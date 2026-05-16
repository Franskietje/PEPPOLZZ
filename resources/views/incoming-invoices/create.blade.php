@extends('layouts.app', ['title' => 'Import incoming invoice'])

@section('content')
<div class="card">
    <h1>Import incoming UBL/XML invoice</h1>
    <p class="muted">Upload a supplier invoice XML file. This is the manual version of what Peppol receive will automate later.</p>

    <form method="post" action="{{ route('web.incoming-invoices.store') }}" enctype="multipart/form-data">
        @csrf
        <div class="field">
            <label>UBL/XML file</label>
            <input name="ubl_file" type="file" accept=".xml,.ubl,text/xml,application/xml" required>
        </div>
        <button type="submit">Import invoice</button>
    </form>
</div>
@endsection
