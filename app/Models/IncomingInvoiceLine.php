<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class IncomingInvoiceLine extends Model
{
    use HasFactory;

    protected $guarded = [];

    public function incomingInvoice(): BelongsTo
    {
        return $this->belongsTo(IncomingInvoice::class);
    }
}
