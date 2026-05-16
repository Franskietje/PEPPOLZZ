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
