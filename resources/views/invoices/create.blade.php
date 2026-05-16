@extends('layouts.app', ['title' => 'Create invoice'])

@section('content')
<div class="card">
    <h1>Create invoice</h1>

    @if ($companies->isEmpty())
        <p>No company found. Run <code>php artisan migrate:fresh --seed</code> or add a company first.</p>
    @elseif ($customers->isEmpty())
        <p>No customers found. Create a customer first.</p>
        <a class="button" href="{{ route('web.contacts.create') }}">Add customer</a>
    @else
        <form method="post" action="{{ route('web.invoices.store') }}">
            @csrf
            <div class="grid">
                <div class="field">
                    <label>Company</label>
                    <select name="company_id" required>
                        @foreach ($companies as $company)
                            <option value="{{ $company->id }}">{{ $company->legal_name }}</option>
                        @endforeach
                    </select>
                </div>
                <div class="field">
                    <label>Customer</label>
                    <select name="customer_id" required>
                        @foreach ($customers as $customer)
                            <option value="{{ $customer->id }}">{{ $customer->name }}</option>
                        @endforeach
                    </select>
                </div>
                <div class="field"><label>Issue date</label><input name="issue_date" type="date" required value="{{ old('issue_date', now()->toDateString()) }}"></div>
                <div class="field"><label>Due date</label><input name="due_date" type="date" required value="{{ old('due_date', now()->addDays(30)->toDateString()) }}"></div>
            </div>
            <div class="field"><label>Notes</label><textarea name="notes" rows="3">{{ old('notes') }}</textarea></div>
            <button type="submit">Create invoice</button>
        </form>
    @endif
</div>
@endsection
