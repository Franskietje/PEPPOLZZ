@extends('layouts.app', ['title' => 'Contacts'])

@section('content')
<div class="card actions">
    <h1>Contacts</h1>
    <a class="button" href="{{ route('web.contacts.create') }}">Add contact</a>
</div>

<div class="card">
    <table>
        <thead><tr><th>Name</th><th>Type</th><th>VAT</th><th>City</th><th>Email</th></tr></thead>
        <tbody>
        @forelse ($contacts as $contact)
            <tr>
                <td>{{ $contact->name }}</td>
                <td><span class="status-badge">{{ $contact->type }}</span></td>
                <td>{{ $contact->vat_number }}</td>
                <td>{{ $contact->city }}</td>
                <td>{{ $contact->email }}</td>
            </tr>
        @empty
            <tr><td colspan="5">No contacts yet.</td></tr>
        @endforelse
        </tbody>
    </table>
</div>
@endsection
