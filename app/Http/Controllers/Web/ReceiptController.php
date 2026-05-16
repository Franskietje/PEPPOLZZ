<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\Contact;
use App\Models\Receipt;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\View\View;
use App\Services\ReceiptOcrService;
use Symfony\Component\HttpFoundation\StreamedResponse;

class ReceiptController extends Controller
{
    public function index(): View
    {
        return view('receipts.index', [
            'receipts' => Receipt::with('supplier')->latest('id')->get(),
        ]);
    }

    public function create(): View
    {
        return view('receipts.create', [
            'suppliers' => Contact::whereIn('type', ['supplier', 'both'])->orderBy('name')->get(),
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $data = $request->validate([
            'supplier_id' => ['nullable', 'exists:contacts,id'],
            'receipt_date' => ['nullable', 'date'],
            'category' => ['nullable', 'string', 'max:100'],
            'currency' => ['required', 'string', 'size:3'],
            'subtotal_ex_vat' => ['nullable', 'numeric', 'min:0'],
            'total_vat' => ['nullable', 'numeric', 'min:0'],
            'total_inc_vat' => ['required', 'numeric', 'min:0'],
            'notes' => ['nullable', 'string'],
            'receipt_file' => ['required', 'file', 'mimes:pdf,jpg,jpeg,png,webp', 'max:10240'],
        ]);

        $file = $request->file('receipt_file');
        $path = $file->store('receipts', 'local');

        $receipt = Receipt::create([
            'supplier_id' => $data['supplier_id'] ?? null,
            'receipt_date' => $data['receipt_date'] ?? null,
            'category' => $data['category'] ?? null,
            'currency' => strtoupper($data['currency']),
            'subtotal_ex_vat' => $data['subtotal_ex_vat'] ?? 0,
            'total_vat' => $data['total_vat'] ?? 0,
            'total_inc_vat' => $data['total_inc_vat'],
            'status' => 'needs_review',
            'original_file_path' => $path,
            'original_file_name' => $file->getClientOriginalName(),
            'mime_type' => $file->getMimeType(),
            'notes' => $data['notes'] ?? null,
        ]);

        return redirect()->route('web.receipts.show', $receipt)->with('success', 'Receipt uploaded.');
    }

    public function show(Receipt $receipt): View
    {
        return view('receipts.show', [
            'receipt' => $receipt->load('supplier'),
            'suppliers' => Contact::whereIn('type', ['supplier', 'both'])->orderBy('name')->get(),
        ]);
    }

    public function update(Request $request, Receipt $receipt): RedirectResponse
    {
        if ($receipt->status !== 'needs_review') {
            return back()->withErrors(['receipt' => 'Only receipts that need review can be edited.']);
        }

        $data = $request->validate([
            'supplier_id' => ['nullable', 'exists:contacts,id'],
            'receipt_date' => ['nullable', 'date'],
            'category' => ['nullable', 'string', 'max:100'],
            'currency' => ['required', 'string', 'size:3'],
            'subtotal_ex_vat' => ['required', 'numeric', 'min:0'],
            'total_vat' => ['required', 'numeric', 'min:0'],
            'total_inc_vat' => ['required', 'numeric', 'min:0'],
            'notes' => ['nullable', 'string'],
        ]);

        $data['currency'] = strtoupper($data['currency']);
        $receipt->update($data);

        return redirect()->route('web.receipts.show', $receipt)->with('success', 'Receipt saved.');
    }

    public function runOcr(Receipt $receipt, ReceiptOcrService $ocr): RedirectResponse
    {
        try {
            $ocr->process($receipt);
        } catch (\Throwable $e) {
            $receipt->update([
                'ocr_status' => 'failed',
                'ocr_data' => [
                    'error' => $e->getMessage(),
                ],
                'ocr_processed_at' => now(),
            ]);

            return redirect()
                ->route('web.receipts.show', $receipt)
                ->withErrors(['ocr' => $e->getMessage()]);
        }

        return redirect()->route('web.receipts.show', $receipt)->with('success', 'OCR processed. Review the extracted text and suggestions.');
    }
    public function applyOcrSuggestions(Receipt $receipt): RedirectResponse
    {
        if ($receipt->status !== 'needs_review') {
            return back()->withErrors(['receipt' => 'Only receipts that need review can be edited.']);
        }

        $data = $receipt->ocr_data ?? [];

        if (! $data) {
            return back()->withErrors(['ocr' => 'No OCR suggestions found. Run OCR first.']);
        }

        $updates = [];

        if (! empty($data['date'])) {
            $updates['receipt_date'] = $data['date'];
        }

        if (isset($data['total_inc_vat'])) {
            $updates['total_inc_vat'] = round((float) $data['total_inc_vat'], 2);
        }

        if (isset($data['total_vat'])) {
            $updates['total_vat'] = round((float) $data['total_vat'], 2);
        }

        if (isset($updates['total_inc_vat'], $updates['total_vat'])) {
            $updates['subtotal_ex_vat'] = max(0, round($updates['total_inc_vat'] - $updates['total_vat'], 2));
        }

        if (! $updates) {
            return back()->withErrors(['ocr' => 'OCR ran, but there were no usable suggestions to apply.']);
        }

        $receipt->update($updates);

        return redirect()->route('web.receipts.show', $receipt)->with('success', 'OCR suggestions applied. Please review before approving.');
    }
    public function approve(Receipt $receipt): RedirectResponse
    {
        $receipt->update(['status' => 'approved']);

        return redirect()->route('web.receipts.show', $receipt)->with('success', 'Receipt approved.');
    }

    public function reject(Receipt $receipt): RedirectResponse
    {
        $receipt->update(['status' => 'rejected']);

        return redirect()->route('web.receipts.show', $receipt)->with('success', 'Receipt rejected.');
    }

    public function viewFile(Receipt $receipt)
    {
        $path = Storage::disk('local')->path($receipt->original_file_path);

        if (! file_exists($path)) {
            abort(404);
        }

        return response()->file($path, [
            'Content-Type' => $receipt->mime_type ?: 'application/octet-stream',
        ]);
    }
    public function download(Receipt $receipt): StreamedResponse
    {
        return Storage::disk('local')->download(
            $receipt->original_file_path,
            $receipt->original_file_name ?: basename($receipt->original_file_path)
        );
    }
}
