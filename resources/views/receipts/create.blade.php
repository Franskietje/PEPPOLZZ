@extends('layouts.app', ['title' => 'Upload receipt'])

@section('content')
<div class="card">
    <h1>Upload receipt</h1>
    <p class="muted">Upload an image receipt such as JPG or PNG for OCR. PDF upload is stored, but OCR for PDFs will come later.</p>

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
