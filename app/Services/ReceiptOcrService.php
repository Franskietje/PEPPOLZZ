<?php

namespace App\Services;

use App\Models\Receipt;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Storage;
use RuntimeException;
use Symfony\Component\Process\Process;

class ReceiptOcrService
{
    public function process(Receipt $receipt): Receipt
    {
        // Get the file path - handle both S3 and local storage
        $disk = strtolower((string) env('FILESYSTEM_DISK', 'local'));
        
        if ($disk === 's3') {
            // For S3, download to temp location
            if (!Storage::disk('s3')->exists($receipt->original_file_path)) {
                throw new RuntimeException('Receipt file not found.');
            }
            $tempPath = tempnam(sys_get_temp_dir(), 'receipt_ocr_');
            file_put_contents($tempPath, Storage::disk('s3')->get($receipt->original_file_path));
            $absolutePath = $tempPath;
            $cleanup = static function () use ($tempPath): void {
                @unlink($tempPath);
            };
        } else {
            // For local storage
            $absolutePath = Storage::disk('local')->path($receipt->original_file_path);
            if (! file_exists($absolutePath)) {
                throw new RuntimeException('Receipt file not found.');
            }
            $cleanup = null;
        }

        try {
            $extension = strtolower(pathinfo($absolutePath, PATHINFO_EXTENSION));

            if (! in_array($extension, ['jpg', 'jpeg', 'png', 'tif', 'tiff', 'webp'], true)) {
                throw new RuntimeException('OCR currently supports image files only. Upload JPG or PNG for now.');
            }

            $driver = strtolower((string) env('OCR_DRIVER', 'tesseract'));

            if ($driver === 'disabled') {
                throw new RuntimeException('OCR is disabled in this environment.');
            }

            $text = match ($driver) {
                'ocr_space' => $this->runOcrSpace($absolutePath),
                'tesseract' => $this->runTesseract($absolutePath),
                default => throw new RuntimeException('Unsupported OCR_DRIVER. Use tesseract, ocr_space, or disabled.'),
            };

            $guesses = $this->extractGuesses($text);

            $receipt->update([
                'ocr_status' => 'processed',
                'ocr_text' => $text,
                'ocr_data' => $guesses,
                'ocr_processed_at' => now(),
            ]);

            return $receipt->refresh();
        } finally {
            // Clean up temp file if it was S3
            if (is_callable($cleanup)) {
                $cleanup();
            }
        }
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
            $output = trim($process->getErrorOutput().' '.$process->getOutput());
            $lower = strtolower($output);

            if ($process->getExitCode() === 127 || str_contains($lower, 'not found')) {
                throw new RuntimeException('Tesseract is not available on this server. Set OCR_DRIVER=ocr_space and OCR_SPACE_API_KEY in production, or install tesseract.');
            }

            throw new RuntimeException(trim($process->getErrorOutput()) ?: 'Tesseract OCR failed.');
        }

        return trim($process->getOutput());
    }

    private function runOcrSpace(string $absolutePath): string
    {
        $apiKey = (string) config('services.ocr_space.api_key');

        if ($apiKey === '') {
            throw new RuntimeException('OCR_SPACE_API_KEY is missing.');
        }

        $endpoint = (string) config('services.ocr_space.endpoint', 'https://api.ocr.space/parse/image');
        $language = (string) config('services.ocr_space.language', 'eng');
        $maxBytes = (int) env('OCR_SPACE_MAX_FILE_SIZE', 1000000);

        [$uploadPath, $cleanup] = $this->prepareFileForOcrSpace($absolutePath, $maxBytes);
        $fileType = $this->resolveOcrSpaceFileType($uploadPath);
        $uploadName = $this->resolveOcrUploadName($uploadPath, $absolutePath, $fileType);
        $handle = fopen($uploadPath, 'r');

        if ($handle === false) {
            if (is_callable($cleanup)) {
                $cleanup();
            }

            throw new RuntimeException('Unable to read file for OCR upload.');
        }

        try {
            $response = Http::timeout(60)
                ->attach('file', $handle, $uploadName)
                ->post($endpoint, [
                    'apikey' => $apiKey,
                    'language' => $language,
                    'filetype' => $fileType,
                    'isOverlayRequired' => 'false',
                    'OCREngine' => '2',
                ]);
        } finally {
            fclose($handle);
            if (is_callable($cleanup)) {
                $cleanup();
            }
        }

        if (! $response->successful()) {
            if ($response->status() === 413) {
                throw new RuntimeException('OCR provider rejected the image as too large. The free OCR.space tier allows files up to 1 MB. Upload a smaller image, or use a PRO OCR.space key.');
            }

            throw new RuntimeException('OCR provider request failed with status '.$response->status().'.');
        }

        $payload = $response->json();

        if (! is_array($payload)) {
            throw new RuntimeException('Invalid OCR provider response.');
        }

        if (($payload['IsErroredOnProcessing'] ?? false) === true) {
            $errors = $payload['ErrorMessage'] ?? 'OCR provider returned an error.';
            $message = is_array($errors) ? implode(' ', $errors) : (string) $errors;
            throw new RuntimeException($message);
        }

        $parsed = $payload['ParsedResults'][0]['ParsedText'] ?? null;

        if (! is_string($parsed) || trim($parsed) === '') {
            throw new RuntimeException('No OCR text detected in the image.');
        }

        return trim($parsed);
    }

    private function prepareFileForOcrSpace(string $absolutePath, int $maxBytes): array
    {
        $currentSize = @filesize($absolutePath);

        if ($currentSize !== false && $currentSize <= $maxBytes) {
            return [$absolutePath, null];
        }

        $mimeType = (string) @mime_content_type($absolutePath);
        if (! str_starts_with($mimeType, 'image/')) {
            throw new RuntimeException('This file is too large for OCR.space free API. For PDFs or large files, use a PRO OCR.space key or upload a smaller image.');
        }

        if (! function_exists('imagecreatefromstring') || ! function_exists('imagejpeg')) {
            throw new RuntimeException('Image is too large for OCR.space free API and image compression is unavailable on this server. Upload a smaller image or use a PRO OCR.space key.');
        }

        $raw = @file_get_contents($absolutePath);
        if ($raw === false) {
            throw new RuntimeException('Unable to read image for OCR preprocessing.');
        }

        $source = @imagecreatefromstring($raw);
        if ($source === false) {
            throw new RuntimeException('Unable to prepare image for OCR.');
        }

        $originalWidth = imagesx($source);
        $originalHeight = imagesy($source);
        $tempPath = tempnam(sys_get_temp_dir(), 'ocr_');

        if ($tempPath === false) {
            imagedestroy($source);
            throw new RuntimeException('Unable to allocate temporary OCR file.');
        }

        $quality = 85;
        $scale = 1.0;
        $compressed = false;

        for ($attempt = 0; $attempt < 8; $attempt++) {
            $targetWidth = max(1, (int) round($originalWidth * $scale));
            $targetHeight = max(1, (int) round($originalHeight * $scale));

            $canvas = imagecreatetruecolor($targetWidth, $targetHeight);
            if ($canvas === false) {
                continue;
            }

            imagecopyresampled($canvas, $source, 0, 0, 0, 0, $targetWidth, $targetHeight, $originalWidth, $originalHeight);
            imagejpeg($canvas, $tempPath, $quality);
            imagedestroy($canvas);

            $newSize = @filesize($tempPath);
            if ($newSize !== false && $newSize <= $maxBytes) {
                $compressed = true;
                break;
            }

            if ($quality > 45) {
                $quality -= 10;
            } else {
                $scale *= 0.8;
            }
        }

        imagedestroy($source);

        if (! $compressed) {
            @unlink($tempPath);
            throw new RuntimeException('Receipt image is too large for OCR.space free API (1 MB limit). Please upload a smaller image or use a PRO OCR.space key.');
        }

        return [
            $tempPath,
            static function () use ($tempPath): void {
                @unlink($tempPath);
            },
        ];
    }

    private function resolveOcrSpaceFileType(string $path): string
    {
        $extension = strtolower(pathinfo($path, PATHINFO_EXTENSION));

        return match ($extension) {
            'jpg', 'jpeg' => 'JPG',
            'png' => 'PNG',
            'pdf' => 'PDF',
            'tif', 'tiff' => 'TIF',
            'bmp' => 'BMP',
            'gif' => 'GIF',
            'webp' => 'JPG',
            default => 'JPG',
        };
    }

    private function resolveOcrUploadName(string $uploadPath, string $absolutePath, string $fileType): string
    {
        $originalBaseName = pathinfo($absolutePath, PATHINFO_FILENAME);

        if ($originalBaseName === '') {
            $originalBaseName = 'receipt';
        }

        $desiredExtension = strtolower($fileType === 'JPG' ? 'jpg' : $fileType);
        $currentExtension = strtolower(pathinfo($uploadPath, PATHINFO_EXTENSION));

        if ($currentExtension !== '') {
            return basename($uploadPath);
        }

        return $originalBaseName.'.'.$desiredExtension;
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
