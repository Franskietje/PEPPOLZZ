#!/usr/bin/env bash
set -euo pipefail

# Run this from the Laravel project root after the receipt review helpers scaffold.
# It adds manual incoming supplier invoice import via UBL/XML upload.
# Later, a Peppol receive webhook can reuse the same parser and tables.

mkdir -p app/Http/Controllers/Web app/Models app/Services resources/views/incoming-invoices database/migrations

cat > database/migrations/2026_05_13_000008_create_incoming_invoices_table.php <<'PHP'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('incoming_invoices', function (Blueprint $table) {
            $table->id();
            $table->foreignId('supplier_id')->nullable()->constrained('contacts')->nullOnDelete();
            $table->string('supplier_name')->nullable();
            $table->string('supplier_vat_number')->nullable()->index();
            $table->string('invoice_number')->nullable()->index();
            $table->date('issue_date')->nullable();
            $table->date('due_date')->nullable();
            $table->string('currency', 3)->default('EUR');
            $table->decimal('subtotal_ex_vat', 12, 2)->default(0);
            $table->decimal('total_vat', 12, 2)->default(0);
            $table->decimal('total_inc_vat', 12, 2)->default(0);
            $table->string('status')->default('needs_review'); // needs_review, approved, rejected
            $table->string('original_file_path');
            $table->string('original_file_name')->nullable();
            $table->json('parsed_data')->nullable();
            $table->text('notes')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('incoming_invoices');
    }
};
PHP

cat > database/migrations/2026_05_13_000009_create_incoming_invoice_lines_table.php <<'PHP'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('incoming_invoice_lines', function (Blueprint $table) {
            $table->id();
            $table->foreignId('incoming_invoice_id')->constrained()->cascadeOnDelete();
            $table->string('line_number')->nullable();
            $table->text('description')->nullable();
            $table->decimal('quantity', 12, 3)->default(1);
            $table->string('unit_code')->default('C62');
            $table->decimal('unit_price_ex_vat', 12, 2)->default(0);
            $table->decimal('vat_rate', 5, 2)->default(0);
            $table->decimal('line_total_ex_vat', 12, 2)->default(0);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('incoming_invoice_lines');
    }
};
PHP

cat > app/Models/IncomingInvoice.php <<'PHP'
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class IncomingInvoice extends Model
{
    use HasFactory;

    protected $guarded = [];

    protected $casts = [
        'issue_date' => 'date',
        'due_date' => 'date',
        'parsed_data' => 'array',
    ];

    public function supplier(): BelongsTo
    {
        return $this->belongsTo(Contact::class, 'supplier_id');
    }

    public function lines(): HasMany
    {
        return $this->hasMany(IncomingInvoiceLine::class);
    }
}
PHP

cat > app/Models/IncomingInvoiceLine.php <<'PHP'
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class IncomingInvoiceLine extends Model
{
    use HasFactory;

    protected $guarded = [];

    public function incomingInvoice(): BelongsTo
    {
        return $this->belongsTo(IncomingInvoice::class);
    }
}
PHP

cat > app/Services/UblIncomingInvoiceParser.php <<'PHP'
<?php

namespace App\Services;

use RuntimeException;
use SimpleXMLElement;

class UblIncomingInvoiceParser
{
    public function parseFile(string $absolutePath): array
    {
        if (! file_exists($absolutePath)) {
            throw new RuntimeException('UBL/XML file not found.');
        }

        libxml_use_internal_errors(true);
        $xml = simplexml_load_file($absolutePath);

        if (! $xml instanceof SimpleXMLElement) {
            $errors = collect(libxml_get_errors())->map(fn ($e) => trim($e->message))->implode(' ');
            libxml_clear_errors();
            throw new RuntimeException('Invalid XML file. ' . $errors);
        }

        return $this->parseXml($xml);
    }

    public function parseXml(SimpleXMLElement $xml): array
    {
        $cbc = 'urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2';
        $cac = 'urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2';

        $supplierParty = $xml->children($cac)->AccountingSupplierParty?->children($cac)->Party;
        $supplierName = $this->firstText([
            $supplierParty?->children($cac)->PartyName?->children($cbc)->Name ?? null,
            $supplierParty?->children($cac)->PartyLegalEntity?->children($cbc)->RegistrationName ?? null,
        ]);
        $supplierVat = $this->firstText([
            $supplierParty?->children($cac)->PartyTaxScheme?->children($cbc)->CompanyID ?? null,
            $supplierParty?->children($cbc)->EndpointID ?? null,
        ]);

        $legalTotal = $xml->children($cac)->LegalMonetaryTotal;
        $taxTotal = $xml->children($cac)->TaxTotal;

        $lines = [];
        foreach ($xml->children($cac)->InvoiceLine as $line) {
            $item = $line->children($cac)->Item;
            $price = $line->children($cac)->Price;
            $qtyNode = $line->children($cbc)->InvoicedQuantity;
            $taxCategory = $item?->children($cac)->ClassifiedTaxCategory;

            $quantity = $this->number($qtyNode);
            $unitCode = $qtyNode instanceof SimpleXMLElement ? (string) $qtyNode['unitCode'] : 'C62';

            $lines[] = [
                'line_number' => $this->text($line->children($cbc)->ID),
                'description' => $this->firstText([
                    $item?->children($cbc)->Name ?? null,
                    $item?->children($cbc)->Description ?? null,
                ]),
                'quantity' => $quantity ?: 1,
                'unit_code' => $unitCode ?: 'C62',
                'unit_price_ex_vat' => $this->number($price?->children($cbc)->PriceAmount),
                'vat_rate' => $this->number($taxCategory?->children($cbc)->Percent),
                'line_total_ex_vat' => $this->number($line->children($cbc)->LineExtensionAmount),
            ];
        }

        return [
            'invoice_number' => $this->text($xml->children($cbc)->ID),
            'issue_date' => $this->date($xml->children($cbc)->IssueDate),
            'due_date' => $this->date($xml->children($cbc)->DueDate),
            'currency' => $this->text($xml->children($cbc)->DocumentCurrencyCode) ?: 'EUR',
            'supplier_name' => $supplierName,
            'supplier_vat_number' => $supplierVat,
            'subtotal_ex_vat' => $this->number($legalTotal?->children($cbc)->TaxExclusiveAmount)
                ?: $this->number($legalTotal?->children($cbc)->LineExtensionAmount),
            'total_vat' => $this->number($taxTotal?->children($cbc)->TaxAmount),
            'total_inc_vat' => $this->number($legalTotal?->children($cbc)->TaxInclusiveAmount)
                ?: $this->number($legalTotal?->children($cbc)->PayableAmount),
            'lines' => $lines,
        ];
    }

    private function text(mixed $node): ?string
    {
        if (! $node instanceof SimpleXMLElement) {
            return null;
        }

        $value = trim((string) $node);

        return $value === '' ? null : $value;
    }

    private function firstText(array $nodes): ?string
    {
        foreach ($nodes as $node) {
            $value = $this->text($node);
            if ($value) {
                return $value;
            }
        }

        return null;
    }

    private function number(mixed $node): float
    {
        $value = $this->text($node);

        if ($value === null) {
            return 0.0;
        }

        return round((float) str_replace(',', '.', $value), 2);
    }

    private function date(mixed $node): ?string
    {
        $value = $this->text($node);

        return $value ?: null;
    }
}
PHP

cat > app/Http/Controllers/Web/IncomingInvoiceController.php <<'PHP'
<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\Contact;
use App\Models\IncomingInvoice;
use App\Services\UblIncomingInvoiceParser;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\DB;
use Illuminate\View\View;
use Symfony\Component\HttpFoundation\StreamedResponse;

class IncomingInvoiceController extends Controller
{
    public function index(): View
    {
        return view('incoming-invoices.index', [
            'incomingInvoices' => IncomingInvoice::with('supplier')->latest('id')->get(),
        ]);
    }

    public function create(): View
    {
        return view('incoming-invoices.create');
    }

    public function store(Request $request, UblIncomingInvoiceParser $parser): RedirectResponse
    {
        $data = $request->validate([
            'ubl_file' => [
                'required',
                'file',
                'max:10240',
                'mimetypes:text/xml,application/xml,application/octet-stream,text/plain',
            ],
        ]);

        $file = $request->file('ubl_file');
        $path = $file->store('incoming-invoices', 'local');
        $absolutePath = Storage::disk('local')->path($path);

        try {
            $parsed = $parser->parseFile($absolutePath);
        } catch (\Throwable $e) {
            Storage::disk('local')->delete($path);
            return back()->withErrors(['ubl_file' => $e->getMessage()]);
        }

        $incomingInvoice = DB::transaction(function () use ($parsed, $path, $file) {
            $supplier = $this->findOrCreateSupplier($parsed['supplier_name'] ?? null, $parsed['supplier_vat_number'] ?? null);

            $incomingInvoice = IncomingInvoice::create([
                'supplier_id' => $supplier?->id,
                'supplier_name' => $parsed['supplier_name'] ?? null,
                'supplier_vat_number' => $parsed['supplier_vat_number'] ?? null,
                'invoice_number' => $parsed['invoice_number'] ?? null,
                'issue_date' => $parsed['issue_date'] ?? null,
                'due_date' => $parsed['due_date'] ?? null,
                'currency' => $parsed['currency'] ?? 'EUR',
                'subtotal_ex_vat' => $parsed['subtotal_ex_vat'] ?? 0,
                'total_vat' => $parsed['total_vat'] ?? 0,
                'total_inc_vat' => $parsed['total_inc_vat'] ?? 0,
                'status' => 'needs_review',
                'original_file_path' => $path,
                'original_file_name' => $file->getClientOriginalName(),
                'parsed_data' => $parsed,
            ]);

            foreach ($parsed['lines'] ?? [] as $line) {
                $incomingInvoice->lines()->create($line);
            }

            return $incomingInvoice;
        });

        return redirect()->route('web.incoming-invoices.show', $incomingInvoice)->with('success', 'Incoming UBL invoice imported. Review before approving.');
    }

    public function show(IncomingInvoice $incomingInvoice): View
    {
        return view('incoming-invoices.show', [
            'incomingInvoice' => $incomingInvoice->load(['supplier', 'lines']),
            'suppliers' => Contact::whereIn('type', ['supplier', 'both'])->orderBy('name')->get(),
        ]);
    }

    public function update(Request $request, IncomingInvoice $incomingInvoice): RedirectResponse
    {
        if ($incomingInvoice->status !== 'needs_review') {
            return back()->withErrors(['incoming_invoice' => 'Only invoices that need review can be edited.']);
        }

        $data = $request->validate([
            'supplier_id' => ['nullable', 'exists:contacts,id'],
            'supplier_name' => ['nullable', 'string', 'max:255'],
            'supplier_vat_number' => ['nullable', 'string', 'max:50'],
            'invoice_number' => ['nullable', 'string', 'max:100'],
            'issue_date' => ['nullable', 'date'],
            'due_date' => ['nullable', 'date'],
            'currency' => ['required', 'string', 'size:3'],
            'subtotal_ex_vat' => ['required', 'numeric', 'min:0'],
            'total_vat' => ['required', 'numeric', 'min:0'],
            'total_inc_vat' => ['required', 'numeric', 'min:0'],
            'notes' => ['nullable', 'string'],
        ]);

        $data['currency'] = strtoupper($data['currency']);
        $incomingInvoice->update($data);

        return redirect()->route('web.incoming-invoices.show', $incomingInvoice)->with('success', 'Incoming invoice saved.');
    }

    public function approve(IncomingInvoice $incomingInvoice): RedirectResponse
    {
        $incomingInvoice->update(['status' => 'approved']);

        return redirect()->route('web.incoming-invoices.show', $incomingInvoice)->with('success', 'Incoming invoice approved.');
    }

    public function reject(IncomingInvoice $incomingInvoice): RedirectResponse
    {
        $incomingInvoice->update(['status' => 'rejected']);

        return redirect()->route('web.incoming-invoices.show', $incomingInvoice)->with('success', 'Incoming invoice rejected.');
    }

    public function download(IncomingInvoice $incomingInvoice): StreamedResponse
    {
        return Storage::disk('local')->download(
            $incomingInvoice->original_file_path,
            $incomingInvoice->original_file_name ?: basename($incomingInvoice->original_file_path)
        );
    }

    private function findOrCreateSupplier(?string $name, ?string $vatNumber): ?Contact
    {
        if (! $name && ! $vatNumber) {
            return null;
        }

        if ($vatNumber) {
            $existing = Contact::where('vat_number', $vatNumber)->first();
            if ($existing) {
                return $existing;
            }
        }

        if ($name) {
            $existing = Contact::where('name', $name)->first();
            if ($existing) {
                return $existing;
            }
        }

        return Contact::create([
            'type' => 'supplier',
            'name' => $name ?: 'Unknown supplier',
            'vat_number' => $vatNumber,
            'country_code' => 'BE',
            'default_currency' => 'EUR',
            'payment_terms_days' => 30,
        ]);
    }
}
PHP

cat > resources/views/incoming-invoices/index.blade.php <<'BLADE'
@extends('layouts.app', ['title' => 'Incoming invoices'])

@section('content')
<div class="card actions">
    <h1 style="margin-right:auto">Incoming invoices</h1>
    <a class="button" href="{{ route('web.incoming-invoices.create') }}">Import UBL/XML</a>
</div>

<div class="card">
    <table>
        <thead>
            <tr>
                <th>Invoice number</th>
                <th>Supplier</th>
                <th>Issue date</th>
                <th>Due date</th>
                <th>Status</th>
                <th class="right">Total</th>
            </tr>
        </thead>
        <tbody>
        @forelse ($incomingInvoices as $incomingInvoice)
            <tr>
                <td><a href="{{ route('web.incoming-invoices.show', $incomingInvoice) }}">{{ $incomingInvoice->invoice_number ?? 'No number' }}</a></td>
                <td>{{ $incomingInvoice->supplier?->name ?? $incomingInvoice->supplier_name ?? 'Unknown supplier' }}</td>
                <td>{{ $incomingInvoice->issue_date?->format('Y-m-d') }}</td>
                <td>{{ $incomingInvoice->due_date?->format('Y-m-d') }}</td>
                <td>{{ $incomingInvoice->status }}</td>
                <td class="right">€ {{ number_format((float) $incomingInvoice->total_inc_vat, 2, ',', '.') }}</td>
            </tr>
        @empty
            <tr><td colspan="6">No incoming invoices yet.</td></tr>
        @endforelse
        </tbody>
    </table>
</div>
@endsection
BLADE

cat > resources/views/incoming-invoices/create.blade.php <<'BLADE'
@extends('layouts.app', ['title' => 'Import incoming invoice'])

@section('content')
<div class="card">
    <h1>Import incoming UBL/XML invoice</h1>
    <p class="muted">Upload a supplier invoice XML file. This is the manual version of what Peppol receive will automate later.</p>

    <form method="post" action="{{ route('web.incoming-invoices.store') }}" enctype="multipart/form-data">
        @csrf
        <div class="field">
            <label>UBL/XML file</label>
            <input name="ubl_file" type="file" accept=".xml,.ubl,text/xml,application/xml" required>
        </div>
        <button type="submit">Import invoice</button>
    </form>
</div>
@endsection
BLADE

cat > resources/views/incoming-invoices/show.blade.php <<'BLADE'
@extends('layouts.app', ['title' => 'Incoming invoice'])

@section('content')
<div class="card">
    <div class="actions">
        <h1 style="margin-right:auto">Incoming invoice {{ $incomingInvoice->invoice_number ?? '#' . $incomingInvoice->id }}</h1>
        <a class="button secondary" href="{{ route('web.incoming-invoices.download', $incomingInvoice) }}">Download original XML</a>
        @if ($incomingInvoice->status === 'needs_review')
            <form method="post" action="{{ route('web.incoming-invoices.approve', $incomingInvoice) }}">
                @csrf
                <button type="submit">Approve</button>
            </form>
            <form method="post" action="{{ route('web.incoming-invoices.reject', $incomingInvoice) }}">
                @csrf
                <button class="danger" type="submit">Reject</button>
            </form>
        @endif
    </div>
    <p class="muted">Status: {{ $incomingInvoice->status }} · File: {{ $incomingInvoice->original_file_name }}</p>
</div>

<div class="card">
    <h2>Review details</h2>
    <form method="post" action="{{ route('web.incoming-invoices.update', $incomingInvoice) }}">
        @csrf
        @method('PUT')

        <div class="grid">
            <div class="field">
                <label>Supplier contact</label>
                <select name="supplier_id" @disabled($incomingInvoice->status !== 'needs_review')>
                    <option value="">No linked supplier</option>
                    @foreach ($suppliers as $supplier)
                        <option value="{{ $supplier->id }}" @selected(old('supplier_id', $incomingInvoice->supplier_id) == $supplier->id)>{{ $supplier->name }}</option>
                    @endforeach
                </select>
            </div>
            <div class="field"><label>Supplier name</label><input name="supplier_name" value="{{ old('supplier_name', $incomingInvoice->supplier_name) }}" @disabled($incomingInvoice->status !== 'needs_review')></div>
            <div class="field"><label>Supplier VAT</label><input name="supplier_vat_number" value="{{ old('supplier_vat_number', $incomingInvoice->supplier_vat_number) }}" @disabled($incomingInvoice->status !== 'needs_review')></div>
            <div class="field"><label>Invoice number</label><input name="invoice_number" value="{{ old('invoice_number', $incomingInvoice->invoice_number) }}" @disabled($incomingInvoice->status !== 'needs_review')></div>
            <div class="field"><label>Issue date</label><input name="issue_date" type="date" value="{{ old('issue_date', $incomingInvoice->issue_date?->format('Y-m-d')) }}" @disabled($incomingInvoice->status !== 'needs_review')></div>
            <div class="field"><label>Due date</label><input name="due_date" type="date" value="{{ old('due_date', $incomingInvoice->due_date?->format('Y-m-d')) }}" @disabled($incomingInvoice->status !== 'needs_review')></div>
            <div class="field"><label>Currency</label><input name="currency" maxlength="3" required value="{{ old('currency', $incomingInvoice->currency) }}" @disabled($incomingInvoice->status !== 'needs_review')></div>
            <div class="field"><label>Subtotal ex VAT</label><input name="subtotal_ex_vat" type="number" step="0.01" min="0" required value="{{ old('subtotal_ex_vat', $incomingInvoice->subtotal_ex_vat) }}" @disabled($incomingInvoice->status !== 'needs_review')></div>
            <div class="field"><label>Total VAT</label><input name="total_vat" type="number" step="0.01" min="0" required value="{{ old('total_vat', $incomingInvoice->total_vat) }}" @disabled($incomingInvoice->status !== 'needs_review')></div>
            <div class="field"><label>Total inc VAT</label><input name="total_inc_vat" type="number" step="0.01" min="0" required value="{{ old('total_inc_vat', $incomingInvoice->total_inc_vat) }}" @disabled($incomingInvoice->status !== 'needs_review')></div>
        </div>

        <div class="field"><label>Notes</label><textarea name="notes" rows="3" @disabled($incomingInvoice->status !== 'needs_review')>{{ old('notes', $incomingInvoice->notes) }}</textarea></div>

        @if ($incomingInvoice->status === 'needs_review')
            <button type="submit">Save review</button>
        @endif
    </form>
</div>

<div class="card">
    <h2>Lines parsed from XML</h2>
    <table>
        <thead>
            <tr>
                <th>#</th>
                <th>Description</th>
                <th class="right">Qty</th>
                <th class="right">Unit price</th>
                <th class="right">VAT</th>
                <th class="right">Line ex VAT</th>
            </tr>
        </thead>
        <tbody>
        @forelse ($incomingInvoice->lines as $line)
            <tr>
                <td>{{ $line->line_number }}</td>
                <td>{{ $line->description }}</td>
                <td class="right">{{ number_format((float) $line->quantity, 3, ',', '.') }}</td>
                <td class="right">€ {{ number_format((float) $line->unit_price_ex_vat, 2, ',', '.') }}</td>
                <td class="right">{{ number_format((float) $line->vat_rate, 2, ',', '.') }}%</td>
                <td class="right">€ {{ number_format((float) $line->line_total_ex_vat, 2, ',', '.') }}</td>
            </tr>
        @empty
            <tr><td colspan="6">No lines found in XML.</td></tr>
        @endforelse
        </tbody>
    </table>
</div>
@endsection
BLADE

# Add controller import and routes.
php <<'PHP'
<?php
$path = 'routes/web.php';
$text = file_get_contents($path);

if (strpos($text, 'use App\\Http\\Controllers\\Web\\IncomingInvoiceController;') === false) {
    $text = str_replace(
        "use App\\Http\\Controllers\\Web\\InvoiceController;\n",
        "use App\\Http\\Controllers\\Web\\IncomingInvoiceController;\nuse App\\Http\\Controllers\\Web\\InvoiceController;\n",
        $text
    );
}

$routes = <<<'ROUTES'

Route::get('/incoming-invoices', [IncomingInvoiceController::class, 'index'])->name('web.incoming-invoices.index');
Route::get('/incoming-invoices/create', [IncomingInvoiceController::class, 'create'])->name('web.incoming-invoices.create');
Route::post('/incoming-invoices', [IncomingInvoiceController::class, 'store'])->name('web.incoming-invoices.store');
Route::get('/incoming-invoices/{incomingInvoice}', [IncomingInvoiceController::class, 'show'])->name('web.incoming-invoices.show');
Route::put('/incoming-invoices/{incomingInvoice}', [IncomingInvoiceController::class, 'update'])->name('web.incoming-invoices.update');
Route::get('/incoming-invoices/{incomingInvoice}/download', [IncomingInvoiceController::class, 'download'])->name('web.incoming-invoices.download');
Route::post('/incoming-invoices/{incomingInvoice}/approve', [IncomingInvoiceController::class, 'approve'])->name('web.incoming-invoices.approve');
Route::post('/incoming-invoices/{incomingInvoice}/reject', [IncomingInvoiceController::class, 'reject'])->name('web.incoming-invoices.reject');
ROUTES;

if (strpos($text, 'web.incoming-invoices.index') === false) {
    $marker = "Route::get('/invoices', [InvoiceController::class, 'index'])->name('web.invoices.index');\n";
    $text = str_replace($marker, $routes . "\n" . $marker, $text);
}

file_put_contents($path, $text);
PHP

# Add Incoming link to header.
php <<'PHP'
<?php
$path = 'resources/views/layouts/app.blade.php';
$text = file_get_contents($path);
$link = "        <a href=\"{{ route('web.incoming-invoices.index') }}\">Incoming</a>\n";

if (strpos($text, 'web.incoming-invoices.index') === false) {
    $marker = "        <a href=\"{{ route('web.invoices.index') }}\">Invoices</a>\n";
    if (strpos($text, $marker) === false) {
        $marker = "    <a href=\"{{ route('web.invoices.index') }}\">Invoices</a>\n";
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

if (strpos($text, 'use App\\Models\\IncomingInvoice;') === false) {
    $text = str_replace(
        "use App\\Models\\Invoice;\n",
        "use App\\Models\\IncomingInvoice;\nuse App\\Models\\Invoice;\n",
        $text
    );
}

if (strpos($text, "'incomingInvoicesCount'") === false) {
    $text = str_replace(
        "'invoicesCount' => Invoice::count(),",
        "'invoicesCount' => Invoice::count(),\n            'incomingInvoicesCount' => IncomingInvoice::count(),",
        $text
    );
}

file_put_contents($path, $text);
PHP

# Update dashboard view with import button and count.
php <<'PHP'
<?php
$path = 'resources/views/dashboard.blade.php';
$text = file_get_contents($path);

if (strpos($text, 'web.incoming-invoices.create') === false) {
    $marker = "        <a class=\"button secondary\" href=\"{{ route('web.receipts.create') }}\">Upload receipt</a>\n";
    $text = str_replace($marker, $marker . "        <a class=\"button secondary\" href=\"{{ route('web.incoming-invoices.create') }}\">Import incoming XML</a>\n", $text);
}

if (strpos($text, 'Incoming invoices</div><div class="stat">{{ $incomingInvoicesCount }}') === false) {
    $marker = "    <div class=\"card\"><div class=\"muted\">Invoices</div><div class=\"stat\">{{ \$invoicesCount }}</div></div>\n";
    $card = <<<'BLADE'
    <div class="card"><div class="muted">Incoming invoices</div><div class="stat">{{ $incomingInvoicesCount }}</div></div>
BLADE;
    $text = str_replace($marker, $marker . $card . "\n", $text);
}

file_put_contents($path, $text);
PHP

php artisan migrate
php artisan route:clear
php artisan view:clear
php artisan optimize:clear

echo "Milestone 8 incoming UBL invoices scaffold installed."
echo "Start/restart Laravel:"
echo "  php artisan serve"
echo ""
echo "Open:"
echo "  http://127.0.0.1:8000/incoming-invoices"
echo ""
echo "Test with an XML you exported earlier:"
echo "  1. Open any sales invoice"
echo "  2. Download UBL XML"
echo "  3. Go to Incoming -> Import UBL/XML"
echo "  4. Upload that XML"
echo "  5. Review and approve"
