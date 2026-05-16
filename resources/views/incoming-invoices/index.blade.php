@extends('layouts.app', ['title' => 'Incoming invoices'])

@section('content')
<div class="card actions">
    <h1>Incoming Invoices</h1>
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
                <td><span class="status-badge status-{{ $incomingInvoice->status }}">{{ str_replace('_', ' ', $incomingInvoice->status) }}</span></td>
                <td class="right">€ {{ number_format((float) $incomingInvoice->total_inc_vat, 2, ',', '.') }}</td>
            </tr>
        @empty
            <tr><td colspan="6">No incoming invoices yet.</td></tr>
        @endforelse
        </tbody>
    </table>
</div>
@endsection
