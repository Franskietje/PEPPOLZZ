@extends('layouts.app', ['title' => 'Add contact'])

@section('content')
<div class="card">
    <h1>Add contact</h1>
    <form method="post" action="{{ route('web.contacts.store') }}">
        @csrf
        <div class="grid">
            <div class="field"><label>Type</label><select name="type"><option value="customer">Customer</option><option value="supplier">Supplier</option><option value="both">Both</option></select></div>
            <div class="field"><label>Name</label><input name="name" required value="{{ old('name') }}"></div>
            <div class="field"><label>VAT number</label><input name="vat_number" value="{{ old('vat_number') }}"></div>
            <div class="field"><label>Enterprise number</label><input name="enterprise_number" value="{{ old('enterprise_number') }}"></div>
            <div class="field"><label>Email</label><input name="email" type="email" value="{{ old('email') }}"></div>
            <div class="field"><label>Address</label><input name="address_line1" value="{{ old('address_line1') }}"></div>
            <div class="field"><label>Postal code</label><input name="postal_code" value="{{ old('postal_code') }}"></div>
            <div class="field"><label>City</label><input name="city" value="{{ old('city') }}"></div>
            <div class="field"><label>Country code</label><input name="country_code" value="{{ old('country_code', 'BE') }}" maxlength="2" required></div>
            <div class="field"><label>Payment terms days</label><input name="payment_terms_days" type="number" value="{{ old('payment_terms_days', 30) }}" required></div>
        </div>
        <button type="submit">Save contact</button>
    </form>
</div>
@endsection
