#!/usr/bin/env bash
set -euo pipefail

# Run this from the Laravel project root after the Milestone 1 web UI scaffold.
# It installs DomPDF and adds a downloadable PDF invoice button/page.

mkdir -p resources/views/pdf

if ! composer show barryvdh/laravel-dompdf >/dev/null 2>&1; then
  composer require barryvdh/laravel-dompdf
fi

# Add Pdf facade import and downloadPdf method to the existing Web InvoiceController.
php <<'PHP'
<?php
$path = 'app/Http/Controllers/Web/InvoiceController.php';
$text = file_get_contents($path);

if (strpos($text, 'use Barryvdh\\DomPDF\\Facade\\Pdf;') === false) {
    $text = str_replace(
        "namespace App\\Http\\Controllers\\Web;\n\n",
        "namespace App\\Http\\Controllers\\Web;\n\nuse Barryvdh\\DomPDF\\Facade\\Pdf;\n",
        $text
    );
}

$method = <<<'METHOD'

    public function downloadPdf(Invoice $invoice)
    {
        $invoice->load(['company', 'customer', 'lines.product']);

        $pdf = Pdf::loadView('pdf.invoice', [
            'invoice' => $invoice,
        ])->setPaper('a4');

        return $pdf->download($invoice->invoice_number . '.pdf');
    }
METHOD;

if (strpos($text, 'function downloadPdf') === false) {
    $marker = "\n    public function markPaid(Invoice \$invoice): RedirectResponse\n";
    $text = str_replace($marker, $method . $marker, $text);
}

file_put_contents($path, $text);
PHP

cat > resources/views/pdf/invoice.blade.php <<'BLADE'
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <title>{{ $invoice->invoice_number }}</title>
    <style>
        body {
            font-family: DejaVu Sans, sans-serif;
            font-size: 12px;
            color: #111827;
            margin: 0;
            padding: 0;
        }
        .page {
            padding: 28px;
        }
        .header {
            width: 100%;
            margin-bottom: 28px;
        }
        .header td {
            vertical-align: top;
        }
        h1 {
            margin: 0 0 8px;
            font-size: 28px;
        }
        h2 {
            margin: 0 0 8px;
            font-size: 15px;
        }
        .muted {
            color: #6b7280;
        }
        .box {
            border: 1px solid #e5e7eb;
            padding: 12px;
            border-radius: 6px;
            margin-bottom: 18px;
        }
        table.lines {
            width: 100%;
            border-collapse: collapse;
            margin-top: 18px;
        }
        table.lines th,
        table.lines td {
            border-bottom: 1px solid #e5e7eb;
            padding: 8px;
            text-align: left;
        }
        table.lines th {
            background: #f3f4f6;
            font-size: 11px;
            text-transform: uppercase;
            letter-spacing: .04em;
        }
        .right {
            text-align: right !important;
        }
        .totals {
            width: 300px;
            margin-left: auto;
            margin-top: 18px;
            border-collapse: collapse;
        }
        .totals td {
            padding: 7px 8px;
            border-bottom: 1px solid #e5e7eb;
        }
        .total-row td {
            font-weight: bold;
            font-size: 14px;
            border-top: 2px solid #111827;
        }
        .footer {
            margin-top: 36px;
            font-size: 10px;
            color: #6b7280;
        }
    </style>
</head>
<body>
<div class="page">
    <table class="header">
        <tr>
            <td style="width: 55%;">
                <h1>Invoice</h1>
                <div><strong>{{ $invoice->invoice_number }}</strong></div>
                <div class="muted">Issue date: {{ $invoice->issue_date?->format('Y-m-d') }}</div>
                <div class="muted">Due date: {{ $invoice->due_date?->format('Y-m-d') }}</div>
                <div class="muted">Status: {{ ucfirst($invoice->status) }}</div>
            </td>
            <td style="width: 45%; text-align: right;">
                <h2>{{ $invoice->company?->legal_name }}</h2>
                <div>{{ $invoice->company?->address_line1 }}</div>
                @if ($invoice->company?->address_line2)<div>{{ $invoice->company->address_line2 }}</div>@endif
                <div>{{ $invoice->company?->postal_code }} {{ $invoice->company?->city }}</div>
                <div>{{ $invoice->company?->country_code }}</div>
                @if ($invoice->company?->vat_number)<div>VAT: {{ $invoice->company->vat_number }}</div>@endif
                @if ($invoice->company?->email)<div>{{ $invoice->company->email }}</div>@endif
            </td>
        </tr>
    </table>

    <table style="width:100%; margin-bottom:18px;">
        <tr>
            <td style="width:50%; vertical-align:top; padding-right:12px;">
                <div class="box">
                    <h2>Bill to</h2>
                    <strong>{{ $invoice->customer?->name }}</strong><br>
                    {{ $invoice->customer?->address_line1 }}<br>
                    @if ($invoice->customer?->address_line2){{ $invoice->customer->address_line2 }}<br>@endif
                    {{ $invoice->customer?->postal_code }} {{ $invoice->customer?->city }}<br>
                    {{ $invoice->customer?->country_code }}<br>
                    @if ($invoice->customer?->vat_number)VAT: {{ $invoice->customer->vat_number }}<br>@endif
                    @if ($invoice->customer?->email){{ $invoice->customer->email }}@endif
                </div>
            </td>
            <td style="width:50%; vertical-align:top; padding-left:12px;">
                <div class="box">
                    <h2>Payment</h2>
                    @if ($invoice->company?->iban)<div>IBAN: {{ $invoice->company->iban }}</div>@endif
                    @if ($invoice->company?->bic)<div>BIC: {{ $invoice->company->bic }}</div>@endif
                    @if ($invoice->payment_reference)<div>Reference: {{ $invoice->payment_reference }}</div>@endif
                    <div>Currency: {{ $invoice->currency }}</div>
                </div>
            </td>
        </tr>
    </table>

    <table class="lines">
        <thead>
            <tr>
                <th>Description</th>
                <th class="right">Qty</th>
                <th class="right">Unit price</th>
                <th class="right">VAT</th>
                <th class="right">Line total</th>
            </tr>
        </thead>
        <tbody>
        @forelse ($invoice->lines as $line)
            <tr>
                <td>{{ $line->description }}</td>
                <td class="right">{{ number_format((float) $line->quantity, 3, ',', '.') }}</td>
                <td class="right">€ {{ number_format((float) $line->unit_price_ex_vat, 2, ',', '.') }}</td>
                <td class="right">{{ number_format((float) $line->vat_rate, 2, ',', '.') }}%</td>
                <td class="right">€ {{ number_format((float) $line->line_total_inc_vat, 2, ',', '.') }}</td>
            </tr>
        @empty
            <tr><td colspan="5">No invoice lines.</td></tr>
        @endforelse
        </tbody>
    </table>

    <table class="totals">
        <tr>
            <td>Subtotal ex VAT</td>
            <td class="right">€ {{ number_format((float) $invoice->subtotal_ex_vat, 2, ',', '.') }}</td>
        </tr>
        <tr>
            <td>VAT</td>
            <td class="right">€ {{ number_format((float) $invoice->total_vat, 2, ',', '.') }}</td>
        </tr>
        <tr class="total-row">
            <td>Total inc VAT</td>
            <td class="right">€ {{ number_format((float) $invoice->total_inc_vat, 2, ',', '.') }}</td>
        </tr>
    </table>

    @if ($invoice->notes)
        <div class="box" style="margin-top:24px;">
            <h2>Notes</h2>
            {{ $invoice->notes }}
        </div>
    @endif

    <div class="footer">
        Generated by local invoicing app. Keep a copy of this invoice with your accounting records.
    </div>
</div>
</body>
</html>
BLADE

# Add web route for PDF download.
php <<'PHP'
<?php
$path = 'routes/web.php';
$text = file_get_contents($path);
$route = "Route::get('/invoices/{invoice}/pdf', [InvoiceController::class, 'downloadPdf'])->name('web.invoices.pdf');\n";

if (strpos($text, 'web.invoices.pdf') === false) {
    $marker = "Route::get('/invoices/{invoice}', [InvoiceController::class, 'show'])->name('web.invoices.show');\n";
    $text = str_replace($marker, $route . $marker, $text);
}

file_put_contents($path, $text);
PHP

# Add a Download PDF button to invoice show page.
php <<'PHP'
<?php
$path = 'resources/views/invoices/show.blade.php';
$text = file_get_contents($path);
$button = <<<'BLADE'

        <a class="button secondary" href="{{ route('web.invoices.pdf', $invoice) }}">Download PDF</a>

BLADE;

if (strpos($text, 'web.invoices.pdf') === false) {
    $marker = "        @if (\$invoice->status !== 'paid')\n";
    $text = str_replace($marker, $button . $marker, $text);
}

file_put_contents($path, $text);
PHP

php artisan route:clear
php artisan view:clear
php artisan optimize:clear

echo "Milestone 2 PDF scaffold installed."
echo "Start/restart Laravel:"
echo "  php artisan serve"
echo ""
echo "Open an invoice and click Download PDF:"
echo "  http://127.0.0.1:8000/invoices"
