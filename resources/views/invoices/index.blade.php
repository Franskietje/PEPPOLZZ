@extends('layouts.app', ['title' => 'Invoices'])

@section('content')
<div class="card actions">
    <h1>Sales Invoices</h1>
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
                <td><span class="status-badge status-{{ $invoice->status }}">{{ $invoice->status }}</span></td>
                <td class="right">€ {{ number_format((float) $invoice->total_inc_vat, 2, ',', '.') }}</td>
            </tr>
        @empty
            <tr><td colspan="6">No invoices yet.</td></tr>
        @endforelse
        </tbody>
    </table>
</div>
@endsection
