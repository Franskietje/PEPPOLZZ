@extends('layouts.app', ['title' => 'Incoming invoice'])

@section('content')
<div class="card">
    <div class="actions">
        <h1>Incoming invoice {{ $incomingInvoice->invoice_number ?? '#' . $incomingInvoice->id }}</h1>
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
    <p class="muted">Status: <span class="status-badge status-{{ $incomingInvoice->status }}">{{ str_replace('_', ' ', $incomingInvoice->status) }}</span> · File: {{ $incomingInvoice->original_file_name }}</p>
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
