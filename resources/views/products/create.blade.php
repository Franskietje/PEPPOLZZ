@extends('layouts.app', ['title' => 'Add product'])

@section('content')
<div class="card">
    <h1>Add product</h1>
    <form method="post" action="{{ route('web.products.store') }}">
        @csrf
        <div class="grid">
            <div class="field"><label>Name</label><input name="name" required value="{{ old('name') }}"></div>
            <div class="field"><label>Price ex VAT</label><input name="unit_price_ex_vat" type="number" step="0.01" min="0" required value="{{ old('unit_price_ex_vat', '0.00') }}"></div>
            <div class="field"><label>VAT rate</label><input name="vat_rate" type="number" step="0.01" min="0" max="100" required value="{{ old('vat_rate', '21.00') }}"></div>
            <div class="field"><label>Unit code</label><input name="unit_code" required value="{{ old('unit_code', 'C62') }}"></div>
            <div class="field"><label>Account code</label><input name="account_code" value="{{ old('account_code') }}"></div>
        </div>
        <div class="field"><label>Description</label><textarea name="description" rows="3">{{ old('description') }}</textarea></div>
        <button type="submit">Save product</button>
    </form>
</div>
@endsection
