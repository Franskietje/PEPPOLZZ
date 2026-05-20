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
            'invoice_number_prefix' => 'FRA',
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
        $data['invoice_number_prefix'] = strtoupper(trim($data['invoice_number_prefix']));
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
