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
        $number = sprintf('%s-%04d', $this->invoice_number_prefix, $this->next_invoice_number);
        $this->increment('next_invoice_number');

        return $number;
    }
}
