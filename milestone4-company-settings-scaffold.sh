#!/usr/bin/env bash
set -euo pipefail

# Run this from the Laravel project root after the UBL XML scaffold.
# It adds a Company Settings screen so the demo company data can be edited from the browser.

mkdir -p app/Http/Controllers/Web resources/views/company

cat > app/Http/Controllers/Web/CompanyController.php <<'PHP'
<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\Company;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

class CompanyController extends Controller
{
    public function edit(): View
    {
        $company = Company::firstOrCreate([
            'legal_name' => 'My Company',
        ], [
            'country_code' => 'BE',
            'default_currency' => 'EUR',
            'invoice_number_prefix' => 'INV',
            'next_invoice_number' => 1,
        ]);

        return view('company.edit', [
            'company' => $company,
        ]);
    }

    public function update(Request $request): RedirectResponse
    {
        $company = Company::firstOrFail();

        $data = $request->validate([
            'legal_name' => ['required', 'string', 'max:255'],
            'vat_number' => ['nullable', 'string', 'max:50'],
            'enterprise_number' => ['nullable', 'string', 'max:50'],
            'address_line1' => ['nullable', 'string', 'max:255'],
            'address_line2' => ['nullable', 'string', 'max:255'],
            'postal_code' => ['nullable', 'string', 'max:20'],
            'city' => ['nullable', 'string', 'max:100'],
            'country_code' => ['required', 'string', 'size:2'],
            'email' => ['nullable', 'email', 'max:255'],
            'iban' => ['nullable', 'string', 'max:50'],
            'bic' => ['nullable', 'string', 'max:20'],
            'default_currency' => ['required', 'string', 'size:3'],
            'invoice_number_prefix' => ['required', 'string', 'max:20'],
            'next_invoice_number' => ['required', 'integer', 'min:1'],
        ]);

        $data['country_code'] = strtoupper($data['country_code']);
        $data['default_currency'] = strtoupper($data['default_currency']);
        $data['vat_number'] = $this->normalizeNullable($data['vat_number'] ?? null);
        $data['enterprise_number'] = $this->normalizeNullable($data['enterprise_number'] ?? null);
        $data['iban'] = $this->normalizeIban($data['iban'] ?? null);
        $data['bic'] = $this->normalizeNullable($data['bic'] ?? null);

        $company->update($data);

        return redirect()->route('web.company.edit')->with('success', 'Company settings saved.');
    }

    private function normalizeNullable(?string $value): ?string
    {
        $value = trim((string) $value);

        return $value === '' ? null : strtoupper($value);
    }

    private function normalizeIban(?string $value): ?string
    {
        $value = preg_replace('/\s+/', '', strtoupper(trim((string) $value)));

        return $value === '' ? null : $value;
    }
}
PHP

cat > resources/views/company/edit.blade.php <<'BLADE'
@extends('layouts.app', ['title' => 'Company settings'])

@section('content')
<div class="card">
    <h1>Company settings</h1>
    <p class="muted">These details appear on your PDF invoices and UBL XML exports.</p>

    <form method="post" action="{{ route('web.company.update') }}">
        @csrf
        @method('PUT')

        <h2>Legal details</h2>
        <div class="grid">
            <div class="field">
                <label>Legal name</label>
                <input name="legal_name" required value="{{ old('legal_name', $company->legal_name) }}">
            </div>
            <div class="field">
                <label>VAT number</label>
                <input name="vat_number" value="{{ old('vat_number', $company->vat_number) }}" placeholder="BE0123456789">
            </div>
            <div class="field">
                <label>Enterprise number</label>
                <input name="enterprise_number" value="{{ old('enterprise_number', $company->enterprise_number) }}" placeholder="0123456789">
            </div>
            <div class="field">
                <label>Email</label>
                <input name="email" type="email" value="{{ old('email', $company->email) }}">
            </div>
        </div>

        <h2>Address</h2>
        <div class="grid">
            <div class="field">
                <label>Address line 1</label>
                <input name="address_line1" value="{{ old('address_line1', $company->address_line1) }}">
            </div>
            <div class="field">
                <label>Address line 2</label>
                <input name="address_line2" value="{{ old('address_line2', $company->address_line2) }}">
            </div>
            <div class="field">
                <label>Postal code</label>
                <input name="postal_code" value="{{ old('postal_code', $company->postal_code) }}">
            </div>
            <div class="field">
                <label>City</label>
                <input name="city" value="{{ old('city', $company->city) }}">
            </div>
            <div class="field">
                <label>Country code</label>
                <input name="country_code" maxlength="2" required value="{{ old('country_code', $company->country_code ?? 'BE') }}">
            </div>
        </div>

        <h2>Payment details</h2>
        <div class="grid">
            <div class="field">
                <label>IBAN</label>
                <input name="iban" value="{{ old('iban', $company->iban) }}" placeholder="BE68539007547034">
            </div>
            <div class="field">
                <label>BIC</label>
                <input name="bic" value="{{ old('bic', $company->bic) }}" placeholder="BBRUBEBB">
            </div>
            <div class="field">
                <label>Default currency</label>
                <input name="default_currency" maxlength="3" required value="{{ old('default_currency', $company->default_currency ?? 'EUR') }}">
            </div>
        </div>

        <h2>Invoice numbering</h2>
        <div class="grid">
            <div class="field">
                <label>Invoice number prefix</label>
                <input name="invoice_number_prefix" required value="{{ old('invoice_number_prefix', $company->invoice_number_prefix ?? 'INV') }}">
            </div>
            <div class="field">
                <label>Next invoice number</label>
                <input name="next_invoice_number" type="number" min="1" required value="{{ old('next_invoice_number', $company->next_invoice_number ?? 1) }}">
            </div>
        </div>

        <button type="submit">Save company settings</button>
    </form>
</div>
@endsection
BLADE

# Add routes.
php <<'PHP'
<?php
$path = 'routes/web.php';
$text = file_get_contents($path);

if (strpos($text, 'use App\\Http\\Controllers\\Web\\CompanyController;') === false) {
    $text = str_replace(
        "use App\\Http\\Controllers\\Web\\ContactController;\n",
        "use App\\Http\\Controllers\\Web\\CompanyController;\nuse App\\Http\\Controllers\\Web\\ContactController;\n",
        $text
    );
}

$routes = "\nRoute::get('/company', [CompanyController::class, 'edit'])->name('web.company.edit');\nRoute::put('/company', [CompanyController::class, 'update'])->name('web.company.update');\n";

if (strpos($text, 'web.company.edit') === false) {
    $marker = "Route::get('/', DashboardController::class)->name('web.dashboard');\n";
    $text = str_replace($marker, $marker . $routes, $text);
}

file_put_contents($path, $text);
PHP

# Add link to header.
php <<'PHP'
<?php
$path = 'resources/views/layouts/app.blade.php';
$text = file_get_contents($path);
$link = "        <a href=\"{{ route('web.company.edit') }}\">Company</a>\n";

if (strpos($text, 'web.company.edit') === false) {
    $marker = "        <a href=\"{{ route('web.dashboard') }}\">Dashboard</a>\n";
    if (strpos($text, $marker) === false) {
        $marker = "    <a href=\"{{ route('web.dashboard') }}\">Dashboard</a>\n";
    }
    $text = str_replace($marker, $marker . $link, $text);
}

file_put_contents($path, $text);
PHP

# Add dashboard card/link.
php <<'PHP'
<?php
$path = 'resources/views/dashboard.blade.php';
$text = file_get_contents($path);
$button = "        <a class=\"button secondary\" href=\"{{ route('web.company.edit') }}\">Company settings</a>\n";

if (strpos($text, 'web.company.edit') === false) {
    $marker = "        <a class=\"button secondary\" href=\"{{ route('web.products.create') }}\">Add product</a>\n";
    $text = str_replace($marker, $marker . $button, $text);
}

file_put_contents($path, $text);
PHP

php artisan route:clear
php artisan view:clear
php artisan optimize:clear

echo "Milestone 4 company settings scaffold installed."
echo "Start/restart Laravel:"
echo "  php artisan serve"
echo ""
echo "Open:"
echo "  http://127.0.0.1:8000/company"
echo ""
echo "Update your real company info, then download a PDF/UBL again to check it."
