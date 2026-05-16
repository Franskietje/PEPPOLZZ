<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('incoming_invoice_lines', function (Blueprint $table) {
            $table->id();
            $table->foreignId('incoming_invoice_id')->constrained()->cascadeOnDelete();
            $table->string('line_number')->nullable();
            $table->text('description')->nullable();
            $table->decimal('quantity', 12, 3)->default(1);
            $table->string('unit_code')->default('C62');
            $table->decimal('unit_price_ex_vat', 12, 2)->default(0);
            $table->decimal('vat_rate', 5, 2)->default(0);
            $table->decimal('line_total_ex_vat', 12, 2)->default(0);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('incoming_invoice_lines');
    }
};
