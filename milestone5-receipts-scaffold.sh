#!/usr/bin/env bash
set -euo pipefail

# Run this from the Laravel project root after the Company Settings scaffold.
# It adds a basic receipt/expense module:
# - upload receipt PDF/image
# - manually enter supplier/date/category/totals
# - approve/reject receipts
# OCR will be added later on top of this.

mkdir -p app/Http/Controllers/Web app/Models resources/views/receipts database/migrations

cat > database/migrations/2026_05_13_000006_create_receipts_table.php <<'PHP'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('receipts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('supplier_id')->nullable()->constrained('contacts')->nullOnDelete();
            $table->date('receipt_date')->nullable();
            $table->string('category')->nullable();
            $table->string('currency', 3)->default('EUR');
            $table->decimal('subtotal_ex_vat', 12, 2)->default(0);
            $table->decimal('total_vat', 12, 2)->default(0);
            $table->decimal('total_inc_vat', 12, 2)->default(0);
            $table->string('status')->default('needs_review'); // needs_review, approved, rejected
            $table->string('original_file_path');
            $table->string('original_file_name')->nullable();
            $table->string('mime_type')->nullable();
            $table->text('notes')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('receipts');
    }
};
PHP

cat > app/Models/Receipt.php <<'PHP'
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Receipt extends Model
{
    use HasFactory;

    protected $guarded = [];

    protected $casts = [
        'receipt_date' => 'date',
    ];

    public function supplier(): BelongsTo
    {
        return $this->belongsTo(Contact::class, 'supplier_id');
    }
}
PHP

cat > app/Http/Controllers/Web/ReceiptController.php <<'PHP'
<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\Contact;
use App\Models\Receipt;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\View\View;
use Symfony\Component\HttpFoundation\StreamedResponse;

class ReceiptController extends Controller
{
    public function index(): View
    {
        return view('receipts.index', [
            'receipts' => Receipt::with('supplier')->latest('id')->get(),
        ]);
    }

    public function create(): View
    {
        return view('receipts.create', [
            'suppliers' => Contact::whereIn('type', ['supplier', 'both'])->orderBy('name')->get(),
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $data = $request->validate([
            'supplier_id' => ['nullable', 'exists:contacts,id'],
            'receipt_date' => ['nullable', 'date'],
            'category' => ['nullable', 'string', 'max:100'],
            'currency' => ['required', 'string', 'size:3'],
            'subtotal_ex_vat' => ['nullable', 'numeric', 'min:0'],
            'total_vat' => ['nullable', 'numeric', 'min:0'],
            'total_inc_vat' => ['required', 'numeric', 'min:0'],
            'notes' => ['nullable', 'string'],
            'receipt_file' => ['required', 'file', 'mimes:pdf,jpg,jpeg,png,webp', 'max:10240'],
        ]);

        $file = $request->file('receipt_file');
        $path = $file->store('receipts', 'local');

        $receipt = Receipt::create([
            'supplier_id' => $data['supplier_id'] ?? null,
            'receipt_date' => $data['receipt_date'] ?? null,
            'category' => $data['category'] ?? null,
            'currency' => strtoupper($data['currency']),
            'subtotal_ex_vat' => $data['subtotal_ex_vat'] ?? 0,
            'total_vat' => $data['total_vat'] ?? 0,
            'total_inc_vat' => $data['total_inc_vat'],
            'status' => 'needs_review',
            'original_file_path' => $path,
            'original_file_name' => $file->getClientOriginalName(),
            'mime_type' => $file->getMimeType(),
            'notes' => $data['notes'] ?? null,
        ]);

        return redirect()->route('web.receipts.show', $receipt)->with('success', 'Receipt uploaded.');
    }

    public function show(Receipt $receipt): View
    {
        return view('receipts.show', [
            'receipt' => $receipt->load('supplier'),
            'suppliers' => Contact::whereIn('type', ['supplier', 'both'])->orderBy('name')->get(),
        ]);
    }

    public function update(Request $request, Receipt $receipt): RedirectResponse
    {
        if ($receipt->status !== 'needs_review') {
            return back()->withErrors(['receipt' => 'Only receipts that need review can be edited.']);
        }

        $data = $request->validate([
            'supplier_id' => ['nullable', 'exists:contacts,id'],
            'receipt_date' => ['nullable', 'date'],
            'category' => ['nullable', 'string', 'max:100'],
            'currency' => ['required', 'string', 'size:3'],
            'subtotal_ex_vat' => ['required', 'numeric', 'min:0'],
            'total_vat' => ['required', 'numeric', 'min:0'],
            'total_inc_vat' => ['required', 'numeric', 'min:0'],
            'notes' => ['nullable', 'string'],
        ]);

        $data['currency'] = strtoupper($data['currency']);
        $receipt->update($data);

        return redirect()->route('web.receipts.show', $receipt)->with('success', 'Receipt saved.');
    }

    public function approve(Receipt $receipt): RedirectResponse
    {
        $receipt->update(['status' => 'approved']);

        return redirect()->route('web.receipts.show', $receipt)->with('success', 'Receipt approved.');
    }

    public function reject(Receipt $receipt): RedirectResponse
    {
        $receipt->update(['status' => 'rejected']);

        return redirect()->route('web.receipts.show', $receipt)->with('success', 'Receipt rejected.');
    }

    public function download(Receipt $receipt): StreamedResponse
    {
        return Storage::disk('local')->download(
            $receipt->original_file_path,
            $receipt->original_file_name ?: basename($receipt->original_file_path)
        );
    }
}
PHP

cat > resources/views/receipts/index.blade.php <<'BLADE'
@extends('layouts.app', ['title' => 'Receipts'])

@section('content')
<div class="card actions">
    <h1 style="margin-right:auto">Receipts</h1>
    <a class="button" href="{{ route('web.receipts.create') }}">Upload receipt</a>
</div>

<div class="card">
    <table>
        <thead>
            <tr>
                <th>Date</th>
                <th>Supplier</th>
                <th>Category</th>
                <th>Status</th>
                <th class="right">VAT</th>
                <th class="right">Total</th>
            </tr>
        </thead>
        <tbody>
        @forelse ($receipts as $receipt)
            <tr>
                <td><a href="{{ route('web.receipts.show', $receipt) }}">{{ $receipt->receipt_date?->format('Y-m-d') ?? 'No date' }}</a></td>
                <td>{{ $receipt->supplier?->name ?? 'Unknown supplier' }}</td>
                <td>{{ $receipt->category }}</td>
                <td>{{ $receipt->status }}</td>
                <td class="right">€ {{ number_format((float) $receipt->total_vat, 2, ',', '.') }}</td>
                <td class="right">€ {{ number_format((float) $receipt->total_inc_vat, 2, ',', '.') }}</td>
            </tr>
        @empty
            <tr><td colspan="6">No receipts yet.</td></tr>
        @endforelse
        </tbody>
    </table>
</div>
@endsection
BLADE

cat > resources/views/receipts/create.blade.php <<'BLADE'
@extends('layouts.app', ['title' => 'Upload receipt'])

@section('content')
<div class="card">
    <h1>Upload receipt</h1>
    <p class="muted">Upload a PDF/image and enter the main values manually for now. OCR will be added later.</p>

    <form method="post" action="{{ route('web.receipts.store') }}" enctype="multipart/form-data">
        @csrf
        <div class="grid">
            <div class="field">
                <label>Supplier</label>
                <select name="supplier_id">
                    <option value="">Unknown / create later</option>
                    @foreach ($suppliers as $supplier)
                        <option value="{{ $supplier->id }}" @selected(old('supplier_id') == $supplier->id)>{{ $supplier->name }}</option>
                    @endforeach
                </select>
            </div>
            <div class="field">
                <label>Receipt date</label>
                <input name="receipt_date" type="date" value="{{ old('receipt_date', now()->toDateString()) }}">
            </div>
            <div class="field">
                <label>Category</label>
                <input name="category" value="{{ old('category') }}" placeholder="Fuel, meals, office, travel...">
            </div>
            <div class="field">
                <label>Currency</label>
                <input name="currency" maxlength="3" required value="{{ old('currency', 'EUR') }}">
            </div>
            <div class="field">
                <label>Subtotal ex VAT</label>
                <input name="subtotal_ex_vat" type="number" step="0.01" min="0" value="{{ old('subtotal_ex_vat', '0.00') }}">
            </div>
            <div class="field">
                <label>Total VAT</label>
                <input name="total_vat" type="number" step="0.01" min="0" value="{{ old('total_vat', '0.00') }}">
            </div>
            <div class="field">
                <label>Total inc VAT</label>
                <input name="total_inc_vat" type="number" step="0.01" min="0" required value="{{ old('total_inc_vat', '0.00') }}">
            </div>
            <div class="field">
                <label>Receipt file</label>
                <input name="receipt_file" type="file" accept=".pdf,.jpg,.jpeg,.png,.webp" required>
            </div>
        </div>
        <div class="field">
            <label>Notes</label>
            <textarea name="notes" rows="3">{{ old('notes') }}</textarea>
        </div>
        <button type="submit">Upload receipt</button>
    </form>
</div>
@endsection
BLADE

cat > resources/views/receipts/show.blade.php <<'BLADE'
@extends('layouts.app', ['title' => 'Receipt'])

@section('content')
<div class="card">
    <div class="actions">
        <h1 style="margin-right:auto">Receipt #{{ $receipt->id }}</h1>
        <a class="button secondary" href="{{ route('web.receipts.download', $receipt) }}">Download original</a>
        @if ($receipt->status === 'needs_review')
            <form method="post" action="{{ route('web.receipts.approve', $receipt) }}">
                @csrf
                <button type="submit">Approve</button>
            </form>
            <form method="post" action="{{ route('web.receipts.reject', $receipt) }}">
                @csrf
                <button class="danger" type="submit">Reject</button>
            </form>
        @endif
    </div>
    <p class="muted">
        Status: {{ $receipt->status }} · File: {{ $receipt->original_file_name }}
    </p>
</div>

<div class="card">
    <h2>Receipt details</h2>

    <form method="post" action="{{ route('web.receipts.update', $receipt) }}">
        @csrf
        @method('PUT')

        <div class="grid">
            <div class="field">
                <label>Supplier</label>
                <select name="supplier_id" @disabled($receipt->status !== 'needs_review')>
                    <option value="">Unknown / create later</option>
                    @foreach ($suppliers as $supplier)
                        <option value="{{ $supplier->id }}" @selected(old('supplier_id', $receipt->supplier_id) == $supplier->id)>{{ $supplier->name }}</option>
                    @endforeach
                </select>
            </div>
            <div class="field">
                <label>Receipt date</label>
                <input name="receipt_date" type="date" value="{{ old('receipt_date', $receipt->receipt_date?->format('Y-m-d')) }}" @disabled($receipt->status !== 'needs_review')>
            </div>
            <div class="field">
                <label>Category</label>
                <input name="category" value="{{ old('category', $receipt->category) }}" @disabled($receipt->status !== 'needs_review')>
            </div>
            <div class="field">
                <label>Currency</label>
                <input name="currency" maxlength="3" required value="{{ old('currency', $receipt->currency) }}" @disabled($receipt->status !== 'needs_review')>
            </div>
            <div class="field">
                <label>Subtotal ex VAT</label>
                <input name="subtotal_ex_vat" type="number" step="0.01" min="0" required value="{{ old('subtotal_ex_vat', $receipt->subtotal_ex_vat) }}" @disabled($receipt->status !== 'needs_review')>
            </div>
            <div class="field">
                <label>Total VAT</label>
                <input name="total_vat" type="number" step="0.01" min="0" required value="{{ old('total_vat', $receipt->total_vat) }}" @disabled($receipt->status !== 'needs_review')>
            </div>
            <div class="field">
                <label>Total inc VAT</label>
                <input name="total_inc_vat" type="number" step="0.01" min="0" required value="{{ old('total_inc_vat', $receipt->total_inc_vat) }}" @disabled($receipt->status !== 'needs_review')>
            </div>
        </div>

        <div class="field">
            <label>Notes</label>
            <textarea name="notes" rows="3" @disabled($receipt->status !== 'needs_review')>{{ old('notes', $receipt->notes) }}</textarea>
        </div>

        @if ($receipt->status === 'needs_review')
            <button type="submit">Save receipt</button>
        @endif
    </form>
</div>
@endsection
BLADE

# Add controller import and routes.
php <<'PHP'
<?php
$path = 'routes/web.php';
$text = file_get_contents($path);

if (strpos($text, 'use App\\Http\\Controllers\\Web\\ReceiptController;') === false) {
    $text = str_replace(
        "use App\\Http\\Controllers\\Web\\ProductController;\n",
        "use App\\Http\\Controllers\\Web\\ProductController;\nuse App\\Http\\Controllers\\Web\\ReceiptController;\n",
        $text
    );
}

$routes = <<<'ROUTES'

Route::get('/receipts', [ReceiptController::class, 'index'])->name('web.receipts.index');
Route::get('/receipts/create', [ReceiptController::class, 'create'])->name('web.receipts.create');
Route::post('/receipts', [ReceiptController::class, 'store'])->name('web.receipts.store');
Route::get('/receipts/{receipt}', [ReceiptController::class, 'show'])->name('web.receipts.show');
Route::put('/receipts/{receipt}', [ReceiptController::class, 'update'])->name('web.receipts.update');
Route::get('/receipts/{receipt}/download', [ReceiptController::class, 'download'])->name('web.receipts.download');
Route::post('/receipts/{receipt}/approve', [ReceiptController::class, 'approve'])->name('web.receipts.approve');
Route::post('/receipts/{receipt}/reject', [ReceiptController::class, 'reject'])->name('web.receipts.reject');
ROUTES;

if (strpos($text, 'web.receipts.index') === false) {
    $marker = "Route::get('/products', [ProductController::class, 'index'])->name('web.products.index');\n";
    $text = str_replace($marker, $routes . "\n" . $marker, $text);
}

file_put_contents($path, $text);
PHP

# Add Receipts link to header.
php <<'PHP'
<?php
$path = 'resources/views/layouts/app.blade.php';
$text = file_get_contents($path);
$link = "        <a href=\"{{ route('web.receipts.index') }}\">Receipts</a>\n";

if (strpos($text, 'web.receipts.index') === false) {
    $marker = "        <a href=\"{{ route('web.products.index') }}\">Products</a>\n";
    if (strpos($text, $marker) === false) {
        $marker = "    <a href=\"{{ route('web.products.index') }}\">Products</a>\n";
    }
    $text = str_replace($marker, $marker . $link, $text);
}

file_put_contents($path, $text);
PHP

# Update dashboard controller counts.
php <<'PHP'
<?php
$path = 'app/Http/Controllers/Web/DashboardController.php';
$text = file_get_contents($path);

if (strpos($text, 'use App\\Models\\Receipt;') === false) {
    $text = str_replace(
        "use App\\Models\\Product;\n",
        "use App\\Models\\Product;\nuse App\\Models\\Receipt;\n",
        $text
    );
}

if (strpos($text, "'receiptsCount'") === false) {
    $text = str_replace(
        "'invoicesCount' => Invoice::count(),",
        "'invoicesCount' => Invoice::count(),\n            'receiptsCount' => Receipt::count(),",
        $text
    );
}

file_put_contents($path, $text);
PHP

# Update dashboard view with receipt button and count.
php <<'PHP'
<?php
$path = 'resources/views/dashboard.blade.php';
$text = file_get_contents($path);

if (strpos($text, 'web.receipts.create') === false) {
    $marker = '        <a class="button secondary" href="{{ route(\'web.company.edit\') }}">Company settings</a>' . "\n";
    $button = <<<'BLADE'
        <a class="button secondary" href="{{ route('web.receipts.create') }}">Upload receipt</a>
BLADE;
    $text = str_replace($marker, $marker . $button . "\n", $text);
}

if (strpos($text, 'Receipts</div><div class="stat">{{ $receiptsCount }}') === false) {
    $marker = '    <div class="card"><div class="muted">Invoices</div><div class="stat">{{ $invoicesCount }}</div></div>' . "\n";
    $countCard = <<<'BLADE'
    <div class="card"><div class="muted">Receipts</div><div class="stat">{{ $receiptsCount }}</div></div>
BLADE;
    $text = str_replace($marker, $marker . $countCard . "\n", $text);
}

file_put_contents($path, $text);
PHP

php artisan migrate
php artisan route:clear
php artisan view:clear
php artisan optimize:clear

echo "Milestone 5 receipts scaffold installed."
echo "Start/restart Laravel:"
echo "  php artisan serve"
echo ""
echo "Open:"
echo "  http://127.0.0.1:8000/receipts"
echo ""
echo "Try: Receipts -> Upload receipt -> Save -> Approve"
