<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\IncomingInvoice;
use App\Models\Invoice;
use App\Models\Receipt;
use App\Services\UblInvoiceGenerator;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\BinaryFileResponse;
use ZipArchive;

class PeriodExportController extends Controller
{
    public function __invoke(Request $request, UblInvoiceGenerator $ublGenerator): BinaryFileResponse|RedirectResponse
    {
        $data = $request->validate([
            'start_date' => ['required', 'date'],
            'end_date' => ['required', 'date', 'after_or_equal:start_date'],
        ]);

        if (! class_exists(ZipArchive::class)) {
            return back()->withErrors(['export' => 'ZIP export is not available because the PHP zip extension is missing.']);
        }

        $startDate = Carbon::parse($data['start_date'])->startOfDay();
        $endDate = Carbon::parse($data['end_date'])->endOfDay();

        $salesInvoices = Invoice::with(['customer', 'company', 'lines.product'])
            ->whereBetween('issue_date', [$startDate->toDateString(), $endDate->toDateString()])
            ->orderBy('issue_date')
            ->orderBy('id')
            ->get();

        $incomingInvoices = IncomingInvoice::with('supplier')
            ->where(function ($query) use ($startDate, $endDate): void {
                $query->whereBetween('issue_date', [$startDate->toDateString(), $endDate->toDateString()])
                    ->orWhere(function ($query) use ($startDate, $endDate): void {
                        $query->whereNull('issue_date')
                            ->whereBetween('created_at', [$startDate, $endDate]);
                    });
            })
            ->orderBy('issue_date')
            ->orderBy('id')
            ->get();

        $receipts = Receipt::with('supplier')
            ->where(function ($query) use ($startDate, $endDate): void {
                $query->whereBetween('receipt_date', [$startDate->toDateString(), $endDate->toDateString()])
                    ->orWhere(function ($query) use ($startDate, $endDate): void {
                        $query->whereNull('receipt_date')
                            ->whereBetween('created_at', [$startDate, $endDate]);
                    });
            })
            ->orderBy('receipt_date')
            ->orderBy('id')
            ->get();

        $zipPath = tempnam(sys_get_temp_dir(), 'period_export_');

        if ($zipPath === false) {
            return back()->withErrors(['export' => 'Could not create a temporary export file.']);
        }

        $zip = new ZipArchive();

        if ($zip->open($zipPath, ZipArchive::OVERWRITE) !== true) {
            @unlink($zipPath);

            return back()->withErrors(['export' => 'Could not open ZIP archive for writing.']);
        }

        foreach ($salesInvoices as $invoice) {
            $baseName = $this->safeFileName($invoice->invoice_number ?: 'invoice-'.$invoice->id);

            $pdf = Pdf::loadView('pdf.invoice', [
                'invoice' => $invoice,
            ])->setPaper('a4');

            $zip->addFromString('sales/pdfs/'.$baseName.'.pdf', $pdf->output());
            $zip->addFromString('sales/ubl/'.$baseName.'.xml', $ublGenerator->generate($invoice));
        }

        foreach ($incomingInvoices as $incomingInvoice) {
            if (! $incomingInvoice->original_file_path || ! Storage::disk('local')->exists($incomingInvoice->original_file_path)) {
                continue;
            }

            $sourceName = $incomingInvoice->original_file_name ?: basename($incomingInvoice->original_file_path);
            $baseName = pathinfo($sourceName, PATHINFO_FILENAME);
            $baseName = $this->safeFileName($baseName !== '' ? $baseName : 'incoming-invoice-'.$incomingInvoice->id);

            $zip->addFromString(
                'expenses/incoming-invoices/'.$baseName.'.xml',
                Storage::disk('local')->get($incomingInvoice->original_file_path)
            );
        }

        foreach ($receipts as $receipt) {
            if (! $receipt->original_file_path || ! Storage::disk('s3')->exists($receipt->original_file_path)) {
                continue;
            }

            $sourceName = $receipt->original_file_name ?: basename($receipt->original_file_path);
            $extension = strtolower(pathinfo($sourceName, PATHINFO_EXTENSION));
            $baseName = pathinfo($sourceName, PATHINFO_FILENAME);
            $baseName = $this->safeFileName($baseName !== '' ? $baseName : 'receipt-'.$receipt->id);
            $extension = $extension !== '' ? $extension : 'bin';

            $zip->addFromString(
                'expenses/receipts/'.$baseName.'.'.$extension,
                Storage::disk('s3')->get($receipt->original_file_path)
            );
        }

        $zip->addFromString('summaries/sales_summary.csv', $this->buildSalesCsv($salesInvoices));
        $zip->addFromString('summaries/expenses_summary.csv', $this->buildExpensesCsv($incomingInvoices, $receipts));

        $zip->close();

        $downloadName = sprintf(
            'period-export-%s-to-%s.zip',
            Carbon::parse($data['start_date'])->format('Ymd'),
            Carbon::parse($data['end_date'])->format('Ymd')
        );

        return response()->download($zipPath, $downloadName)->deleteFileAfterSend(true);
    }

    private function buildSalesCsv($salesInvoices): string
    {
        $rows = [
            ['invoice_number', 'issue_date', 'due_date', 'customer', 'status', 'currency', 'subtotal_ex_vat', 'total_vat', 'total_inc_vat'],
        ];

        foreach ($salesInvoices as $invoice) {
            $rows[] = [
                $invoice->invoice_number,
                optional($invoice->issue_date)->format('Y-m-d'),
                optional($invoice->due_date)->format('Y-m-d'),
                $invoice->customer?->name,
                $invoice->status,
                $invoice->currency,
                number_format((float) $invoice->subtotal_ex_vat, 2, '.', ''),
                number_format((float) $invoice->total_vat, 2, '.', ''),
                number_format((float) $invoice->total_inc_vat, 2, '.', ''),
            ];
        }

        return $this->rowsToCsv($rows);
    }

    private function buildExpensesCsv($incomingInvoices, $receipts): string
    {
        $rows = [
            ['type', 'id', 'date', 'supplier', 'invoice_or_receipt_number', 'status', 'currency', 'subtotal_ex_vat', 'total_vat', 'total_inc_vat', 'source_file'],
        ];

        foreach ($incomingInvoices as $incomingInvoice) {
            $rows[] = [
                'incoming_invoice',
                (string) $incomingInvoice->id,
                optional($incomingInvoice->issue_date)->format('Y-m-d') ?: optional($incomingInvoice->created_at)->format('Y-m-d'),
                $incomingInvoice->supplier?->name ?: $incomingInvoice->supplier_name,
                $incomingInvoice->invoice_number,
                $incomingInvoice->status,
                $incomingInvoice->currency,
                number_format((float) $incomingInvoice->subtotal_ex_vat, 2, '.', ''),
                number_format((float) $incomingInvoice->total_vat, 2, '.', ''),
                number_format((float) $incomingInvoice->total_inc_vat, 2, '.', ''),
                $incomingInvoice->original_file_name,
            ];
        }

        foreach ($receipts as $receipt) {
            $rows[] = [
                'receipt',
                (string) $receipt->id,
                optional($receipt->receipt_date)->format('Y-m-d') ?: optional($receipt->created_at)->format('Y-m-d'),
                $receipt->supplier?->name,
                $receipt->original_file_name,
                $receipt->status,
                $receipt->currency,
                number_format((float) $receipt->subtotal_ex_vat, 2, '.', ''),
                number_format((float) $receipt->total_vat, 2, '.', ''),
                number_format((float) $receipt->total_inc_vat, 2, '.', ''),
                $receipt->original_file_name,
            ];
        }

        return $this->rowsToCsv($rows);
    }

    private function rowsToCsv(array $rows): string
    {
        $stream = fopen('php://temp', 'w+');

        foreach ($rows as $row) {
            fputcsv($stream, $row);
        }

        rewind($stream);
        $contents = (string) stream_get_contents($stream);
        fclose($stream);

        return $contents;
    }

    private function safeFileName(string $name): string
    {
        $name = trim($name);
        $name = preg_replace('/[^A-Za-z0-9._-]/', '_', $name) ?: 'file';

        return Str::limit($name, 120, '');
    }
}
