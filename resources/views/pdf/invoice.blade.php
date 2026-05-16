<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <title>{{ $invoice->invoice_number }}</title>
    <style>
        @page {
            margin: 26px;
        }
        body {
            font-family: DejaVu Sans, sans-serif;
            font-size: 12px;
            color: #1F2328;
            margin: 0;
            padding: 0;
            background: #F7F7F5;
        }
        .page {
            padding: 18px 20px 24px;
            background: #FFFFFF;
            border: 1px solid #E7EAEE;
        }
        .header {
            width: 100%;
            margin-bottom: 26px;
            border-bottom: 1px solid #E7EAEE;
            padding-bottom: 18px;
        }
        .header td {
            vertical-align: top;
        }
        h1 {
            margin: 0 0 8px;
            font-size: 26px;
            letter-spacing: 0.08em;
            color: #0D1B2A;
        }
        h2 {
            margin: 0 0 8px;
            font-size: 14px;
            text-transform: uppercase;
            letter-spacing: .12em;
            color: #0D1B2A;
        }
        .muted {
            color: #8A96A3;
        }
        .brand-wordmark {
            font-size: 34px;
            line-height: 1;
            color: #1F2328;
            margin-bottom: 10px;
        }
        .brand-wordmark .bv {
            color: #B8865B;
            font-size: 16px;
            margin-left: 6px;
            letter-spacing: .18em;
        }
        .brand-subtitle {
            color: #1F2328;
            font-size: 10px;
            letter-spacing: .42em;
            text-transform: uppercase;
        }
        .box {
            border: 1px solid #E7EAEE;
            background: #FBFAF8;
            padding: 14px;
            border-radius: 10px;
            margin-bottom: 18px;
        }
        table.lines {
            width: 100%;
            border-collapse: collapse;
            margin-top: 18px;
        }
        table.lines th,
        table.lines td {
            border-bottom: 1px solid #E7EAEE;
            padding: 9px 8px;
            text-align: left;
        }
        table.lines th {
            background: #F7F7F5;
            font-size: 11px;
            text-transform: uppercase;
            letter-spacing: .12em;
            color: #0D1B2A;
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
            border-bottom: 1px solid #E7EAEE;
        }
        .total-row td {
            font-weight: bold;
            font-size: 14px;
            border-top: 2px solid #0D1B2A;
            color: #0D1B2A;
        }
        .footer {
            margin-top: 36px;
            font-size: 10px;
            color: #8A96A3;
            border-top: 1px solid #E7EAEE;
            padding-top: 12px;
        }
        .invoice-kicker {
            color: #B8865B;
            font-size: 10px;
            text-transform: uppercase;
            letter-spacing: .22em;
            margin-bottom: 8px;
        }
        .invoice-meta {
            margin-top: 10px;
        }
        .invoice-meta div {
            margin-bottom: 3px;
        }
    </style>
</head>
<body>
<div class="page">
    <table class="header">
        <tr>
            <td style="width: 55%;">
                <div class="brand-wordmark">franssiss <span class="bv">BV</span></div>
                <div class="brand-subtitle">Management &amp; Consultancy</div>
            </td>
            <td style="width: 45%; text-align: right;">
                <div class="invoice-kicker">Factuur</div>
                <h1 style="margin-bottom: 6px;">{{ $invoice->invoice_number }}</h1>
                <div class="invoice-meta muted">
                    <div>Issue date: {{ $invoice->issue_date?->format('Y-m-d') }}</div>
                    <div>Due date: {{ $invoice->due_date?->format('Y-m-d') }}</div>
                    <div>Status: {{ ucfirst($invoice->status) }}</div>
                </div>
            </td>
        </tr>
        <tr>
            <td style="padding-top: 18px; width: 55%;">
                <h2>{{ $invoice->company?->legal_name }}</h2>
                <div>{{ $invoice->company?->address_line1 }}</div>
                @if ($invoice->company?->address_line2)<div>{{ $invoice->company->address_line2 }}</div>@endif
                <div>{{ $invoice->company?->postal_code }} {{ $invoice->company?->city }}</div>
                <div>{{ $invoice->company?->country_code }}</div>
                @if ($invoice->company?->vat_number)<div>VAT: {{ $invoice->company->vat_number }}</div>@endif
                @if ($invoice->company?->email)<div>{{ $invoice->company->email }}</div>@endif
            </td>
            <td style="padding-top: 18px;"></td>
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
        Franssiss BV invoice document. Keep a copy of this invoice with your accounting records.
    </div>
</div>
</body>
</html>
