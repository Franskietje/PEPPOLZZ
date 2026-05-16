#!/usr/bin/env bash
set -euo pipefail

# Run this from the root of a fresh Laravel project.
# It creates the Milestone 1 data model for a free-first invoicing app:
# companies, contacts, products, invoices, and invoice lines.

mkdir -p app/Models app/Services database/migrations

cat > database/migrations/2026_05_13_000001_create_companies_table.php <<'PHP'
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
PHP

cat > database/migrations/2026_05_13_000002_create_contacts_table.php <<'PHP'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('contacts', function (Blueprint $table) {
            $table->id();
            $table->string('type')->default('customer'); // customer, supplier, both
            $table->string('name');
            $table->string('vat_number')->nullable()->index();
            $table->string('enterprise_number')->nullable()->index();
            $table->string('address_line1')->nullable();
            $table->string('address_line2')->nullable();
            $table->string('postal_code')->nullable();
            $table->string('city')->nullable();
            $table->char('country_code', 2)->default('BE');
            $table->string('email')->nullable();
            $table->string('default_currency', 3)->default('EUR');
            $table->unsignedSmallInteger('payment_terms_days')->default(30);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('contacts');
    }
};
PHP

cat > database/migrations/2026_05_13_000003_create_products_table.php <<'PHP'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('products', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->text('description')->nullable();
            $table->decimal('unit_price_ex_vat', 12, 2)->default(0);
            $table->decimal('vat_rate', 5, 2)->default(21.00);
            $table->string('unit_code')->default('C62'); // C62 = one/unit in UNECE Rec 20
            $table->string('account_code')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('products');
    }
};
PHP

cat > database/migrations/2026_05_13_000004_create_invoices_table.php <<'PHP'
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
PHP

cat > database/migrations/2026_05_13_000005_create_invoice_lines_table.php <<'PHP'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('invoice_lines', function (Blueprint $table) {
            $table->id();
            $table->foreignId('invoice_id')->constrained()->cascadeOnDelete();
            $table->foreignId('product_id')->nullable()->constrained()->nullOnDelete();
            $table->text('description');
            $table->decimal('quantity', 12, 3)->default(1);
            $table->string('unit_code')->default('C62');
            $table->decimal('unit_price_ex_vat', 12, 2)->default(0);
            $table->decimal('vat_rate', 5, 2)->default(21.00);
            $table->decimal('line_total_ex_vat', 12, 2)->default(0);
            $table->decimal('line_vat', 12, 2)->default(0);
            $table->decimal('line_total_inc_vat', 12, 2)->default(0);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('invoice_lines');
    }
};
PHP

cat > app/Models/Company.php <<'PHP'
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
PHP

cat > app/Models/Contact.php <<'PHP'
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Contact extends Model
{
    use HasFactory;

    protected $guarded = [];

    public function customerInvoices(): HasMany
    {
        return $this->hasMany(Invoice::class, 'customer_id');
    }
}
PHP

cat > app/Models/Product.php <<'PHP'
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Product extends Model
{
    use HasFactory;

    protected $guarded = [];
}
PHP

cat > app/Models/Invoice.php <<'PHP'
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Invoice extends Model
{
    use HasFactory;

    protected $guarded = [];

    protected $casts = [
        'issue_date' => 'date',
        'due_date' => 'date',
    ];

    public function company(): BelongsTo
    {
        return $this->belongsTo(Company::class);
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Contact::class, 'customer_id');
    }

    public function lines(): HasMany
    {
        return $this->hasMany(InvoiceLine::class);
    }
}
PHP

cat > app/Models/InvoiceLine.php <<'PHP'
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class InvoiceLine extends Model
{
    use HasFactory;

    protected $guarded = [];

    public function invoice(): BelongsTo
    {
        return $this->belongsTo(Invoice::class);
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }
}
PHP

cat > app/Services/InvoiceCalculator.php <<'PHP'
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
PHP

cat > database/seeders/DatabaseSeeder.php <<'PHP'
<?php

namespace Database\Seeders;

use App\Models\Company;
use App\Models\Contact;
use App\Models\Product;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        Company::firstOrCreate([
            'legal_name' => 'Demo Company BV',
        ], [
            'vat_number' => 'BE0123456789',
            'enterprise_number' => '0123456789',
            'address_line1' => 'Demo Street 1',
            'postal_code' => '1000',
            'city' => 'Brussels',
            'country_code' => 'BE',
            'email' => 'hello@example.test',
            'iban' => 'BE68539007547034',
            'bic' => 'BBRUBEBB',
            'invoice_number_prefix' => 'INV',
            'next_invoice_number' => 1,
        ]);

        Contact::firstOrCreate([
            'name' => 'Demo Customer BV',
        ], [
            'type' => 'customer',
            'vat_number' => 'BE0987654321',
            'enterprise_number' => '0987654321',
            'address_line1' => 'Customer Street 10',
            'postal_code' => '2000',
            'city' => 'Antwerp',
            'country_code' => 'BE',
            'email' => 'customer@example.test',
            'payment_terms_days' => 30,
        ]);

        Product::firstOrCreate([
            'name' => 'Consulting hour',
        ], [
            'description' => 'Professional services per hour',
            'unit_price_ex_vat' => 85.00,
            'vat_rate' => 21.00,
            'unit_code' => 'HUR',
        ]);
    }
}
PHP

echo "Milestone 1 scaffold created."
echo "Next commands:"
echo "  php artisan migrate:fresh --seed"
echo "  php artisan tinker"
echo ""
echo "In Tinker you can create an invoice, add lines, then run App\\Services\\InvoiceCalculator."
