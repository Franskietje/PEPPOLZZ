<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('companies', function (Blueprint $table) {
            $table->id();
            $table->string('legal_name');
            $table->string('vat_number')->nullable()->index();
            $table->string('enterprise_number')->nullable()->index();
            $table->string('address_line1')->nullable();
            $table->string('address_line2')->nullable();
            $table->string('postal_code')->nullable();
            $table->string('city')->nullable();
            $table->char('country_code', 2)->default('BE');
            $table->string('email')->nullable();
            $table->string('iban')->nullable();
            $table->string('bic')->nullable();
            $table->string('default_currency', 3)->default('EUR');
            $table->string('invoice_number_prefix')->default('INV');
            $table->unsignedInteger('next_invoice_number')->default(1);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('companies');
    }
};
