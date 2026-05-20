@extends('layouts.app', ['title' => 'Upload receipt'])

@section('content')
<div class="card">
    <h1>Upload receipt</h1>
    <p class="muted">Step 1: upload your receipt file. Step 2: OCR suggestions are generated automatically. Step 3: fill in and confirm the receipt fields.</p>

    <form method="post" action="{{ route('web.receipts.store') }}" enctype="multipart/form-data">
        @csrf
        <div class="field">
            <label>Receipt file</label>
            <input name="receipt_file" type="file" accept=".pdf,.jpg,.jpeg,.png,.webp" required>
        </div>
        <button type="submit">Upload receipt</button>
    </form>
</div>
@endsection
