@extends('layouts.app', ['title' => 'Receipts'])

@section('content')
<div class="card actions">
    <h1>Receipts</h1>
    <a class="button" href="{{ route('web.receipts.create') }}">Upload receipt</a>
</div>

<div class="card">
    <table>
        <thead>
            <tr>
                <th>Date</th>
                <th>Supplier</th>
                <th>Category</th>
                <th>Status</th>
                <th class="right">VAT</th>
                <th class="right">Total</th>
                <th></th>
            </tr>
        </thead>
        <tbody>
        @forelse ($receipts as $receipt)
            <tr>
                <td><a href="{{ route('web.receipts.show', $receipt) }}">{{ $receipt->receipt_date?->format('Y-m-d') ?? 'No date' }}</a></td>
                <td>{{ $receipt->supplier?->name ?? 'Unknown supplier' }}</td>
                <td>{{ $receipt->category }}</td>
                <td><span class="status-badge status-{{ $receipt->status }}">{{ str_replace('_', ' ', $receipt->status) }}</span></td>
                <td class="right">€ {{ number_format((float) $receipt->total_vat, 2, ',', '.') }}</td>
                <td class="right">€ {{ number_format((float) $receipt->total_inc_vat, 2, ',', '.') }}</td>
                <td class="right">
                    <form method="post" action="{{ route('web.receipts.destroy', $receipt) }}" onsubmit="return confirm('Delete this receipt permanently?')">
                        @csrf
                        @method('DELETE')
                        <button class="danger" type="submit">Delete</button>
                    </form>
                </td>
            </tr>
        @empty
            <tr><td colspan="7">No receipts yet.</td></tr>
        @endforelse
        </tbody>
    </table>
</div>
@endsection
