@extends('layouts.app', ['title' => 'Company settings'])

@section('content')
<div class="card">
    <h1>Company settings</h1>
    <p class="muted">These details appear on your PDF invoices and UBL XML exports.</p>

    <form method="post" action="{{ route('web.company.update') }}">
        @csrf
        @method('PUT')

        <h2>Legal details</h2>
        <div class="grid">
            <div class="field">
                <label>Legal name</label>
                <input name="legal_name" required value="{{ old('legal_name', $company->legal_name) }}">
            </div>
            <div class="field">
                <label>VAT number</label>
                <input name="vat_number" value="{{ old('vat_number', $company->vat_number) }}" placeholder="BE0123456789">
            </div>
            <div class="field">
                <label>Enterprise number</label>
                <input name="enterprise_number" value="{{ old('enterprise_number', $company->enterprise_number) }}" placeholder="0123456789">
            </div>
            <div class="field">
                <label>Email</label>
                <input name="email" type="email" value="{{ old('email', $company->email) }}">
            </div>
        </div>

        <h2>Address</h2>
        <div class="grid">
            <div class="field">
                <label>Address line 1</label>
                <input name="address_line1" value="{{ old('address_line1', $company->address_line1) }}">
            </div>
            <div class="field">
                <label>Address line 2</label>
                <input name="address_line2" value="{{ old('address_line2', $company->address_line2) }}">
            </div>
            <div class="field">
                <label>Postal code</label>
                <input name="postal_code" value="{{ old('postal_code', $company->postal_code) }}">
            </div>
            <div class="field">
                <label>City</label>
                <input name="city" value="{{ old('city', $company->city) }}">
            </div>
            <div class="field">
                <label>Country code</label>
                <input name="country_code" maxlength="2" required value="{{ old('country_code', $company->country_code ?? 'BE') }}">
            </div>
        </div>

        <h2>Payment details</h2>
        <div class="grid">
            <div class="field">
                <label>IBAN</label>
                <input name="iban" value="{{ old('iban', $company->iban) }}" placeholder="BE68539007547034">
            </div>
            <div class="field">
                <label>BIC</label>
                <input name="bic" value="{{ old('bic', $company->bic) }}" placeholder="BBRUBEBB">
            </div>
            <div class="field">
                <label>Default currency</label>
                <input name="default_currency" maxlength="3" required value="{{ old('default_currency', $company->default_currency ?? 'EUR') }}">
            </div>
        </div>

        <h2>Invoice numbering</h2>
        <div class="grid">
            <div class="field">
                <label>Invoice number prefix</label>
                <input name="invoice_number_prefix" required value="{{ old('invoice_number_prefix', $company->invoice_number_prefix ?? 'INV') }}">
            </div>
            <div class="field">
                <label>Next invoice number</label>
                <input name="next_invoice_number" type="number" min="1" required value="{{ old('next_invoice_number', $company->next_invoice_number ?? 1) }}">
            </div>
        </div>

        <button type="submit">Save company settings</button>
    </form>
</div>
@endsection
