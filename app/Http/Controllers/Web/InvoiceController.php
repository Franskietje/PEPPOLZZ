<?php

namespace App\Http\Controllers\Web;

use Barryvdh\DomPDF\Facade\Pdf;
use App\Http\Controllers\Controller;
use App\Models\Company;
use App\Models\Contact;
use App\Models\Invoice;
use App\Models\InvoiceLine;
use App\Models\Product;
use App\Services\InvoiceCalculator;
use App\Services\UblInvoiceGenerator;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\View\View;

class InvoiceController extends Controller
{
    public function index(): View
    {
        return view('invoices.index', [
            'invoices' => Invoice::with('customer')->latest('id')->get(),
        ]);
    }

    public function create(): View
    {
        return view('invoices.create', [
            'companies' => Company::orderBy('legal_name')->get(),
            'customers' => Contact::whereIn('type', ['customer', 'both'])->orderBy('name')->get(),
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $data = $request->validate([
            'company_id' => ['required', 'exists:companies,id'],
            'customer_id' => ['required', 'exists:contacts,id'],
            'issue_date' => ['required', 'date'],
            'due_date' => ['required', 'date', 'after_or_equal:issue_date'],
            'notes' => ['nullable', 'string'],
        ]);

        $invoice = DB::transaction(function () use ($data) {
            $company = Company::lockForUpdate()->findOrFail($data['company_id']);

            return Invoice::create([
                'company_id' => $company->id,
                'customer_id' => $data['customer_id'],
                'invoice_type' => 'invoice',
                'invoice_number' => $company->reserveNextInvoiceNumber(),
                'issue_date' => Carbon::parse($data['issue_date'])->toDateString(),
                'due_date' => Carbon::parse($data['due_date'])->toDateString(),
                'currency' => $company->default_currency,
                'status' => 'draft',
                'notes' => $data['notes'] ?? null,
            ]);
        });

        return redirect()->route('web.invoices.show', $invoice)->with('success', 'Invoice created. Add lines below.');
    }

    public function show(Invoice $invoice): View
    {
        return view('invoices.show', [
            'invoice' => $invoice->load(['company', 'customer', 'lines.product']),
            'products' => Product::orderBy('name')->get(),
        ]);
    }

    public function addLine(Request $request, Invoice $invoice, InvoiceCalculator $calculator): RedirectResponse
    {
        if ($invoice->status !== 'draft') {
            return back()->withErrors(['invoice' => 'Only draft invoices can be edited.']);
        }

        $data = $request->validate([
            'product_id' => ['nullable', 'exists:products,id'],
            'description' => ['nullable', 'string'],
            'quantity' => ['required', 'numeric', 'min:0.001'],
            'unit_price_ex_vat' => ['nullable', 'numeric', 'min:0'],
            'vat_rate' => ['nullable', 'numeric', 'min:0', 'max:100'],
        ]);

        $product = isset($data['product_id']) ? Product::find($data['product_id']) : null;

        $invoice->lines()->create([
            'product_id' => $product?->id,
            'description' => $data['description'] ?: ($product?->description ?: $product?->name ?: 'Invoice line'),
            'quantity' => $data['quantity'],
            'unit_code' => $product?->unit_code ?? 'C62',
            'unit_price_ex_vat' => $data['unit_price_ex_vat'] ?? $product?->unit_price_ex_vat ?? 0,
            'vat_rate' => $data['vat_rate'] ?? $product?->vat_rate ?? 21,
        ]);

        $calculator->recalculate($invoice);

        return redirect()->route('web.invoices.show', $invoice)->with('success', 'Line added.');
    }

    public function deleteLine(Invoice $invoice, InvoiceLine $line, InvoiceCalculator $calculator): RedirectResponse
    {
        if ($line->invoice_id !== $invoice->id) {
            abort(404);
        }

        if ($invoice->status !== 'draft') {
            return back()->withErrors(['invoice' => 'Only draft invoices can be edited.']);
        }

        $line->delete();
        $calculator->recalculate($invoice);

        return redirect()->route('web.invoices.show', $invoice)->with('success', 'Line deleted.');
    }

    public function downloadUbl(Invoice $invoice, UblInvoiceGenerator $generator)
    {
        $xml = $generator->generate($invoice);

        return response($xml, 200, [
            'Content-Type' => 'application/xml; charset=UTF-8',
            'Content-Disposition' => 'attachment; filename="' . $invoice->invoice_number . '.xml"',
        ]);
    }
    public function downloadPdf(Invoice $invoice)
    {
        $invoice->load(['company', 'customer', 'lines.product']);

        $pdf = Pdf::loadView('pdf.invoice', [
            'invoice' => $invoice,
        ])->setPaper('a4');

        return $pdf->download($invoice->invoice_number . '.pdf');
    }
    public function markPaid(Invoice $invoice): RedirectResponse
    {
        $invoice->update(['status' => 'paid']);

        return redirect()->route('web.invoices.show', $invoice)->with('success', 'Invoice marked as paid.');
    }

    public function destroy(Invoice $invoice): RedirectResponse
    {
        foreach ([$invoice->xml_storage_path, $invoice->pdf_storage_path] as $path) {
            if ($path) {
                Storage::disk('local')->delete($path);
            }
        }

        $invoice->delete();

        return redirect()->route('web.invoices.index')->with('success', 'Invoice deleted.');
    }
}
