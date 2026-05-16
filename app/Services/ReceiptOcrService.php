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
        $binary = $this->resolveTesseractBinary();
        $languages = implode('+', $this->resolveLanguages($binary));

        $process = new Process([
            $binary,
            $absolutePath,
            'stdout',
            '-l',
            $languages,
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

    private function resolveTesseractBinary(): string
    {
        $configured = env('TESSERACT_BINARY');
        if (is_string($configured) && trim($configured) !== '') {
            return trim($configured);
        }

        if (PHP_OS_FAMILY === 'Windows') {
            $candidates = [
                'C:\\Program Files\\Tesseract-OCR\\tesseract.exe',
                'C:\\Program Files (x86)\\Tesseract-OCR\\tesseract.exe',
            ];

            foreach ($candidates as $candidate) {
                if (file_exists($candidate)) {
                    return $candidate;
                }
            }
        }

        return 'tesseract';
    }

    private function resolveLanguages(string $binary): array
    {
        $default = ['eng'];
        $preferred = ['eng', 'nld', 'fra'];

        $process = new Process([$binary, '--list-langs']);
        $process->setTimeout(10);
        $process->run();

        if (! $process->isSuccessful()) {
            return $default;
        }

        $lines = preg_split('/\r\n|\n|\r/', trim($process->getOutput())) ?: [];
        $installed = [];
        foreach ($lines as $line) {
            $line = trim($line);
            if ($line === '' || str_starts_with(strtolower($line), 'list of available languages')) {
                continue;
            }
            $installed[] = $line;
        }

        $usable = array_values(array_intersect($preferred, $installed));

        if ($usable !== []) {
            return $usable;
        }

        if ($installed !== []) {
            return [reset($installed)];
        }

        return $default;
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
