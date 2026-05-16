<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('invoices', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->foreignId('customer_id')->constrained('contacts')->restrictOnDelete();
            $table->string('invoice_type')->default('invoice'); // invoice, credit_note
            $table->string('invoice_number')->unique();
            $table->date('issue_date');
            $table->date('due_date');
            $table->string('currency', 3)->default('EUR');
            $table->string('status')->default('draft'); // draft, ready, validated, sent, paid, cancelled
            $table->string('payment_reference')->nullable();
            $table->text('notes')->nullable();
            $table->decimal('subtotal_ex_vat', 12, 2)->default(0);
            $table->decimal('total_vat', 12, 2)->default(0);
            $table->decimal('total_inc_vat', 12, 2)->default(0);
            $table->string('xml_storage_path')->nullable();
            $table->string('pdf_storage_path')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('invoices');
    }
};
