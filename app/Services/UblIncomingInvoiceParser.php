<?php

namespace App\Services;

use RuntimeException;
use SimpleXMLElement;

class UblIncomingInvoiceParser
{
    public function parseFile(string $absolutePath): array
    {
        if (! file_exists($absolutePath)) {
            throw new RuntimeException('UBL/XML file not found.');
        }

        libxml_use_internal_errors(true);
        $xml = simplexml_load_file($absolutePath);

        if (! $xml instanceof SimpleXMLElement) {
            $errors = collect(libxml_get_errors())->map(fn ($e) => trim($e->message))->implode(' ');
            libxml_clear_errors();
            throw new RuntimeException('Invalid XML file. ' . $errors);
        }

        return $this->parseXml($xml);
    }

    public function parseXml(SimpleXMLElement $xml): array
    {
        $cbc = 'urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2';
        $cac = 'urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2';

        $supplierParty = $xml->children($cac)->AccountingSupplierParty?->children($cac)->Party;
        $supplierName = $this->firstText([
            $supplierParty?->children($cac)->PartyName?->children($cbc)->Name ?? null,
            $supplierParty?->children($cac)->PartyLegalEntity?->children($cbc)->RegistrationName ?? null,
        ]);
        $supplierVat = $this->firstText([
            $supplierParty?->children($cac)->PartyTaxScheme?->children($cbc)->CompanyID ?? null,
            $supplierParty?->children($cbc)->EndpointID ?? null,
        ]);

        $legalTotal = $xml->children($cac)->LegalMonetaryTotal;
        $taxTotal = $xml->children($cac)->TaxTotal;

        $lines = [];
        foreach ($xml->children($cac)->InvoiceLine as $line) {
            $item = $line->children($cac)->Item;
            $price = $line->children($cac)->Price;
            $qtyNode = $line->children($cbc)->InvoicedQuantity;
            $taxCategory = $item?->children($cac)->ClassifiedTaxCategory;

            $quantity = $this->number($qtyNode);
            $unitCode = $qtyNode instanceof SimpleXMLElement ? (string) $qtyNode['unitCode'] : 'C62';

            $lines[] = [
                'line_number' => $this->text($line->children($cbc)->ID),
                'description' => $this->firstText([
                    $item?->children($cbc)->Name ?? null,
                    $item?->children($cbc)->Description ?? null,
                ]),
                'quantity' => $quantity ?: 1,
                'unit_code' => $unitCode ?: 'C62',
                'unit_price_ex_vat' => $this->number($price?->children($cbc)->PriceAmount),
                'vat_rate' => $this->number($taxCategory?->children($cbc)->Percent),
                'line_total_ex_vat' => $this->number($line->children($cbc)->LineExtensionAmount),
            ];
        }

        return [
            'invoice_number' => $this->text($xml->children($cbc)->ID),
            'issue_date' => $this->date($xml->children($cbc)->IssueDate),
            'due_date' => $this->date($xml->children($cbc)->DueDate),
            'currency' => $this->text($xml->children($cbc)->DocumentCurrencyCode) ?: 'EUR',
            'supplier_name' => $supplierName,
            'supplier_vat_number' => $supplierVat,
            'subtotal_ex_vat' => $this->number($legalTotal?->children($cbc)->TaxExclusiveAmount)
                ?: $this->number($legalTotal?->children($cbc)->LineExtensionAmount),
            'total_vat' => $this->number($taxTotal?->children($cbc)->TaxAmount),
            'total_inc_vat' => $this->number($legalTotal?->children($cbc)->TaxInclusiveAmount)
                ?: $this->number($legalTotal?->children($cbc)->PayableAmount),
            'lines' => $lines,
        ];
    }

    private function text(mixed $node): ?string
    {
        if (! $node instanceof SimpleXMLElement) {
            return null;
        }

        $value = trim((string) $node);

        return $value === '' ? null : $value;
    }

    private function firstText(array $nodes): ?string
    {
        foreach ($nodes as $node) {
            $value = $this->text($node);
            if ($value) {
                return $value;
            }
        }

        return null;
    }

    private function number(mixed $node): float
    {
        $value = $this->text($node);

        if ($value === null) {
            return 0.0;
        }

        return round((float) str_replace(',', '.', $value), 2);
    }

    private function date(mixed $node): ?string
    {
        $value = $this->text($node);

        return $value ?: null;
    }
}
