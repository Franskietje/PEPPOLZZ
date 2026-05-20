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
        $nextNumber = max(1, (int) $this->next_invoice_number);

        while ($this->invoices()->where('invoice_number', sprintf('%s-%04d', $prefix, $nextNumber))->exists()) {
            $nextNumber++;
        }

        $number = sprintf('%s-%04d', $prefix, $nextNumber);

        $this->forceFill([
            'invoice_number_prefix' => $prefix,
            'next_invoice_number' => $nextNumber + 1,
        ])->save();

        return $number;
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
