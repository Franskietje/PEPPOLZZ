@extends('layouts.app', ['title' => 'Products'])

@section('content')
<div class="card actions">
    <h1>Products</h1>
    <a class="button" href="{{ route('web.products.create') }}">Add product</a>
</div>

<div class="card">
    <table>
        <thead><tr><th>Name</th><th>Description</th><th>Price ex VAT</th><th>VAT</th><th>Unit</th></tr></thead>
        <tbody>
        @forelse ($products as $product)
            <tr>
                <td>{{ $product->name }}</td>
                <td>{{ $product->description }}</td>
                <td>€ {{ number_format((float) $product->unit_price_ex_vat, 2, ',', '.') }}</td>
                <td>{{ number_format((float) $product->vat_rate, 2, ',', '.') }}%</td>
                <td>{{ $product->unit_code }}</td>
            </tr>
        @empty
            <tr><td colspan="5">No products yet.</td></tr>
        @endforelse
        </tbody>
    </table>
</div>
@endsection
