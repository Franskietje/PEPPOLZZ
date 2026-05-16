#!/usr/bin/env bash
set -euo pipefail

# Run this from the Laravel project root after the Tesseract OCR scaffold.
# It improves receipt review:
# - inline image/PDF preview route
# - Apply OCR suggestions button
# - fills date, VAT, total, and subtotal from OCR guesses when available

# Update ReceiptController with view file + apply OCR suggestions actions.
php <<'PHP'
<?php
$path = 'app/Http/Controllers/Web/ReceiptController.php';
$text = file_get_contents($path);

$viewMethod = <<<'METHOD'

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
METHOD;

$applyMethod = <<<'METHOD'

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
METHOD;

if (strpos($text, 'function viewFile') === false) {
    $marker = "\n    public function download(Receipt \$receipt): StreamedResponse\n";
    $text = str_replace($marker, $viewMethod . $marker, $text);
}

if (strpos($text, 'function applyOcrSuggestions') === false) {
    $marker = "\n    public function approve(Receipt \$receipt): RedirectResponse\n";
    $text = str_replace($marker, $applyMethod . $marker, $text);
}

file_put_contents($path, $text);
PHP

# Add routes. Must place /view and /apply-ocr before the generic /receipts/{receipt} show route.
php <<'PHP'
<?php
$path = 'routes/web.php';
$text = file_get_contents($path);

$viewRoute = "Route::get('/receipts/{receipt}/view', [ReceiptController::class, 'viewFile'])->name('web.receipts.view');\n";
$applyRoute = "Route::post('/receipts/{receipt}/apply-ocr', [ReceiptController::class, 'applyOcrSuggestions'])->name('web.receipts.apply-ocr');\n";

if (strpos($text, 'web.receipts.view') === false) {
    $marker = "Route::get('/receipts/{receipt}', [ReceiptController::class, 'show'])->name('web.receipts.show');\n";
    $text = str_replace($marker, $viewRoute . $marker, $text);
}

if (strpos($text, 'web.receipts.apply-ocr') === false) {
    $marker = "Route::post('/receipts/{receipt}/approve', [ReceiptController::class, 'approve'])->name('web.receipts.approve');\n";
    $text = str_replace($marker, $applyRoute . $marker, $text);
}

file_put_contents($path, $text);
PHP

# Update receipt show view with preview and Apply OCR button.
php <<'PHP'
<?php
$path = 'resources/views/receipts/show.blade.php';
$text = file_get_contents($path);

$applyButton = <<<'BLADE'

            @if ($receipt->ocr_status === 'processed')
                <form method="post" action="{{ route('web.receipts.apply-ocr', $receipt) }}">
                    @csrf
                    <button type="submit" class="secondary">Apply OCR suggestions</button>
                </form>
            @endif
BLADE;

if (strpos($text, 'web.receipts.apply-ocr') === false) {
    $marker = "            <form method=\"post\" action=\"{{ route('web.receipts.ocr', \$receipt) }}\">\n                @csrf\n                <button type=\"submit\" class=\"secondary\">Run OCR</button>\n            </form>\n";
    $text = str_replace($marker, $marker . $applyButton, $text);
}

$previewBlock = <<<'BLADE'

<div class="card">
    <h2>Preview</h2>
    @if (str_starts_with((string) $receipt->mime_type, 'image/'))
        <img src="{{ route('web.receipts.view', $receipt) }}" alt="Receipt preview" style="max-width:100%; border:1px solid #e5e7eb; border-radius:12px;">
    @elseif ($receipt->mime_type === 'application/pdf')
        <iframe src="{{ route('web.receipts.view', $receipt) }}" style="width:100%; height:700px; border:1px solid #e5e7eb; border-radius:12px;"></iframe>
    @else
        <p class="muted">No inline preview available for this file type.</p>
    @endif
</div>
BLADE;

if (strpos($text, '<h2>Preview</h2>') === false) {
    $marker = "<div class=\"card\">\n    <h2>Receipt details</h2>";
    $text = str_replace($marker, $previewBlock . "\n" . $marker, $text);
}

if (strpos($text, 'Click Apply OCR suggestions') === false) {
    $marker = "        <h3>Suggestions</h3>\n";
    $text = str_replace($marker, $marker . "        <p class=\"muted\">Click Apply OCR suggestions above to copy these into the review form, then verify them manually.</p>\n", $text);
}

file_put_contents($path, $text);
PHP

php artisan route:clear
php artisan view:clear
php artisan optimize:clear

echo "Milestone 7 receipt review helpers installed."
echo "Start/restart Laravel:"
echo "  php artisan serve"
echo ""
echo "Test:"
echo "  1. Open a receipt"
echo "  2. Check the preview"
echo "  3. Run OCR"
echo "  4. Click Apply OCR suggestions"
echo "  5. Review and approve"
