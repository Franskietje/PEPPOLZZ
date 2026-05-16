<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('receipts', function (Blueprint $table) {
            $table->string('ocr_status')->default('not_processed')->after('status'); // not_processed, processed, failed
            $table->longText('ocr_text')->nullable()->after('ocr_status');
            $table->json('ocr_data')->nullable()->after('ocr_text');
            $table->timestamp('ocr_processed_at')->nullable()->after('ocr_data');
        });
    }

    public function down(): void
    {
        Schema::table('receipts', function (Blueprint $table) {
            $table->dropColumn(['ocr_status', 'ocr_text', 'ocr_data', 'ocr_processed_at']);
        });
    }
};
