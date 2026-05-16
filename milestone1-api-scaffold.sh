#!/usr/bin/env bash
set -euo pipefail

# Run this from the Laravel project root after the Milestone 1 scaffold.
# It adds a simple JSON API for contacts, products, invoices, invoice lines, and invoice recalculation.

mkdir -p app/Http/Controllers/Api routes

# Ensure API routing exists.
# Laravel 10 usually already has routes/api.php.
# Laravel 11/12 may need php artisan install:api.
if [ ! -f routes/api.php ]; then
  php artisan install:api --no-interaction || true
fi

if [ ! -f routes/api.php ]; then
  cat > routes/api.php <<'PHP'
<?php

use Illuminate\Support\Facades\Route;

Route::get('/health', fn () => ['ok' => true]);
PHP
fi

# If this is Laravel 11/12 and api.php is not registered yet, register it in bootstrap/app.php.
if [ -f bootstrap/app.php ] && ! grep -q "routes/api.php" bootstrap/app.php; then
  python3 - <<'PY'
from pathlib import Path
path = Path('bootstrap/app.php')
text = path.read_text()
needle = "web: __DIR__.'/../routes/web.php',"
replacement = "web: __DIR__.'/../routes/web.php',\n        api: __DIR__.'/../routes/api.php',"
if needle in text and "routes/api.php" not in text:
    text = text.replace(needle, replacement)
    path.write_text(text)
PY
fi

cat > app/Http/Controllers/Api/ContactController.php <<'PHP'
<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Contact;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ContactController extends Controller
{
    public function index(): JsonResponse
    {
        return response()->json(Contact::orderBy('name')->get());
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'type' => ['nullable', 'in:customer,supplier,both'],
            'name' => ['required', 'string', 'max:255'],
            'vat_number' => ['nullable', 'string', 'max:50'],
            'enterprise_number' => ['nullable', 'string', 'max:50'],
            'address_line1' => ['nullable', 'string', 'max:255'],
            'address_line2' => ['nullable', 'string', 'max:255'],
            'postal_code' => ['nullable', 'string', 'max:20'],
            'city' => ['nullable', 'string', 'max:100'],
            'country_code' => ['nullable', 'string', 'size:2'],
            'email' => ['nullable', 'email', 'max:255'],
            'default_currency' => ['nullable', 'string', 'size:3'],
            'payment_terms_days' => ['nullable', 'integer', 'min:0', 'max:365'],
        ]);

        $contact = Contact::create($data);

        return response()->json($contact, 201);
    }

    public function show(Contact $contact): JsonResponse
    {
        return response()->json($contact);
    }

    public function update(Request $request, Contact $contact): JsonResponse
    {
        $data = $request->validate([
            'type' => ['sometimes', 'in:customer,supplier,both'],
            'name' => ['sometimes', 'required', 'string', 'max:255'],
            'vat_number' => ['nullable', 'string', 'max:50'],
            'enterprise_number' => ['nullable', 'string', 'max:50'],
            'address_line1' => ['nullable', 'string', 'max:255'],
            'address_line2' => ['nullable', 'string', 'max:255'],
            'postal_code' => ['nullable', 'string', 'max:20'],
            'city' => ['nullable', 'string', 'max:100'],
            'country_code' => ['nullable', 'string', 'size:2'],
            'email' => ['nullable', 'email', 'max:255'],
            'default_currency' => ['nullable', 'string', 'size:3'],
            'payment_terms_days' => ['nullable', 'integer', 'min:0', 'max:365'],
        ]);

        $contact->update($data);

        return response()->json($contact->refresh());
    }

    public function destroy(Contact $contact): JsonResponse
    {
        $contact->delete();

        return response()->json(['deleted' => true]);
    }
}
PHP

cat > app/Http/Controllers/Api/ProductController.php <<'PHP'
<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Product;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ProductController extends Controller
{
    public function index(): JsonResponse
    {
        return response()->json(Product::orderBy('name')->get());
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'unit_price_ex_vat' => ['required', 'numeric', 'min:0'],
            'vat_rate' => ['required', 'numeric', 'min:0', 'max:100'],
            'unit_code' => ['nullable', 'string', 'max:20'],
            'account_code' => ['nullable', 'string', 'max:50'],
        ]);

        $product = Product::create($data);

        return response()->json($product, 201);
    }

    public function show(Product $product): JsonResponse
    {
        return response()->json($product);
    }

    public function update(Request $request, Product $product): JsonResponse
    {
        $data = $request->validate([
            'name' => ['sometimes', 'required', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'unit_price_ex_vat' => ['sometimes', 'required', 'numeric', 'min:0'],
            'vat_rate' => ['sometimes', 'required', 'numeric', 'min:0', 'max:100'],
            'unit_code' => ['nullable', 'string', 'max:20'],
            'account_code' => ['nullable', 'string', 'max:50'],
        ]);

        $product->update($data);

        return response()->json($product->refresh());
    }

    public function destroy(Product $product): JsonResponse
    {
        $product->delete();

        return response()->json(['deleted' => true]);
    }
}
PHP

cat > app/Http/Controllers/Api/InvoiceController.php <<'PHP'
<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Company;
use App\Models\Invoice;
use App\Services\InvoiceCalculator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class InvoiceController extends Controller
{
    public function index(): JsonResponse
    {
        return response()->json(
            Invoice::with(['company', 'customer', 'lines'])
                ->latest('id')
                ->get()
        );
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'company_id' => ['required', 'exists:companies,id'],
            'customer_id' => ['required', 'exists:contacts,id'],
            'invoice_type' => ['nullable', 'in:invoice,credit_note'],
            'issue_date' => ['nullable', 'date'],
            'due_date' => ['nullable', 'date'],
            'currency' => ['nullable', 'string', 'size:3'],
            'payment_reference' => ['nullable', 'string', 'max:255'],
            'notes' => ['nullable', 'string'],
        ]);

        $invoice = DB::transaction(function () use ($data) {
            $company = Company::lockForUpdate()->findOrFail($data['company_id']);
            $issueDate = isset($data['issue_date'])
                ? Carbon::parse($data['issue_date'])
                : now();
            $dueDate = isset($data['due_date'])
                ? Carbon::parse($data['due_date'])
                : $issueDate->copy()->addDays(30);

            return Invoice::create([
                'company_id' => $company->id,
                'customer_id' => $data['customer_id'],
                'invoice_type' => $data['invoice_type'] ?? 'invoice',
                'invoice_number' => $company->reserveNextInvoiceNumber(),
                'issue_date' => $issueDate->toDateString(),
                'due_date' => $dueDate->toDateString(),
                'currency' => $data['currency'] ?? $company->default_currency,
                'status' => 'draft',
                'payment_reference' => $data['payment_reference'] ?? null,
                'notes' => $data['notes'] ?? null,
            ]);
        });

        return response()->json($invoice->load(['company', 'customer', 'lines']), 201);
    }

    public function show(Invoice $invoice): JsonResponse
    {
        return response()->json($invoice->load(['company', 'customer', 'lines.product']));
    }

    public function update(Request $request, Invoice $invoice): JsonResponse
    {
        $data = $request->validate([
            'customer_id' => ['sometimes', 'exists:contacts,id'],
            'issue_date' => ['sometimes', 'date'],
            'due_date' => ['sometimes', 'date'],
            'currency' => ['sometimes', 'string', 'size:3'],
            'status' => ['sometimes', 'in:draft,ready,validated,sent,paid,cancelled'],
            'payment_reference' => ['nullable', 'string', 'max:255'],
            'notes' => ['nullable', 'string'],
        ]);

        $invoice->update($data);

        return response()->json($invoice->refresh()->load(['company', 'customer', 'lines.product']));
    }

    public function destroy(Invoice $invoice): JsonResponse
    {
        if ($invoice->status !== 'draft') {
            return response()->json([
                'message' => 'Only draft invoices can be deleted.',
            ], 422);
        }

        $invoice->delete();

        return response()->json(['deleted' => true]);
    }

    public function recalculate(Invoice $invoice, InvoiceCalculator $calculator): JsonResponse
    {
        $invoice = $calculator->recalculate($invoice);

        return response()->json($invoice->load(['company', 'customer', 'lines.product']));
    }
}
PHP

cat > app/Http/Controllers/Api/InvoiceLineController.php <<'PHP'
<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Invoice;
use App\Models\InvoiceLine;
use App\Models\Product;
use App\Services\InvoiceCalculator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class InvoiceLineController extends Controller
{
    public function store(Request $request, Invoice $invoice, InvoiceCalculator $calculator): JsonResponse
    {
        if ($invoice->status !== 'draft') {
            return response()->json([
                'message' => 'Lines can only be added to draft invoices.',
            ], 422);
        }

        $data = $request->validate([
            'product_id' => ['nullable', 'exists:products,id'],
            'description' => ['nullable', 'string'],
            'quantity' => ['required', 'numeric', 'min:0.001'],
            'unit_code' => ['nullable', 'string', 'max:20'],
            'unit_price_ex_vat' => ['nullable', 'numeric', 'min:0'],
            'vat_rate' => ['nullable', 'numeric', 'min:0', 'max:100'],
        ]);

        $product = isset($data['product_id']) ? Product::find($data['product_id']) : null;

        $line = $invoice->lines()->create([
            'product_id' => $product?->id,
            'description' => $data['description'] ?? $product?->description ?? $product?->name ?? 'Invoice line',
            'quantity' => $data['quantity'],
            'unit_code' => $data['unit_code'] ?? $product?->unit_code ?? 'C62',
            'unit_price_ex_vat' => $data['unit_price_ex_vat'] ?? $product?->unit_price_ex_vat ?? 0,
            'vat_rate' => $data['vat_rate'] ?? $product?->vat_rate ?? 21,
        ]);

        $calculator->recalculate($invoice);

        return response()->json($line->refresh(), 201);
    }

    public function update(Request $request, Invoice $invoice, InvoiceLine $line, InvoiceCalculator $calculator): JsonResponse
    {
        if ($line->invoice_id !== $invoice->id) {
            abort(404);
        }

        if ($invoice->status !== 'draft') {
            return response()->json([
                'message' => 'Lines can only be changed on draft invoices.',
            ], 422);
        }

        $data = $request->validate([
            'description' => ['sometimes', 'required', 'string'],
            'quantity' => ['sometimes', 'required', 'numeric', 'min:0.001'],
            'unit_code' => ['sometimes', 'required', 'string', 'max:20'],
            'unit_price_ex_vat' => ['sometimes', 'required', 'numeric', 'min:0'],
            'vat_rate' => ['sometimes', 'required', 'numeric', 'min:0', 'max:100'],
        ]);

        $line->update($data);
        $calculator->recalculate($invoice);

        return response()->json($line->refresh());
    }

    public function destroy(Invoice $invoice, InvoiceLine $line, InvoiceCalculator $calculator): JsonResponse
    {
        if ($line->invoice_id !== $invoice->id) {
            abort(404);
        }

        if ($invoice->status !== 'draft') {
            return response()->json([
                'message' => 'Lines can only be deleted from draft invoices.',
            ], 422);
        }

        $line->delete();
        $calculator->recalculate($invoice);

        return response()->json(['deleted' => true]);
    }
}
PHP

cat > routes/api.php <<'PHP'
<?php

use App\Http\Controllers\Api\ContactController;
use App\Http\Controllers\Api\InvoiceController;
use App\Http\Controllers\Api\InvoiceLineController;
use App\Http\Controllers\Api\ProductController;
use Illuminate\Support\Facades\Route;

Route::get('/health', fn () => ['ok' => true]);

Route::apiResource('contacts', ContactController::class);
Route::apiResource('products', ProductController::class);
Route::apiResource('invoices', InvoiceController::class);

Route::post('/invoices/{invoice}/recalculate', [InvoiceController::class, 'recalculate']);
Route::post('/invoices/{invoice}/lines', [InvoiceLineController::class, 'store']);
Route::put('/invoices/{invoice}/lines/{line}', [InvoiceLineController::class, 'update']);
Route::delete('/invoices/{invoice}/lines/{line}', [InvoiceLineController::class, 'destroy']);
PHP

php artisan route:clear
php artisan optimize:clear

echo "Milestone 1 API scaffold installed."
echo "Start the server with:"
echo "  php artisan serve"
echo ""
echo "Test health endpoint:"
echo "  http://127.0.0.1:8000/api/health"
echo ""
echo "Useful endpoints:"
echo "  GET    /api/contacts"
echo "  POST   /api/contacts"
echo "  GET    /api/products"
echo "  POST   /api/products"
echo "  GET    /api/invoices"
echo "  POST   /api/invoices"
echo "  POST   /api/invoices/{invoice}/lines"
echo "  POST   /api/invoices/{invoice}/recalculate"
