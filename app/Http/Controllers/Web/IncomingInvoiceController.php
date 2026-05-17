<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\Contact;
use App\Models\IncomingInvoice;
use App\Services\UblIncomingInvoiceParser;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\DB;
use Illuminate\View\View;
use Symfony\Component\HttpFoundation\StreamedResponse;

class IncomingInvoiceController extends Controller
{
    public function index(): View
    {
        return view('incoming-invoices.index', [
            'incomingInvoices' => IncomingInvoice::with('supplier')->latest('id')->get(),
        ]);
    }

    public function create(): View
    {
        return view('incoming-invoices.create');
    }

    public function store(Request $request, UblIncomingInvoiceParser $parser): RedirectResponse
    {
        $data = $request->validate([
            'ubl_file' => [
                'required',
                'file',
                'max:10240',
                'mimetypes:text/xml,application/xml,application/octet-stream,text/plain',
            ],
        ]);

        $file = $request->file('ubl_file');
        $path = $file->store('incoming-invoices', 'local');
        $absolutePath = Storage::disk('local')->path($path);

        try {
            $parsed = $parser->parseFile($absolutePath);
        } catch (\Throwable $e) {
            Storage::disk('local')->delete($path);
            return back()->withErrors(['ubl_file' => $e->getMessage()]);
        }

        $incomingInvoice = DB::transaction(function () use ($parsed, $path, $file) {
            $supplier = $this->findOrCreateSupplier($parsed['supplier_name'] ?? null, $parsed['supplier_vat_number'] ?? null);

            $incomingInvoice = IncomingInvoice::create([
                'supplier_id' => $supplier?->id,
                'supplier_name' => $parsed['supplier_name'] ?? null,
                'supplier_vat_number' => $parsed['supplier_vat_number'] ?? null,
                'invoice_number' => $parsed['invoice_number'] ?? null,
                'issue_date' => $parsed['issue_date'] ?? null,
                'due_date' => $parsed['due_date'] ?? null,
                'currency' => $parsed['currency'] ?? 'EUR',
                'subtotal_ex_vat' => $parsed['subtotal_ex_vat'] ?? 0,
                'total_vat' => $parsed['total_vat'] ?? 0,
                'total_inc_vat' => $parsed['total_inc_vat'] ?? 0,
                'status' => 'needs_review',
                'original_file_path' => $path,
                'original_file_name' => $file->getClientOriginalName(),
                'parsed_data' => $parsed,
            ]);

            foreach ($parsed['lines'] ?? [] as $line) {
                $incomingInvoice->lines()->create($line);
            }

            return $incomingInvoice;
        });

        return redirect()->route('web.incoming-invoices.show', $incomingInvoice)->with('success', 'Incoming UBL invoice imported. Review before approving.');
    }

    public function show(IncomingInvoice $incomingInvoice): View
    {
        return view('incoming-invoices.show', [
            'incomingInvoice' => $incomingInvoice->load(['supplier', 'lines']),
            'suppliers' => Contact::whereIn('type', ['supplier', 'both'])->orderBy('name')->get(),
        ]);
    }

    public function update(Request $request, IncomingInvoice $incomingInvoice): RedirectResponse
    {
        if ($incomingInvoice->status !== 'needs_review') {
            return back()->withErrors(['incoming_invoice' => 'Only invoices that need review can be edited.']);
        }

        $data = $request->validate([
            'supplier_id' => ['nullable', 'exists:contacts,id'],
            'supplier_name' => ['nullable', 'string', 'max:255'],
            'supplier_vat_number' => ['nullable', 'string', 'max:50'],
            'invoice_number' => ['nullable', 'string', 'max:100'],
            'issue_date' => ['nullable', 'date'],
            'due_date' => ['nullable', 'date'],
            'currency' => ['required', 'string', 'size:3'],
            'subtotal_ex_vat' => ['required', 'numeric', 'min:0'],
            'total_vat' => ['required', 'numeric', 'min:0'],
            'total_inc_vat' => ['required', 'numeric', 'min:0'],
            'notes' => ['nullable', 'string'],
        ]);

        $data['currency'] = strtoupper($data['currency']);
        $incomingInvoice->update($data);

        return redirect()->route('web.incoming-invoices.show', $incomingInvoice)->with('success', 'Incoming invoice saved.');
    }

    public function approve(IncomingInvoice $incomingInvoice): RedirectResponse
    {
        $incomingInvoice->update(['status' => 'approved']);

        return redirect()->route('web.incoming-invoices.show', $incomingInvoice)->with('success', 'Incoming invoice approved.');
    }

    public function reject(IncomingInvoice $incomingInvoice): RedirectResponse
    {
        $incomingInvoice->update(['status' => 'rejected']);

        return redirect()->route('web.incoming-invoices.show', $incomingInvoice)->with('success', 'Incoming invoice rejected.');
    }

    public function destroy(IncomingInvoice $incomingInvoice): RedirectResponse
    {
        if ($incomingInvoice->original_file_path) {
            Storage::disk('local')->delete($incomingInvoice->original_file_path);
        }

        $incomingInvoice->delete();

        return redirect()->route('web.incoming-invoices.index')->with('success', 'Incoming invoice deleted.');
    }

    public function download(IncomingInvoice $incomingInvoice): StreamedResponse
    {
        return Storage::disk('local')->download(
            $incomingInvoice->original_file_path,
            $incomingInvoice->original_file_name ?: basename($incomingInvoice->original_file_path)
        );
    }

    private function findOrCreateSupplier(?string $name, ?string $vatNumber): ?Contact
    {
        if (! $name && ! $vatNumber) {
            return null;
        }

        if ($vatNumber) {
            $existing = Contact::where('vat_number', $vatNumber)->first();
            if ($existing) {
                return $existing;
            }
        }

        if ($name) {
            $existing = Contact::where('name', $name)->first();
            if ($existing) {
                return $existing;
            }
        }

        return Contact::create([
            'type' => 'supplier',
            'name' => $name ?: 'Unknown supplier',
            'vat_number' => $vatNumber,
            'country_code' => 'BE',
            'default_currency' => 'EUR',
            'payment_terms_days' => 30,
        ]);
    }
}
