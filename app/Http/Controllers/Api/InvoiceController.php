<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Company;
use App\Models\Invoice;
use App\Services\InvoiceCalculator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class InvoiceController extends Controller
{
    public function index(): JsonResponse
    {
        return response()->json(
            Invoice::with(['company', 'customer', 'lines'])
                ->latest('id')
                ->get()
        );
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'company_id' => ['required', 'exists:companies,id'],
            'customer_id' => ['required', 'exists:contacts,id'],
            'invoice_type' => ['nullable', 'in:invoice,credit_note'],
            'issue_date' => ['nullable', 'date'],
            'due_date' => ['nullable', 'date'],
            'currency' => ['nullable', 'string', 'size:3'],
            'payment_reference' => ['nullable', 'string', 'max:255'],
            'notes' => ['nullable', 'string'],
        ]);

        $invoice = DB::transaction(function () use ($data) {
            $company = Company::lockForUpdate()->findOrFail($data['company_id']);
            $issueDate = isset($data['issue_date'])
                ? Carbon::parse($data['issue_date'])
                : now();
            $dueDate = isset($data['due_date'])
                ? Carbon::parse($data['due_date'])
                : $issueDate->copy()->addDays(30);

            return Invoice::create([
                'company_id' => $company->id,
                'customer_id' => $data['customer_id'],
                'invoice_type' => $data['invoice_type'] ?? 'invoice',
                'invoice_number' => $company->reserveNextInvoiceNumber(),
                'issue_date' => $issueDate->toDateString(),
                'due_date' => $dueDate->toDateString(),
                'currency' => $data['currency'] ?? $company->default_currency,
                'status' => 'draft',
                'payment_reference' => $data['payment_reference'] ?? null,
                'notes' => $data['notes'] ?? null,
            ]);
        });

        return response()->json($invoice->load(['company', 'customer', 'lines']), 201);
    }

    public function show(Invoice $invoice): JsonResponse
    {
        return response()->json($invoice->load(['company', 'customer', 'lines.product']));
    }

    public function update(Request $request, Invoice $invoice): JsonResponse
    {
        $data = $request->validate([
            'customer_id' => ['sometimes', 'exists:contacts,id'],
            'issue_date' => ['sometimes', 'date'],
            'due_date' => ['sometimes', 'date'],
            'currency' => ['sometimes', 'string', 'size:3'],
            'status' => ['sometimes', 'in:draft,ready,validated,sent,paid,cancelled'],
            'payment_reference' => ['nullable', 'string', 'max:255'],
            'notes' => ['nullable', 'string'],
        ]);

        $invoice->update($data);

        return response()->json($invoice->refresh()->load(['company', 'customer', 'lines.product']));
    }

    public function destroy(Invoice $invoice): JsonResponse
    {
        if ($invoice->status !== 'draft') {
            return response()->json([
                'message' => 'Only draft invoices can be deleted.',
            ], 422);
        }

        $invoice->delete();

        return response()->json(['deleted' => true]);
    }

    public function recalculate(Invoice $invoice, InvoiceCalculator $calculator): JsonResponse
    {
        $invoice = $calculator->recalculate($invoice);

        return response()->json($invoice->load(['company', 'customer', 'lines.product']));
    }
}
