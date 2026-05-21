<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Company extends Model
{
    use HasFactory;

    protected $guarded = [];

    public function invoices(): HasMany
    {
        return $this->hasMany(Invoice::class);
    }

    public function reserveNextInvoiceNumber(): string
    {
        $prefix = strtoupper(trim((string) $this->invoice_number_prefix));
        $nextNumber = $this->nextAvailableInvoiceNumber($prefix);

        $number = sprintf('%s-%04d', $prefix, $nextNumber);

        $this->forceFill([
            'invoice_number_prefix' => $prefix,
            'next_invoice_number' => $nextNumber + 1,
        ])->save();

        return $number;
    }

    private function nextAvailableInvoiceNumber(string $prefix): int
    {
        $usedNumbers = $this->invoices()
            ->where('invoice_number', 'like', $prefix.'-%')
            ->pluck('invoice_number')
            ->map(function (string $invoiceNumber) use ($prefix): ?int {
                if (! preg_match('/^'.preg_quote($prefix, '/').'-([0-9]+)$/', $invoiceNumber, $matches)) {
                    return null;
                }

                return (int) $matches[1];
            })
            ->filter(fn (?int $number): bool => $number !== null && $number > 0)
            ->sort()
            ->values();

        $candidate = 1;

        foreach ($usedNumbers as $usedNumber) {
            if ($usedNumber !== $candidate) {
                break;
            }

            $candidate++;
        }

        return $candidate;
    }

    public function releaseInvoiceNumber(string $invoiceNumber): void
    {
        $prefix = strtoupper(trim((string) $this->invoice_number_prefix));

        if (! preg_match('/^'.preg_quote($prefix, '/').'-([0-9]+)$/', $invoiceNumber, $matches)) {
            return;
        }

        $releasedNumber = (int) $matches[1];

        if ($releasedNumber < 1) {
            return;
        }

        $this->next_invoice_number = min((int) $this->next_invoice_number, $releasedNumber);
        $this->save();
    }
}
