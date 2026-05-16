<?php

namespace App\Services;

use App\Models\Invoice;
use App\Models\InvoiceLine;
use Illuminate\Support\Facades\DB;

class InvoiceCalculator
{
    public function recalculate(Invoice $invoice): Invoice
    {
        return DB::transaction(function () use ($invoice) {
            $subtotal = 0.0;
            $vatTotal = 0.0;
            $grandTotal = 0.0;

            $invoice->load('lines');

            /** @var InvoiceLine $line */
            foreach ($invoice->lines as $line) {
                $lineTotalExVat = round((float) $line->quantity * (float) $line->unit_price_ex_vat, 2);
                $lineVat = round($lineTotalExVat * ((float) $line->vat_rate / 100), 2);
                $lineTotalIncVat = round($lineTotalExVat + $lineVat, 2);

                $line->update([
                    'line_total_ex_vat' => $lineTotalExVat,
                    'line_vat' => $lineVat,
                    'line_total_inc_vat' => $lineTotalIncVat,
                ]);

                $subtotal += $lineTotalExVat;
                $vatTotal += $lineVat;
                $grandTotal += $lineTotalIncVat;
            }

            $invoice->update([
                'subtotal_ex_vat' => round($subtotal, 2),
                'total_vat' => round($vatTotal, 2),
                'total_inc_vat' => round($grandTotal, 2),
            ]);

            return $invoice->refresh();
        });
    }
}
