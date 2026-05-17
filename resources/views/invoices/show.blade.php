@extends('layouts.app', ['title' => $invoice->invoice_number])

@section('content')
<div class="card">
    <div class="actions">
        <h1>Invoice {{ $invoice->invoice_number }}</h1>

        <a class="button secondary" href="{{ route('web.invoices.pdf', $invoice) }}">Download PDF</a>

        <a class="button secondary" href="{{ route('web.invoices.ubl', $invoice) }}">Download UBL XML</a>
        @if ($invoice->status !== 'paid')
            <form method="post" action="{{ route('web.invoices.mark-paid', $invoice) }}">
                @csrf
                <button type="submit" class="secondary">Mark paid</button>
            </form>
        @endif
        <form method="post" action="{{ route('web.invoices.destroy', $invoice) }}" onsubmit="return confirm('Delete this invoice permanently?')">
            @csrf
            @method('DELETE')
            <button class="danger" type="submit">Delete</button>
        </form>
    </div>
    <p class="muted">
        {{ $invoice->company?->legal_name }} → {{ $invoice->customer?->name }}<br>
        Issue date: {{ $invoice->issue_date?->format('Y-m-d') }} · Due date: {{ $invoice->due_date?->format('Y-m-d') }} ·
        <span class="status-badge status-{{ $invoice->status }}">{{ $invoice->status }}</span>
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
