#!/usr/bin/env bash
set -euo pipefail

# Run this from the Laravel project root after the PDF scaffold.
# It adds a basic UBL 2.1 / Peppol-style XML invoice export.
# Important: this is a first XML export foundation, not full Peppol/Schematron validation yet.

mkdir -p app/Services

cat > app/Services/UblInvoiceGenerator.php <<'PHP'
<?php

namespace App\Services;

use App\Models\Invoice;
use DOMDocument;
use DOMElement;

class UblInvoiceGenerator
{
    private const NS_INVOICE = 'urn:oasis:names:specification:ubl:schema:xsd:Invoice-2';
    private const NS_CAC = 'urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2';
    private const NS_CBC = 'urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2';

    public function generate(Invoice $invoice): string
    {
        $invoice->load(['company', 'customer', 'lines.product']);

        $dom = new DOMDocument('1.0', 'UTF-8');
        $dom->formatOutput = true;

        $root = $dom->createElementNS(self::NS_INVOICE, 'Invoice');
        $root->setAttributeNS('http://www.w3.org/2000/xmlns/', 'xmlns:cac', self::NS_CAC);
        $root->setAttributeNS('http://www.w3.org/2000/xmlns/', 'xmlns:cbc', self::NS_CBC);
        $dom->appendChild($root);

        $this->cbc($dom, $root, 'CustomizationID', 'urn:cen.eu:en16931:2017#compliant#urn:fdc:peppol.eu:2017:poacc:billing:3.0');
        $this->cbc($dom, $root, 'ProfileID', 'urn:fdc:peppol.eu:2017:poacc:billing:01:1.0');
        $this->cbc($dom, $root, 'ID', $invoice->invoice_number);
        $this->cbc($dom, $root, 'IssueDate', $invoice->issue_date?->format('Y-m-d'));
        $this->cbc($dom, $root, 'DueDate', $invoice->due_date?->format('Y-m-d'));
        $this->cbc($dom, $root, 'InvoiceTypeCode', '380');
        if ($invoice->notes) {
            $this->cbc($dom, $root, 'Note', $invoice->notes);
        }
        $this->cbc($dom, $root, 'DocumentCurrencyCode', $invoice->currency ?: 'EUR');

        $this->addSupplierParty($dom, $root, $invoice);
        $this->addCustomerParty($dom, $root, $invoice);
        $this->addPaymentMeans($dom, $root, $invoice);
        $this->addTaxTotal($dom, $root, $invoice);
        $this->addLegalMonetaryTotal($dom, $root, $invoice);
        $this->addInvoiceLines($dom, $root, $invoice);

        return $dom->saveXML();
    }

    private function addSupplierParty(DOMDocument $dom, DOMElement $root, Invoice $invoice): void
    {
        $company = $invoice->company;

        $accountingSupplierParty = $this->cac($dom, $root, 'AccountingSupplierParty');
        $party = $this->cac($dom, $accountingSupplierParty, 'Party');

        if ($company?->vat_number) {
            $endpointId = $this->cbc($dom, $party, 'EndpointID', $this->cleanBelgianNumber($company->vat_number));
            $endpointId->setAttribute('schemeID', '0208');
        }

        $partyName = $this->cac($dom, $party, 'PartyName');
        $this->cbc($dom, $partyName, 'Name', $company?->legal_name ?: 'Unknown supplier');

        $this->addAddress($dom, $party, 'PostalAddress', [
            'street' => $company?->address_line1,
            'city' => $company?->city,
            'postal_code' => $company?->postal_code,
            'country_code' => $company?->country_code ?: 'BE',
        ]);

        if ($company?->vat_number) {
            $partyTaxScheme = $this->cac($dom, $party, 'PartyTaxScheme');
            $this->cbc($dom, $partyTaxScheme, 'CompanyID', $company->vat_number);
            $taxScheme = $this->cac($dom, $partyTaxScheme, 'TaxScheme');
            $this->cbc($dom, $taxScheme, 'ID', 'VAT');
        }

        $partyLegalEntity = $this->cac($dom, $party, 'PartyLegalEntity');
        $this->cbc($dom, $partyLegalEntity, 'RegistrationName', $company?->legal_name ?: 'Unknown supplier');
        if ($company?->enterprise_number) {
            $this->cbc($dom, $partyLegalEntity, 'CompanyID', $company->enterprise_number);
        }

        if ($company?->email) {
            $contact = $this->cac($dom, $party, 'Contact');
            $this->cbc($dom, $contact, 'ElectronicMail', $company->email);
        }
    }

    private function addCustomerParty(DOMDocument $dom, DOMElement $root, Invoice $invoice): void
    {
        $customer = $invoice->customer;

        $accountingCustomerParty = $this->cac($dom, $root, 'AccountingCustomerParty');
        $party = $this->cac($dom, $accountingCustomerParty, 'Party');

        if ($customer?->vat_number) {
            $endpointId = $this->cbc($dom, $party, 'EndpointID', $this->cleanBelgianNumber($customer->vat_number));
            $endpointId->setAttribute('schemeID', '0208');
        }

        $partyName = $this->cac($dom, $party, 'PartyName');
        $this->cbc($dom, $partyName, 'Name', $customer?->name ?: 'Unknown customer');

        $this->addAddress($dom, $party, 'PostalAddress', [
            'street' => $customer?->address_line1,
            'city' => $customer?->city,
            'postal_code' => $customer?->postal_code,
            'country_code' => $customer?->country_code ?: 'BE',
        ]);

        if ($customer?->vat_number) {
            $partyTaxScheme = $this->cac($dom, $party, 'PartyTaxScheme');
            $this->cbc($dom, $partyTaxScheme, 'CompanyID', $customer->vat_number);
            $taxScheme = $this->cac($dom, $partyTaxScheme, 'TaxScheme');
            $this->cbc($dom, $taxScheme, 'ID', 'VAT');
        }

        $partyLegalEntity = $this->cac($dom, $party, 'PartyLegalEntity');
        $this->cbc($dom, $partyLegalEntity, 'RegistrationName', $customer?->name ?: 'Unknown customer');
        if ($customer?->enterprise_number) {
            $this->cbc($dom, $partyLegalEntity, 'CompanyID', $customer->enterprise_number);
        }

        if ($customer?->email) {
            $contact = $this->cac($dom, $party, 'Contact');
            $this->cbc($dom, $contact, 'ElectronicMail', $customer->email);
        }
    }

    private function addAddress(DOMDocument $dom, DOMElement $party, string $elementName, array $address): void
    {
        $postalAddress = $this->cac($dom, $party, $elementName);
        $this->cbc($dom, $postalAddress, 'StreetName', $address['street'] ?: 'Unknown street');
        $this->cbc($dom, $postalAddress, 'CityName', $address['city'] ?: 'Unknown city');
        $this->cbc($dom, $postalAddress, 'PostalZone', $address['postal_code'] ?: '0000');
        $country = $this->cac($dom, $postalAddress, 'Country');
        $this->cbc($dom, $country, 'IdentificationCode', $address['country_code'] ?: 'BE');
    }

    private function addPaymentMeans(DOMDocument $dom, DOMElement $root, Invoice $invoice): void
    {
        $company = $invoice->company;

        $paymentMeans = $this->cac($dom, $root, 'PaymentMeans');
        $this->cbc($dom, $paymentMeans, 'PaymentMeansCode', '30'); // Credit transfer
        if ($invoice->payment_reference) {
            $this->cbc($dom, $paymentMeans, 'PaymentID', $invoice->payment_reference);
        }

        if ($company?->iban) {
            $payeeFinancialAccount = $this->cac($dom, $paymentMeans, 'PayeeFinancialAccount');
            $this->cbc($dom, $payeeFinancialAccount, 'ID', str_replace(' ', '', $company->iban));
            if ($company->bic) {
                $financialInstitutionBranch = $this->cac($dom, $payeeFinancialAccount, 'FinancialInstitutionBranch');
                $this->cbc($dom, $financialInstitutionBranch, 'ID', $company->bic);
            }
        }
    }

    private function addTaxTotal(DOMDocument $dom, DOMElement $root, Invoice $invoice): void
    {
        $taxTotal = $this->cac($dom, $root, 'TaxTotal');
        $this->cbcAmount($dom, $taxTotal, 'TaxAmount', $invoice->total_vat, $invoice->currency);

        $groups = [];
        foreach ($invoice->lines as $line) {
            $rate = number_format((float) $line->vat_rate, 2, '.', '');
            if (! isset($groups[$rate])) {
                $groups[$rate] = [
                    'taxable' => 0.0,
                    'tax' => 0.0,
                ];
            }
            $groups[$rate]['taxable'] += (float) $line->line_total_ex_vat;
            $groups[$rate]['tax'] += (float) $line->line_vat;
        }

        foreach ($groups as $rate => $totals) {
            $taxSubtotal = $this->cac($dom, $taxTotal, 'TaxSubtotal');
            $this->cbcAmount($dom, $taxSubtotal, 'TaxableAmount', $totals['taxable'], $invoice->currency);
            $this->cbcAmount($dom, $taxSubtotal, 'TaxAmount', $totals['tax'], $invoice->currency);

            $taxCategory = $this->cac($dom, $taxSubtotal, 'TaxCategory');
            $this->cbc($dom, $taxCategory, 'ID', ((float) $rate) > 0 ? 'S' : 'Z');
            $this->cbc($dom, $taxCategory, 'Percent', $rate);
            $taxScheme = $this->cac($dom, $taxCategory, 'TaxScheme');
            $this->cbc($dom, $taxScheme, 'ID', 'VAT');
        }
    }

    private function addLegalMonetaryTotal(DOMDocument $dom, DOMElement $root, Invoice $invoice): void
    {
        $legalMonetaryTotal = $this->cac($dom, $root, 'LegalMonetaryTotal');
        $this->cbcAmount($dom, $legalMonetaryTotal, 'LineExtensionAmount', $invoice->subtotal_ex_vat, $invoice->currency);
        $this->cbcAmount($dom, $legalMonetaryTotal, 'TaxExclusiveAmount', $invoice->subtotal_ex_vat, $invoice->currency);
        $this->cbcAmount($dom, $legalMonetaryTotal, 'TaxInclusiveAmount', $invoice->total_inc_vat, $invoice->currency);
        $this->cbcAmount($dom, $legalMonetaryTotal, 'PayableAmount', $invoice->total_inc_vat, $invoice->currency);
    }

    private function addInvoiceLines(DOMDocument $dom, DOMElement $root, Invoice $invoice): void
    {
        foreach ($invoice->lines as $index => $line) {
            $invoiceLine = $this->cac($dom, $root, 'InvoiceLine');
            $this->cbc($dom, $invoiceLine, 'ID', (string) ($index + 1));
            $this->cbcQuantity($dom, $invoiceLine, 'InvoicedQuantity', $line->quantity, $line->unit_code ?: 'C62');
            $this->cbcAmount($dom, $invoiceLine, 'LineExtensionAmount', $line->line_total_ex_vat, $invoice->currency);

            $item = $this->cac($dom, $invoiceLine, 'Item');
            $this->cbc($dom, $item, 'Name', $line->description ?: 'Invoice line');
            $classifiedTaxCategory = $this->cac($dom, $item, 'ClassifiedTaxCategory');
            $this->cbc($dom, $classifiedTaxCategory, 'ID', ((float) $line->vat_rate) > 0 ? 'S' : 'Z');
            $this->cbc($dom, $classifiedTaxCategory, 'Percent', number_format((float) $line->vat_rate, 2, '.', ''));
            $taxScheme = $this->cac($dom, $classifiedTaxCategory, 'TaxScheme');
            $this->cbc($dom, $taxScheme, 'ID', 'VAT');

            $price = $this->cac($dom, $invoiceLine, 'Price');
            $this->cbcAmount($dom, $price, 'PriceAmount', $line->unit_price_ex_vat, $invoice->currency);
        }
    }

    private function cac(DOMDocument $dom, DOMElement $parent, string $name): DOMElement
    {
        $element = $dom->createElementNS(self::NS_CAC, 'cac:' . $name);
        $parent->appendChild($element);

        return $element;
    }

    private function cbc(DOMDocument $dom, DOMElement $parent, string $name, mixed $value): DOMElement
    {
        $element = $dom->createElementNS(self::NS_CBC, 'cbc:' . $name);
        $element->appendChild($dom->createTextNode((string) $value));
        $parent->appendChild($element);

        return $element;
    }

    private function cbcAmount(DOMDocument $dom, DOMElement $parent, string $name, mixed $value, string $currency): DOMElement
    {
        $element = $this->cbc($dom, $parent, $name, number_format((float) $value, 2, '.', ''));
        $element->setAttribute('currencyID', $currency ?: 'EUR');

        return $element;
    }

    private function cbcQuantity(DOMDocument $dom, DOMElement $parent, string $name, mixed $value, string $unitCode): DOMElement
    {
        $element = $this->cbc($dom, $parent, $name, number_format((float) $value, 3, '.', ''));
        $element->setAttribute('unitCode', $unitCode ?: 'C62');

        return $element;
    }

    private function cleanBelgianNumber(string $value): string
    {
        return preg_replace('/[^0-9]/', '', $value) ?: $value;
    }
}
PHP

# Add UBL method to Web InvoiceController.
php <<'PHP'
<?php
$path = 'app/Http/Controllers/Web/InvoiceController.php';
$text = file_get_contents($path);

if (strpos($text, 'use App\\Services\\UblInvoiceGenerator;') === false) {
    $text = str_replace(
        "use App\\Services\\InvoiceCalculator;\n",
        "use App\\Services\\InvoiceCalculator;\nuse App\\Services\\UblInvoiceGenerator;\n",
        $text
    );
}

$method = <<<'METHOD'

    public function downloadUbl(Invoice $invoice, UblInvoiceGenerator $generator)
    {
        $xml = $generator->generate($invoice);

        return response($xml, 200, [
            'Content-Type' => 'application/xml; charset=UTF-8',
            'Content-Disposition' => 'attachment; filename="' . $invoice->invoice_number . '.xml"',
        ]);
    }
METHOD;

if (strpos($text, 'function downloadUbl') === false) {
    $marker = "\n    public function downloadPdf(Invoice \$invoice)\n";
    if (strpos($text, $marker) !== false) {
        $text = str_replace($marker, $method . $marker, $text);
    } else {
        $marker = "\n    public function markPaid(Invoice \$invoice): RedirectResponse\n";
        $text = str_replace($marker, $method . $marker, $text);
    }
}

file_put_contents($path, $text);
PHP

# Add web route for UBL download.
php <<'PHP'
<?php
$path = 'routes/web.php';
$text = file_get_contents($path);
$route = "Route::get('/invoices/{invoice}/ubl', [InvoiceController::class, 'downloadUbl'])->name('web.invoices.ubl');\n";

if (strpos($text, 'web.invoices.ubl') === false) {
    $marker = "Route::get('/invoices/{invoice}/pdf', [InvoiceController::class, 'downloadPdf'])->name('web.invoices.pdf');\n";
    if (strpos($text, $marker) !== false) {
        $text = str_replace($marker, $marker . $route, $text);
    } else {
        $marker = "Route::get('/invoices/{invoice}', [InvoiceController::class, 'show'])->name('web.invoices.show');\n";
        $text = str_replace($marker, $route . $marker, $text);
    }
}

file_put_contents($path, $text);
PHP

# Add Download UBL button to invoice show page.
php <<'PHP'
<?php
$path = 'resources/views/invoices/show.blade.php';
$text = file_get_contents($path);
$button = <<<'BLADE'

        <a class="button secondary" href="{{ route('web.invoices.ubl', $invoice) }}">Download UBL XML</a>

BLADE;

if (strpos($text, 'web.invoices.ubl') === false) {
    $marker = "        <a class=\"button secondary\" href=\"{{ route('web.invoices.pdf', \$invoice) }}\">Download PDF</a>\n";
    if (strpos($text, $marker) !== false) {
        $text = str_replace($marker, $marker . $button, $text);
    } else {
        $marker = "        @if (\$invoice->status !== 'paid')\n";
        $text = str_replace($marker, $button . $marker, $text);
    }
}

file_put_contents($path, $text);
PHP

php artisan route:clear
php artisan view:clear
php artisan optimize:clear

echo "Milestone 3 UBL XML scaffold installed."
echo "Start/restart Laravel:"
echo "  php artisan serve"
echo ""
echo "Open an invoice and click Download UBL XML:"
echo "  http://127.0.0.1:8000/invoices"
