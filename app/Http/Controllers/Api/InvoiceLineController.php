<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Invoice;
use App\Models\InvoiceLine;
use App\Models\Product;
use App\Services\InvoiceCalculator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class InvoiceLineController extends Controller
{
    public function store(Request $request, Invoice $invoice, InvoiceCalculator $calculator): JsonResponse
    {
        if ($invoice->status !== 'draft') {
            return response()->json([
                'message' => 'Lines can only be added to draft invoices.',
            ], 422);
        }

        $data = $request->validate([
            'product_id' => ['nullable', 'exists:products,id'],
            'description' => ['nullable', 'string'],
            'quantity' => ['required', 'numeric', 'min:0.001'],
            'unit_code' => ['nullable', 'string', 'max:20'],
            'unit_price_ex_vat' => ['nullable', 'numeric', 'min:0'],
            'vat_rate' => ['nullable', 'numeric', 'min:0', 'max:100'],
        ]);

        $product = isset($data['product_id']) ? Product::find($data['product_id']) : null;

        $line = $invoice->lines()->create([
            'product_id' => $product?->id,
            'description' => $data['description'] ?? $product?->description ?? $product?->name ?? 'Invoice line',
            'quantity' => $data['quantity'],
            'unit_code' => $data['unit_code'] ?? $product?->unit_code ?? 'C62',
            'unit_price_ex_vat' => $data['unit_price_ex_vat'] ?? $product?->unit_price_ex_vat ?? 0,
            'vat_rate' => $data['vat_rate'] ?? $product?->vat_rate ?? 21,
        ]);

        $calculator->recalculate($invoice);

        return response()->json($line->refresh(), 201);
    }

    public function update(Request $request, Invoice $invoice, InvoiceLine $line, InvoiceCalculator $calculator): JsonResponse
    {
        if ($line->invoice_id !== $invoice->id) {
            abort(404);
        }

        if ($invoice->status !== 'draft') {
            return response()->json([
                'message' => 'Lines can only be changed on draft invoices.',
            ], 422);
        }

        $data = $request->validate([
            'description' => ['sometimes', 'required', 'string'],
            'quantity' => ['sometimes', 'required', 'numeric', 'min:0.001'],
            'unit_code' => ['sometimes', 'required', 'string', 'max:20'],
            'unit_price_ex_vat' => ['sometimes', 'required', 'numeric', 'min:0'],
            'vat_rate' => ['sometimes', 'required', 'numeric', 'min:0', 'max:100'],
        ]);

        $line->update($data);
        $calculator->recalculate($invoice);

        return response()->json($line->refresh());
    }

    public function destroy(Invoice $invoice, InvoiceLine $line, InvoiceCalculator $calculator): JsonResponse
    {
        if ($line->invoice_id !== $invoice->id) {
            abort(404);
        }

        if ($invoice->status !== 'draft') {
            return response()->json([
                'message' => 'Lines can only be deleted from draft invoices.',
            ], 422);
        }

        $line->delete();
        $calculator->recalculate($invoice);

        return response()->json(['deleted' => true]);
    }
}
