<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('incoming_invoices', function (Blueprint $table) {
            $table->id();
            $table->foreignId('supplier_id')->nullable()->constrained('contacts')->nullOnDelete();
            $table->string('supplier_name')->nullable();
            $table->string('supplier_vat_number')->nullable()->index();
            $table->string('invoice_number')->nullable()->index();
            $table->date('issue_date')->nullable();
            $table->date('due_date')->nullable();
            $table->string('currency', 3)->default('EUR');
            $table->decimal('subtotal_ex_vat', 12, 2)->default(0);
            $table->decimal('total_vat', 12, 2)->default(0);
            $table->decimal('total_inc_vat', 12, 2)->default(0);
            $table->string('status')->default('needs_review'); // needs_review, approved, rejected
            $table->string('original_file_path');
            $table->string('original_file_name')->nullable();
            $table->json('parsed_data')->nullable();
            $table->text('notes')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('incoming_invoices');
    }
};
