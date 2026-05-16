#!/usr/bin/env bash
set -euo pipefail

# Run this from the Laravel project root after the Milestone 1 API scaffold.
# It adds a simple Blade web interface for contacts, products, and invoices.

mkdir -p app/Http/Controllers/Web resources/views/layouts resources/views/contacts resources/views/products resources/views/invoices

cat > app/Http/Controllers/Web/DashboardController.php <<'PHP'
<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\Contact;
use App\Models\Invoice;
use App\Models\Product;
use Illuminate\View\View;

class DashboardController extends Controller
{
    public function __invoke(): View
    {
        return view('dashboard', [
            'contactsCount' => Contact::count(),
            'productsCount' => Product::count(),
            'invoicesCount' => Invoice::count(),
            'recentInvoices' => Invoice::with('customer')->latest('id')->limit(5)->get(),
        ]);
    }
}
PHP

cat > app/Http/Controllers/Web/ContactController.php <<'PHP'
<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\Contact;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

class ContactController extends Controller
{
    public function index(): View
    {
        return view('contacts.index', [
            'contacts' => Contact::orderBy('name')->get(),
        ]);
    }

    public function create(): View
    {
        return view('contacts.create');
    }

    public function store(Request $request): RedirectResponse
    {
        $data = $request->validate([
            'type' => ['required', 'in:customer,supplier,both'],
            'name' => ['required', 'string', 'max:255'],
            'vat_number' => ['nullable', 'string', 'max:50'],
            'enterprise_number' => ['nullable', 'string', 'max:50'],
            'address_line1' => ['nullable', 'string', 'max:255'],
            'postal_code' => ['nullable', 'string', 'max:20'],
            'city' => ['nullable', 'string', 'max:100'],
            'country_code' => ['required', 'string', 'size:2'],
            'email' => ['nullable', 'email', 'max:255'],
            'payment_terms_days' => ['required', 'integer', 'min:0', 'max:365'],
        ]);

        Contact::create($data);

        return redirect()->route('web.contacts.index')->with('success', 'Contact created.');
    }
}
PHP

cat > app/Http/Controllers/Web/ProductController.php <<'PHP'
<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\Product;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

class ProductController extends Controller
{
    public function index(): View
    {
        return view('products.index', [
            'products' => Product::orderBy('name')->get(),
        ]);
    }

    public function create(): View
    {
        return view('products.create');
    }

    public function store(Request $request): RedirectResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'unit_price_ex_vat' => ['required', 'numeric', 'min:0'],
            'vat_rate' => ['required', 'numeric', 'min:0', 'max:100'],
            'unit_code' => ['required', 'string', 'max:20'],
            'account_code' => ['nullable', 'string', 'max:50'],
        ]);

        Product::create($data);

        return redirect()->route('web.products.index')->with('success', 'Product created.');
    }
}
PHP

cat > app/Http/Controllers/Web/InvoiceController.php <<'PHP'
<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\Company;
use App\Models\Contact;
use App\Models\Invoice;
use App\Models\InvoiceLine;
use App\Models\Product;
use App\Services\InvoiceCalculator;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\View\View;

class InvoiceController extends Controller
{
    public function index(): View
    {
        return view('invoices.index', [
            'invoices' => Invoice::with('customer')->latest('id')->get(),
        ]);
    }

    public function create(): View
    {
        return view('invoices.create', [
            'companies' => Company::orderBy('legal_name')->get(),
            'customers' => Contact::whereIn('type', ['customer', 'both'])->orderBy('name')->get(),
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $data = $request->validate([
            'company_id' => ['required', 'exists:companies,id'],
            'customer_id' => ['required', 'exists:contacts,id'],
            'issue_date' => ['required', 'date'],
            'due_date' => ['required', 'date', 'after_or_equal:issue_date'],
            'notes' => ['nullable', 'string'],
        ]);

        $invoice = DB::transaction(function () use ($data) {
            $company = Company::lockForUpdate()->findOrFail($data['company_id']);

            return Invoice::create([
                'company_id' => $company->id,
                'customer_id' => $data['customer_id'],
                'invoice_type' => 'invoice',
                'invoice_number' => $company->reserveNextInvoiceNumber(),
                'issue_date' => Carbon::parse($data['issue_date'])->toDateString(),
                'due_date' => Carbon::parse($data['due_date'])->toDateString(),
                'currency' => $company->default_currency,
                'status' => 'draft',
                'notes' => $data['notes'] ?? null,
            ]);
        });

        return redirect()->route('web.invoices.show', $invoice)->with('success', 'Invoice created. Add lines below.');
    }

    public function show(Invoice $invoice): View
    {
        return view('invoices.show', [
            'invoice' => $invoice->load(['company', 'customer', 'lines.product']),
            'products' => Product::orderBy('name')->get(),
        ]);
    }

    public function addLine(Request $request, Invoice $invoice, InvoiceCalculator $calculator): RedirectResponse
    {
        if ($invoice->status !== 'draft') {
            return back()->withErrors(['invoice' => 'Only draft invoices can be edited.']);
        }

        $data = $request->validate([
            'product_id' => ['nullable', 'exists:products,id'],
            'description' => ['nullable', 'string'],
            'quantity' => ['required', 'numeric', 'min:0.001'],
            'unit_price_ex_vat' => ['nullable', 'numeric', 'min:0'],
            'vat_rate' => ['nullable', 'numeric', 'min:0', 'max:100'],
        ]);

        $product = isset($data['product_id']) ? Product::find($data['product_id']) : null;

        $invoice->lines()->create([
            'product_id' => $product?->id,
            'description' => $data['description'] ?: ($product?->description ?: $product?->name ?: 'Invoice line'),
            'quantity' => $data['quantity'],
            'unit_code' => $product?->unit_code ?? 'C62',
            'unit_price_ex_vat' => $data['unit_price_ex_vat'] ?? $product?->unit_price_ex_vat ?? 0,
            'vat_rate' => $data['vat_rate'] ?? $product?->vat_rate ?? 21,
        ]);

        $calculator->recalculate($invoice);

        return redirect()->route('web.invoices.show', $invoice)->with('success', 'Line added.');
    }

    public function deleteLine(Invoice $invoice, InvoiceLine $line, InvoiceCalculator $calculator): RedirectResponse
    {
        if ($line->invoice_id !== $invoice->id) {
            abort(404);
        }

        if ($invoice->status !== 'draft') {
            return back()->withErrors(['invoice' => 'Only draft invoices can be edited.']);
        }

        $line->delete();
        $calculator->recalculate($invoice);

        return redirect()->route('web.invoices.show', $invoice)->with('success', 'Line deleted.');
    }

    public function markPaid(Invoice $invoice): RedirectResponse
    {
        $invoice->update(['status' => 'paid']);

        return redirect()->route('web.invoices.show', $invoice)->with('success', 'Invoice marked as paid.');
    }
}
PHP

cat > resources/views/layouts/app.blade.php <<'BLADE'
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ $title ?? 'Invoicing App' }}</title>
    <style>
        * { box-sizing: border-box; }
        body { font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; margin: 0; background: #f6f7f9; color: #17202a; }
        header { background: #111827; color: white; padding: 16px 28px; }
        header a { color: white; text-decoration: none; margin-right: 18px; font-weight: 600; }
        main { max-width: 1100px; margin: 28px auto; padding: 0 18px; }
        .card { background: white; border-radius: 14px; padding: 22px; box-shadow: 0 8px 24px rgba(15, 23, 42, .06); margin-bottom: 18px; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 16px; }
        .stat { font-size: 34px; font-weight: 800; }
        table { width: 100%; border-collapse: collapse; background: white; }
        th, td { padding: 12px; border-bottom: 1px solid #e5e7eb; text-align: left; vertical-align: top; }
        th { color: #4b5563; font-size: 13px; text-transform: uppercase; letter-spacing: .04em; }
        input, select, textarea { width: 100%; padding: 10px 12px; border: 1px solid #d1d5db; border-radius: 10px; font: inherit; }
        label { display: block; font-weight: 700; margin-bottom: 6px; }
        .field { margin-bottom: 14px; }
        .button, button { display: inline-block; border: 0; background: #2563eb; color: white; padding: 10px 14px; border-radius: 10px; text-decoration: none; font-weight: 700; cursor: pointer; }
        .button.secondary { background: #374151; }
        .button.danger, button.danger { background: #dc2626; }
        .muted { color: #6b7280; }
        .success { background: #dcfce7; color: #166534; padding: 12px 14px; border-radius: 10px; margin-bottom: 16px; }
        .errors { background: #fee2e2; color: #991b1b; padding: 12px 14px; border-radius: 10px; margin-bottom: 16px; }
        .actions { display: flex; gap: 8px; align-items: center; flex-wrap: wrap; }
        .right { text-align: right; }
    </style>
</head>
<body>
<header>
    <a href="{{ route('web.dashboard') }}">Dashboard</a>
    <a href="{{ route('web.invoices.index') }}">Invoices</a>
    <a href="{{ route('web.contacts.index') }}">Contacts</a>
    <a href="{{ route('web.products.index') }}">Products</a>
</header>
<main>
    @if (session('success'))
        <div class="success">{{ session('success') }}</div>
    @endif

    @if ($errors->any())
        <div class="errors">
            <strong>Please fix this:</strong>
            <ul>
                @foreach ($errors->all() as $error)
                    <li>{{ $error }}</li>
                @endforeach
            </ul>
        </div>
    @endif

    @yield('content')
</main>
</body>
</html>
BLADE

cat > resources/views/dashboard.blade.php <<'BLADE'
@extends('layouts.app', ['title' => 'Dashboard'])

@section('content')
<div class="card">
    <h1>Invoicing App</h1>
    <p class="muted">Free-first local invoicing MVP.</p>
    <div class="actions">
        <a class="button" href="{{ route('web.invoices.create') }}">Create invoice</a>
        <a class="button secondary" href="{{ route('web.contacts.create') }}">Add contact</a>
        <a class="button secondary" href="{{ route('web.products.create') }}">Add product</a>
    </div>
</div>

<div class="grid">
    <div class="card"><div class="muted">Contacts</div><div class="stat">{{ $contactsCount }}</div></div>
    <div class="card"><div class="muted">Products</div><div class="stat">{{ $productsCount }}</div></div>
    <div class="card"><div class="muted">Invoices</div><div class="stat">{{ $invoicesCount }}</div></div>
</div>

<div class="card">
    <h2>Recent invoices</h2>
    <table>
        <thead><tr><th>Number</th><th>Customer</th><th>Status</th><th>Total</th></tr></thead>
        <tbody>
        @forelse ($recentInvoices as $invoice)
            <tr>
                <td><a href="{{ route('web.invoices.show', $invoice) }}">{{ $invoice->invoice_number }}</a></td>
                <td>{{ $invoice->customer?->name }}</td>
                <td>{{ $invoice->status }}</td>
                <td>€ {{ number_format((float) $invoice->total_inc_vat, 2, ',', '.') }}</td>
            </tr>
        @empty
            <tr><td colspan="4">No invoices yet.</td></tr>
        @endforelse
        </tbody>
    </table>
</div>
@endsection
BLADE

cat > resources/views/contacts/index.blade.php <<'BLADE'
@extends('layouts.app', ['title' => 'Contacts'])

@section('content')
<div class="card actions">
    <h1 style="margin-right:auto">Contacts</h1>
    <a class="button" href="{{ route('web.contacts.create') }}">Add contact</a>
</div>

<div class="card">
    <table>
        <thead><tr><th>Name</th><th>Type</th><th>VAT</th><th>City</th><th>Email</th></tr></thead>
        <tbody>
        @forelse ($contacts as $contact)
            <tr>
                <td>{{ $contact->name }}</td>
                <td>{{ $contact->type }}</td>
                <td>{{ $contact->vat_number }}</td>
                <td>{{ $contact->city }}</td>
                <td>{{ $contact->email }}</td>
            </tr>
        @empty
            <tr><td colspan="5">No contacts yet.</td></tr>
        @endforelse
        </tbody>
    </table>
</div>
@endsection
BLADE

cat > resources/views/contacts/create.blade.php <<'BLADE'
@extends('layouts.app', ['title' => 'Add contact'])

@section('content')
<div class="card">
    <h1>Add contact</h1>
    <form method="post" action="{{ route('web.contacts.store') }}">
        @csrf
        <div class="grid">
            <div class="field"><label>Type</label><select name="type"><option value="customer">Customer</option><option value="supplier">Supplier</option><option value="both">Both</option></select></div>
            <div class="field"><label>Name</label><input name="name" required value="{{ old('name') }}"></div>
            <div class="field"><label>VAT number</label><input name="vat_number" value="{{ old('vat_number') }}"></div>
            <div class="field"><label>Enterprise number</label><input name="enterprise_number" value="{{ old('enterprise_number') }}"></div>
            <div class="field"><label>Email</label><input name="email" type="email" value="{{ old('email') }}"></div>
            <div class="field"><label>Address</label><input name="address_line1" value="{{ old('address_line1') }}"></div>
            <div class="field"><label>Postal code</label><input name="postal_code" value="{{ old('postal_code') }}"></div>
            <div class="field"><label>City</label><input name="city" value="{{ old('city') }}"></div>
            <div class="field"><label>Country code</label><input name="country_code" value="{{ old('country_code', 'BE') }}" maxlength="2" required></div>
            <div class="field"><label>Payment terms days</label><input name="payment_terms_days" type="number" value="{{ old('payment_terms_days', 30) }}" required></div>
        </div>
        <button type="submit">Save contact</button>
    </form>
</div>
@endsection
BLADE

cat > resources/views/products/index.blade.php <<'BLADE'
@extends('layouts.app', ['title' => 'Products'])

@section('content')
<div class="card actions">
    <h1 style="margin-right:auto">Products</h1>
    <a class="button" href="{{ route('web.products.create') }}">Add product</a>
</div>

<div class="card">
    <table>
        <thead><tr><th>Name</th><th>Description</th><th>Price ex VAT</th><th>VAT</th><th>Unit</th></tr></thead>
        <tbody>
        @forelse ($products as $product)
            <tr>
                <td>{{ $product->name }}</td>
                <td>{{ $product->description }}</td>
                <td>€ {{ number_format((float) $product->unit_price_ex_vat, 2, ',', '.') }}</td>
                <td>{{ number_format((float) $product->vat_rate, 2, ',', '.') }}%</td>
                <td>{{ $product->unit_code }}</td>
            </tr>
        @empty
            <tr><td colspan="5">No products yet.</td></tr>
        @endforelse
        </tbody>
    </table>
</div>
@endsection
BLADE

cat > resources/views/products/create.blade.php <<'BLADE'
@extends('layouts.app', ['title' => 'Add product'])

@section('content')
<div class="card">
    <h1>Add product</h1>
    <form method="post" action="{{ route('web.products.store') }}">
        @csrf
        <div class="grid">
            <div class="field"><label>Name</label><input name="name" required value="{{ old('name') }}"></div>
            <div class="field"><label>Price ex VAT</label><input name="unit_price_ex_vat" type="number" step="0.01" min="0" required value="{{ old('unit_price_ex_vat', '0.00') }}"></div>
            <div class="field"><label>VAT rate</label><input name="vat_rate" type="number" step="0.01" min="0" max="100" required value="{{ old('vat_rate', '21.00') }}"></div>
            <div class="field"><label>Unit code</label><input name="unit_code" required value="{{ old('unit_code', 'C62') }}"></div>
            <div class="field"><label>Account code</label><input name="account_code" value="{{ old('account_code') }}"></div>
        </div>
        <div class="field"><label>Description</label><textarea name="description" rows="3">{{ old('description') }}</textarea></div>
        <button type="submit">Save product</button>
    </form>
</div>
@endsection
BLADE

cat > resources/views/invoices/index.blade.php <<'BLADE'
@extends('layouts.app', ['title' => 'Invoices'])

@section('content')
<div class="card actions">
    <h1 style="margin-right:auto">Invoices</h1>
    <a class="button" href="{{ route('web.invoices.create') }}">Create invoice</a>
</div>

<div class="card">
    <table>
        <thead><tr><th>Number</th><th>Customer</th><th>Issue date</th><th>Due date</th><th>Status</th><th class="right">Total</th></tr></thead>
        <tbody>
        @forelse ($invoices as $invoice)
            <tr>
                <td><a href="{{ route('web.invoices.show', $invoice) }}">{{ $invoice->invoice_number }}</a></td>
                <td>{{ $invoice->customer?->name }}</td>
                <td>{{ $invoice->issue_date?->format('Y-m-d') }}</td>
                <td>{{ $invoice->due_date?->format('Y-m-d') }}</td>
                <td>{{ $invoice->status }}</td>
                <td class="right">€ {{ number_format((float) $invoice->total_inc_vat, 2, ',', '.') }}</td>
            </tr>
        @empty
            <tr><td colspan="6">No invoices yet.</td></tr>
        @endforelse
        </tbody>
    </table>
</div>
@endsection
BLADE

cat > resources/views/invoices/create.blade.php <<'BLADE'
@extends('layouts.app', ['title' => 'Create invoice'])

@section('content')
<div class="card">
    <h1>Create invoice</h1>

    @if ($companies->isEmpty())
        <p>No company found. Run <code>php artisan migrate:fresh --seed</code> or add a company first.</p>
    @elseif ($customers->isEmpty())
        <p>No customers found. Create a customer first.</p>
        <a class="button" href="{{ route('web.contacts.create') }}">Add customer</a>
    @else
        <form method="post" action="{{ route('web.invoices.store') }}">
            @csrf
            <div class="grid">
                <div class="field">
                    <label>Company</label>
                    <select name="company_id" required>
                        @foreach ($companies as $company)
                            <option value="{{ $company->id }}">{{ $company->legal_name }}</option>
                        @endforeach
                    </select>
                </div>
                <div class="field">
                    <label>Customer</label>
                    <select name="customer_id" required>
                        @foreach ($customers as $customer)
                            <option value="{{ $customer->id }}">{{ $customer->name }}</option>
                        @endforeach
                    </select>
                </div>
                <div class="field"><label>Issue date</label><input name="issue_date" type="date" required value="{{ old('issue_date', now()->toDateString()) }}"></div>
                <div class="field"><label>Due date</label><input name="due_date" type="date" required value="{{ old('due_date', now()->addDays(30)->toDateString()) }}"></div>
            </div>
            <div class="field"><label>Notes</label><textarea name="notes" rows="3">{{ old('notes') }}</textarea></div>
            <button type="submit">Create invoice</button>
        </form>
    @endif
</div>
@endsection
BLADE

cat > resources/views/invoices/show.blade.php <<'BLADE'
@extends('layouts.app', ['title' => $invoice->invoice_number])

@section('content')
<div class="card">
    <div class="actions">
        <h1 style="margin-right:auto">Invoice {{ $invoice->invoice_number }}</h1>
        @if ($invoice->status !== 'paid')
            <form method="post" action="{{ route('web.invoices.mark-paid', $invoice) }}">
                @csrf
                <button type="submit" class="secondary">Mark paid</button>
            </form>
        @endif
    </div>
    <p class="muted">
        {{ $invoice->company?->legal_name }} → {{ $invoice->customer?->name }}<br>
        Issue date: {{ $invoice->issue_date?->format('Y-m-d') }} · Due date: {{ $invoice->due_date?->format('Y-m-d') }} · Status: {{ $invoice->status }}
    </p>
    @if ($invoice->notes)
        <p>{{ $invoice->notes }}</p>
    @endif
</div>

<div class="card">
    <h2>Lines</h2>
    <table>
        <thead><tr><th>Description</th><th class="right">Qty</th><th class="right">Unit price</th><th class="right">VAT</th><th class="right">Total</th><th></th></tr></thead>
        <tbody>
        @forelse ($invoice->lines as $line)
            <tr>
                <td>{{ $line->description }}</td>
                <td class="right">{{ number_format((float) $line->quantity, 3, ',', '.') }}</td>
                <td class="right">€ {{ number_format((float) $line->unit_price_ex_vat, 2, ',', '.') }}</td>
                <td class="right">{{ number_format((float) $line->vat_rate, 2, ',', '.') }}%</td>
                <td class="right">€ {{ number_format((float) $line->line_total_inc_vat, 2, ',', '.') }}</td>
                <td class="right">
                    @if ($invoice->status === 'draft')
                        <form method="post" action="{{ route('web.invoices.lines.delete', [$invoice, $line]) }}">
                            @csrf
                            @method('DELETE')
                            <button class="danger" type="submit">Delete</button>
                        </form>
                    @endif
                </td>
            </tr>
        @empty
            <tr><td colspan="6">No lines yet.</td></tr>
        @endforelse
        </tbody>
        <tfoot>
            <tr><th colspan="4" class="right">Subtotal ex VAT</th><th class="right">€ {{ number_format((float) $invoice->subtotal_ex_vat, 2, ',', '.') }}</th><th></th></tr>
            <tr><th colspan="4" class="right">VAT</th><th class="right">€ {{ number_format((float) $invoice->total_vat, 2, ',', '.') }}</th><th></th></tr>
            <tr><th colspan="4" class="right">Total inc VAT</th><th class="right">€ {{ number_format((float) $invoice->total_inc_vat, 2, ',', '.') }}</th><th></th></tr>
        </tfoot>
    </table>
</div>

@if ($invoice->status === 'draft')
<div class="card">
    <h2>Add line</h2>
    <form method="post" action="{{ route('web.invoices.lines.add', $invoice) }}">
        @csrf
        <div class="grid">
            <div class="field">
                <label>Product</label>
                <select name="product_id">
                    <option value="">Custom line</option>
                    @foreach ($products as $product)
                        <option value="{{ $product->id }}">{{ $product->name }} — € {{ number_format((float) $product->unit_price_ex_vat, 2, ',', '.') }}</option>
                    @endforeach
                </select>
            </div>
            <div class="field"><label>Quantity</label><input name="quantity" type="number" step="0.001" min="0.001" value="1" required></div>
            <div class="field"><label>Custom unit price ex VAT</label><input name="unit_price_ex_vat" type="number" step="0.01" min="0" placeholder="Use product price"></div>
            <div class="field"><label>Custom VAT rate</label><input name="vat_rate" type="number" step="0.01" min="0" max="100" placeholder="Use product VAT"></div>
        </div>
        <div class="field"><label>Custom description</label><textarea name="description" rows="2" placeholder="Use product description"></textarea></div>
        <button type="submit">Add line</button>
    </form>
</div>
@endif
@endsection
BLADE

cat > routes/web.php <<'PHP'
<?php

use App\Http\Controllers\Web\ContactController;
use App\Http\Controllers\Web\DashboardController;
use App\Http\Controllers\Web\InvoiceController;
use App\Http\Controllers\Web\ProductController;
use Illuminate\Support\Facades\Route;

Route::get('/', DashboardController::class)->name('web.dashboard');

Route::get('/contacts', [ContactController::class, 'index'])->name('web.contacts.index');
Route::get('/contacts/create', [ContactController::class, 'create'])->name('web.contacts.create');
Route::post('/contacts', [ContactController::class, 'store'])->name('web.contacts.store');

Route::get('/products', [ProductController::class, 'index'])->name('web.products.index');
Route::get('/products/create', [ProductController::class, 'create'])->name('web.products.create');
Route::post('/products', [ProductController::class, 'store'])->name('web.products.store');

Route::get('/invoices', [InvoiceController::class, 'index'])->name('web.invoices.index');
Route::get('/invoices/create', [InvoiceController::class, 'create'])->name('web.invoices.create');
Route::post('/invoices', [InvoiceController::class, 'store'])->name('web.invoices.store');
Route::get('/invoices/{invoice}', [InvoiceController::class, 'show'])->name('web.invoices.show');
Route::post('/invoices/{invoice}/lines', [InvoiceController::class, 'addLine'])->name('web.invoices.lines.add');
Route::delete('/invoices/{invoice}/lines/{line}', [InvoiceController::class, 'deleteLine'])->name('web.invoices.lines.delete');
Route::post('/invoices/{invoice}/mark-paid', [InvoiceController::class, 'markPaid'])->name('web.invoices.mark-paid');
PHP

php artisan route:clear
php artisan view:clear
php artisan optimize:clear

echo "Milestone 1 web UI scaffold installed."
echo "Start the server with:"
echo "  php artisan serve"
echo ""
echo "Open:"
echo "  http://127.0.0.1:8000"
echo ""
echo "Try: Dashboard -> Create invoice -> Add line"
