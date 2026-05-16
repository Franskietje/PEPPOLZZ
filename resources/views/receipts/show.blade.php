@extends('layouts.app', ['title' => 'Receipt'])

@section('content')
<div class="card">
    <div class="actions">
        <h1>Receipt #{{ $receipt->id }}</h1>
        <a class="button secondary" href="{{ route('web.receipts.download', $receipt) }}">Download original</a>

            <form method="post" action="{{ route('web.receipts.ocr', $receipt) }}">
                @csrf
                <button type="submit" class="secondary">Run OCR</button>
            </form>
            @if ($receipt->ocr_status === 'processed')
                <form method="post" action="{{ route('web.receipts.apply-ocr', $receipt) }}">
                    @csrf
                    <button type="submit" class="secondary">Apply OCR suggestions</button>
                </form>
            @endif
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
        Status: <span class="status-badge status-{{ $receipt->status }}">{{ str_replace('_', ' ', $receipt->status) }}</span> · File: {{ $receipt->original_file_name }}
    </p>
</div>


<div class="card">
    <h2>Preview</h2>
    @if (str_starts_with((string) $receipt->mime_type, 'image/'))
        <img src="{{ route('web.receipts.view', $receipt) }}" alt="Receipt preview" style="max-width:100%; border:1px solid #e5e7eb; border-radius:12px;">
    @elseif ($receipt->mime_type === 'application/pdf')
        <iframe src="{{ route('web.receipts.view', $receipt) }}" style="width:100%; height:700px; border:1px solid #e5e7eb; border-radius:12px;"></iframe>
    @else
        <p class="muted">No inline preview available for this file type.</p>
    @endif
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
@if ($receipt->ocr_status !== 'not_processed')
<div class="card">
    <h2>OCR result</h2>
    <p class="muted">
        Status: <span class="status-badge status-{{ $receipt->ocr_status }}">{{ str_replace('_', ' ', $receipt->ocr_status) }}</span>
        @if ($receipt->ocr_processed_at)
            · Processed: {{ $receipt->ocr_processed_at->format('Y-m-d H:i') }}
        @endif
    </p>

    @if ($receipt->ocr_data)
        <h3>Suggestions</h3>
        <p class="muted">Click Apply OCR suggestions above to copy these into the review form, then verify them manually.</p>
        <table>
            <tr><th>Date</th><td>{{ $receipt->ocr_data['date'] ?? 'No guess' }}</td></tr>
            <tr><th>Total inc VAT</th><td>{{ isset($receipt->ocr_data['total_inc_vat']) ? '€ ' . number_format((float) $receipt->ocr_data['total_inc_vat'], 2, ',', '.') : 'No guess' }}</td></tr>
            <tr><th>Total VAT</th><td>{{ isset($receipt->ocr_data['total_vat']) ? '€ ' . number_format((float) $receipt->ocr_data['total_vat'], 2, ',', '.') : 'No guess' }}</td></tr>
            @if (!empty($receipt->ocr_data['error']))
                <tr><th>Error</th><td>{{ $receipt->ocr_data['error'] }}</td></tr>
            @endif
        </table>
    @endif

    @if ($receipt->ocr_text)
        <h3>Raw OCR text</h3>
        <textarea rows="14" readonly>{{ $receipt->ocr_text }}</textarea>
    @endif
</div>
@endif
@endsection