#!/usr/bin/env bash
set -euo pipefail

# Run this from the Laravel project root after the Receipts scaffold.
# It adds a first free OCR layer using the Tesseract command-line tool.
#
# Important:
# - This scaffold expects Tesseract to be installed on your computer/server.
# - Image receipts work best: jpg, jpeg, png.
# - PDF OCR is not handled yet in this milestone.
#
# Install Tesseract separately:
#   macOS:   brew install tesseract
#   Ubuntu:  sudo apt install tesseract-ocr tesseract-ocr-eng tesseract-ocr-nld tesseract-ocr-fra
#   Windows: install Tesseract, then make sure tesseract.exe is in PATH

mkdir -p app/Services database/migrations

cat > database/migrations/2026_05_13_000007_add_ocr_fields_to_receipts_table.php <<'PHP'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('receipts', function (Blueprint $table) {
            $table->string('ocr_status')->default('not_processed')->after('status'); // not_processed, processed, failed
            $table->longText('ocr_text')->nullable()->after('ocr_status');
            $table->json('ocr_data')->nullable()->after('ocr_text');
            $table->timestamp('ocr_processed_at')->nullable()->after('ocr_data');
        });
    }

    public function down(): void
    {
        Schema::table('receipts', function (Blueprint $table) {
            $table->dropColumn(['ocr_status', 'ocr_text', 'ocr_data', 'ocr_processed_at']);
        });
    }
};
PHP

# Update Receipt model casts.
php <<'PHP'
<?php
$path = 'app/Models/Receipt.php';
$text = file_get_contents($path);
$old = <<<'OLD'
    protected $casts = [
        'receipt_date' => 'date',
    ];
OLD;

$new = <<<'NEW'
    protected $casts = [
        'receipt_date' => 'date',
        'ocr_data' => 'array',
        'ocr_processed_at' => 'datetime',
    ];
NEW;

if (strpos($text, "'ocr_data' => 'array'") === false && strpos($text, $old) !== false) {
    $text = str_replace($old, $new, $text);
}

file_put_contents($path, $text);
PHP

cat > app/Services/ReceiptOcrService.php <<'PHP'
<?php

namespace App\Services;

use App\Models\Receipt;
use Illuminate\Support\Facades\Storage;
use RuntimeException;
use Symfony\Component\Process\Process;

class ReceiptOcrService
{
    public function process(Receipt $receipt): Receipt
    {
        $absolutePath = Storage::disk('local')->path($receipt->original_file_path);

        if (! file_exists($absolutePath)) {
            throw new RuntimeException('Receipt file not found.');
        }

        $extension = strtolower(pathinfo($absolutePath, PATHINFO_EXTENSION));

        if (! in_array($extension, ['jpg', 'jpeg', 'png', 'tif', 'tiff', 'webp'], true)) {
            throw new RuntimeException('OCR currently supports image files only. Upload JPG or PNG for now.');
        }

        $text = $this->runTesseract($absolutePath);
        $guesses = $this->extractGuesses($text);

        $receipt->update([
            'ocr_status' => 'processed',
            'ocr_text' => $text,
            'ocr_data' => $guesses,
            'ocr_processed_at' => now(),
        ]);

        return $receipt->refresh();
    }

    private function runTesseract(string $absolutePath): string
    {
        $process = new Process([
            'tesseract',
            $absolutePath,
            'stdout',
            '-l',
            'eng+nld+fra',
            '--psm',
            '6',
        ]);

        $process->setTimeout(60);
        $process->run();

        if (! $process->isSuccessful()) {
            throw new RuntimeException(trim($process->getErrorOutput()) ?: 'Tesseract OCR failed.');
        }

        return trim($process->getOutput());
    }

    private function extractGuesses(string $text): array
    {
        $normalized = $this->normalizeText($text);

        return [
            'date' => $this->guessDate($normalized),
            'total_inc_vat' => $this->guessTotal($normalized),
            'total_vat' => $this->guessVat($normalized),
            'raw_amounts' => $this->extractAmounts($normalized),
        ];
    }

    private function normalizeText(string $text): string
    {
        $text = str_replace(["\r\n", "\r"], "\n", $text);
        $text = preg_replace('/[ \t]+/', ' ', $text);

        return trim($text);
    }

    private function guessDate(string $text): ?string
    {
        $patterns = [
            '/\b(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{4})\b/',
            '/\b(\d{4})[\/\-.](\d{1,2})[\/\-.](\d{1,2})\b/',
        ];

        if (preg_match($patterns[0], $text, $m)) {
            $day = str_pad($m[1], 2, '0', STR_PAD_LEFT);
            $month = str_pad($m[2], 2, '0', STR_PAD_LEFT);
            $year = $m[3];

            if (checkdate((int) $month, (int) $day, (int) $year)) {
                return "$year-$month-$day";
            }
        }

        if (preg_match($patterns[1], $text, $m)) {
            $year = $m[1];
            $month = str_pad($m[2], 2, '0', STR_PAD_LEFT);
            $day = str_pad($m[3], 2, '0', STR_PAD_LEFT);

            if (checkdate((int) $month, (int) $day, (int) $year)) {
                return "$year-$month-$day";
            }
        }

        return null;
    }

    private function guessTotal(string $text): ?float
    {
        $lines = preg_split('/\n+/', $text) ?: [];
        $keywords = ['total', 'totaal', 'totale', 'amount due', 'te betalen', 'bancontact'];

        $best = null;
        foreach ($lines as $line) {
            $lower = strtolower($line);
            foreach ($keywords as $keyword) {
                if (str_contains($lower, $keyword)) {
                    $amounts = $this->extractAmounts($line);
                    if ($amounts) {
                        $best = max($amounts);
                    }
                }
            }
        }

        if ($best !== null) {
            return $best;
        }

        $allAmounts = $this->extractAmounts($text);

        return $allAmounts ? max($allAmounts) : null;
    }

    private function guessVat(string $text): ?float
    {
        $lines = preg_split('/\n+/', $text) ?: [];
        $keywords = ['vat', 'btw', 'tva', 'tax'];

        foreach ($lines as $line) {
            $lower = strtolower($line);
            foreach ($keywords as $keyword) {
                if (str_contains($lower, $keyword)) {
                    $amounts = $this->extractAmounts($line);
                    if ($amounts) {
                        return max($amounts);
                    }
                }
            }
        }

        return null;
    }

    private function extractAmounts(string $text): array
    {
        preg_match_all('/(?<!\d)(\d{1,5}(?:[.,]\d{2}))(?!\d)/', $text, $matches);

        $amounts = [];
        foreach ($matches[1] ?? [] as $raw) {
            $amounts[] = (float) str_replace(',', '.', $raw);
        }

        $amounts = array_values(array_unique($amounts));
        sort($amounts);

        return $amounts;
    }
}
PHP

# Update ReceiptController with OCR action.
php <<'PHP'
<?php
$path = 'app/Http/Controllers/Web/ReceiptController.php';
$text = file_get_contents($path);

if (strpos($text, 'use App\\Services\\ReceiptOcrService;') === false) {
    $text = str_replace(
        "use Illuminate\\View\\View;\n",
        "use Illuminate\\View\\View;\nuse App\\Services\\ReceiptOcrService;\n",
        $text
    );
}

$method = <<<'METHOD'

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
METHOD;

if (strpos($text, 'function runOcr') === false) {
    $marker = "\n    public function approve(Receipt \$receipt): RedirectResponse\n";
    $text = str_replace($marker, $method . $marker, $text);
}

file_put_contents($path, $text);
PHP

# Add route.
php <<'PHP'
<?php
$path = 'routes/web.php';
$text = file_get_contents($path);
$route = "Route::post('/receipts/{receipt}/ocr', [ReceiptController::class, 'runOcr'])->name('web.receipts.ocr');\n";

if (strpos($text, 'web.receipts.ocr') === false) {
    $marker = "Route::post('/receipts/{receipt}/approve', [ReceiptController::class, 'approve'])->name('web.receipts.approve');\n";
    $text = str_replace($marker, $route . $marker, $text);
}

file_put_contents($path, $text);
PHP

# Update receipt show view with OCR button and extracted text/suggestions.
php <<'PHP'
<?php
$path = 'resources/views/receipts/show.blade.php';
$text = file_get_contents($path);

$ocrButton = <<<'BLADE'

            <form method="post" action="{{ route('web.receipts.ocr', $receipt) }}">
                @csrf
                <button type="submit" class="secondary">Run OCR</button>
            </form>
BLADE;

if (strpos($text, 'web.receipts.ocr') === false) {
    $marker = "        <a class=\"button secondary\" href=\"{{ route('web.receipts.download', \$receipt) }}\">Download original</a>\n";
    $text = str_replace($marker, $marker . $ocrButton, $text);
}

$ocrPanel = <<<'BLADE'


@if ($receipt->ocr_status !== 'not_processed')
<div class="card">
    <h2>OCR result</h2>
    <p class="muted">
        Status: {{ $receipt->ocr_status }}
        @if ($receipt->ocr_processed_at)
            · Processed: {{ $receipt->ocr_processed_at->format('Y-m-d H:i') }}
        @endif
    </p>

    @if ($receipt->ocr_data)
        <h3>Suggestions</h3>
        <table>
            <tr><th>Date</th><td>{{ $receipt->ocr_data['date'] ?? 'No guess' }}</td></tr>
            <tr><th>Total inc VAT</th><td>{{ isset($receipt->ocr_data['total_inc_vat']) ? '€ ' . number_format((float) $receipt->ocr_data['total_inc_vat'], 2, ',', '.') : 'No guess' }}</td></tr>
            <tr><th>Total VAT</th><td>{{ isset($receipt->ocr_data['total_vat']) ? '€ ' . number_format((float) $receipt->ocr_data['total_vat'], 2, ',', '.') : 'No guess' }}</td></tr>
            @if (!empty($receipt->ocr_data['error']))
                <tr><th>Error</th><td>{{ $receipt->ocr_data['error'] }}</td></tr>
            @endif
        </table>
    @endif

    @if ($receipt->ocr_text)
        <h3>Raw OCR text</h3>
        <textarea rows="14" readonly>{{ $receipt->ocr_text }}</textarea>
    @endif
</div>
@endif
BLADE;

if (strpos($text, 'OCR result') === false) {
    $text .= $ocrPanel;
}

file_put_contents($path, $text);
PHP

# Add helper text to receipt create view.
php <<'PHP'
<?php
$path = 'resources/views/receipts/create.blade.php';
$text = file_get_contents($path);
$old = 'Upload a PDF/image and enter the main values manually for now. OCR will be added later.';
$new = 'Upload an image receipt such as JPG or PNG for OCR. PDF upload is stored, but OCR for PDFs will come later.';
$text = str_replace($old, $new, $text);
file_put_contents($path, $text);
PHP

php artisan migrate
php artisan route:clear
php artisan view:clear
php artisan optimize:clear

echo "Milestone 6 Tesseract OCR scaffold installed."
echo ""
echo "Before testing, make sure Tesseract is installed and available in your terminal:"
echo "  tesseract --version"
echo ""
echo "Start/restart Laravel:"
echo "  php artisan serve"
echo ""
echo "Test:"
echo "  1. Upload a JPG or PNG receipt"
echo "  2. Open the receipt"
echo "  3. Click Run OCR"
echo "  4. Review raw text and suggestions"
