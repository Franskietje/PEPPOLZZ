@extends('layouts.app', ['title' => 'Dashboard'])

@section('content')
<div class="card hero-card">
    <div class="hero-grid">
        <div>
            <div class="page-eyebrow">Operations Dashboard</div>
            <h1>Strategic finance administration, kept clear and current.</h1>
            <p class="muted" style="max-width: 60ch; color: rgba(247, 247, 245, 0.82);">Manage sales invoices, incoming UBL files, receipts, and company records from one branded workspace built around clarity and dependable follow-up.</p>
            <div class="actions">
                <a class="button" href="{{ route('web.invoices.create') }}">Create invoice</a>
                <a class="button secondary" href="{{ route('web.incoming-invoices.create') }}">Import incoming XML</a>
                <a class="button secondary" href="{{ route('web.receipts.create') }}">Upload receipt</a>
            </div>
        </div>
        <div class="hero-panel">
            <div class="page-eyebrow" style="margin-bottom: 10px;">Quick Actions</div>
            <div class="actions">
                <a class="button secondary" href="{{ route('web.contacts.create') }}">Add contact</a>
                <a class="button secondary" href="{{ route('web.products.create') }}">Add product</a>
                <a class="button secondary" href="{{ route('web.company.edit') }}">Company settings</a>
            </div>
        </div>
    </div>
</div>

<div class="grid">
    <div class="card stat-card">
        <div class="metric-label">Contacts</div>
        <div class="stat">{{ $contactsCount }}</div>
        <p class="muted">Client and supplier records available for invoicing flows.</p>
    </div>
    <div class="card stat-card">
        <div class="metric-label">Products</div>
        <div class="stat">{{ $productsCount }}</div>
        <p class="muted">Reusable service lines and product definitions.</p>
    </div>
    <div class="card stat-card">
        <div class="metric-label">Sales invoices</div>
        <div class="stat">{{ $invoicesCount }}</div>
        <p class="muted">Outgoing invoices prepared under the Franssiss identity.</p>
    </div>
    <div class="card stat-card">
        <div class="metric-label">Incoming invoices</div>
        <div class="stat">{{ $incomingInvoicesCount }}</div>
        <p class="muted">Imported UBL or XML files awaiting approval or booking.</p>
    </div>
    <div class="card stat-card">
        <div class="metric-label">Receipts</div>
        <div class="stat">{{ $receiptsCount }}</div>
        <p class="muted">Scanned expense records ready for review and OCR handling.</p>
    </div>
</div>

<div class="card">
    <div class="page-eyebrow">Latest Activity</div>
    <h2>Recent invoices</h2>
    <table>
        <thead><tr><th>Number</th><th>Customer</th><th>Status</th><th>Total</th></tr></thead>
        <tbody>
        @forelse ($recentInvoices as $invoice)
            <tr>
                <td><a href="{{ route('web.invoices.show', $invoice) }}">{{ $invoice->invoice_number }}</a></td>
                <td>{{ $invoice->customer?->name }}</td>
                <td><span class="status-badge status-{{ $invoice->status }}">{{ $invoice->status }}</span></td>
                <td>€ {{ number_format((float) $invoice->total_inc_vat, 2, ',', '.') }}</td>
            </tr>
        @empty
            <tr><td colspan="4">No invoices yet.</td></tr>
        @endforelse
        </tbody>
    </table>
</div>
@endsection
