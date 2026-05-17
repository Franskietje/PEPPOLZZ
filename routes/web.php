<?php

use App\Http\Controllers\Web\CompanyController;
use App\Http\Controllers\Web\ContactController;
use App\Http\Controllers\Web\DashboardController;
use App\Http\Controllers\Web\IncomingInvoiceController;
use App\Http\Controllers\Web\InvoiceController;
use App\Http\Controllers\Web\ProductController;
use App\Http\Controllers\Web\ReceiptController;
use Illuminate\Support\Facades\Route;

Route::get('/', DashboardController::class)->name('web.dashboard');

Route::get('/company', [CompanyController::class, 'edit'])->name('web.company.edit');
Route::put('/company', [CompanyController::class, 'update'])->name('web.company.update');

Route::get('/contacts', [ContactController::class, 'index'])->name('web.contacts.index');
Route::get('/contacts/create', [ContactController::class, 'create'])->name('web.contacts.create');
Route::post('/contacts', [ContactController::class, 'store'])->name('web.contacts.store');


Route::get('/receipts', [ReceiptController::class, 'index'])->name('web.receipts.index');
Route::get('/receipts/create', [ReceiptController::class, 'create'])->name('web.receipts.create');
Route::post('/receipts', [ReceiptController::class, 'store'])->name('web.receipts.store');
Route::get('/receipts/{receipt}/view', [ReceiptController::class, 'viewFile'])->name('web.receipts.view');
Route::get('/receipts/{receipt}', [ReceiptController::class, 'show'])->name('web.receipts.show');
Route::put('/receipts/{receipt}', [ReceiptController::class, 'update'])->name('web.receipts.update');
Route::delete('/receipts/{receipt}', [ReceiptController::class, 'destroy'])->name('web.receipts.destroy');
Route::get('/receipts/{receipt}/download', [ReceiptController::class, 'download'])->name('web.receipts.download');
Route::post('/receipts/{receipt}/ocr', [ReceiptController::class, 'runOcr'])->name('web.receipts.ocr');
Route::post('/receipts/{receipt}/apply-ocr', [ReceiptController::class, 'applyOcrSuggestions'])->name('web.receipts.apply-ocr');
Route::post('/receipts/{receipt}/approve', [ReceiptController::class, 'approve'])->name('web.receipts.approve');
Route::post('/receipts/{receipt}/reject', [ReceiptController::class, 'reject'])->name('web.receipts.reject');
Route::get('/products', [ProductController::class, 'index'])->name('web.products.index');
Route::get('/products/create', [ProductController::class, 'create'])->name('web.products.create');
Route::post('/products', [ProductController::class, 'store'])->name('web.products.store');


Route::get('/incoming-invoices', [IncomingInvoiceController::class, 'index'])->name('web.incoming-invoices.index');
Route::get('/incoming-invoices/create', [IncomingInvoiceController::class, 'create'])->name('web.incoming-invoices.create');
Route::post('/incoming-invoices', [IncomingInvoiceController::class, 'store'])->name('web.incoming-invoices.store');
Route::get('/incoming-invoices/{incomingInvoice}', [IncomingInvoiceController::class, 'show'])->name('web.incoming-invoices.show');
Route::put('/incoming-invoices/{incomingInvoice}', [IncomingInvoiceController::class, 'update'])->name('web.incoming-invoices.update');
Route::delete('/incoming-invoices/{incomingInvoice}', [IncomingInvoiceController::class, 'destroy'])->name('web.incoming-invoices.destroy');
Route::get('/incoming-invoices/{incomingInvoice}/download', [IncomingInvoiceController::class, 'download'])->name('web.incoming-invoices.download');
Route::post('/incoming-invoices/{incomingInvoice}/approve', [IncomingInvoiceController::class, 'approve'])->name('web.incoming-invoices.approve');
Route::post('/incoming-invoices/{incomingInvoice}/reject', [IncomingInvoiceController::class, 'reject'])->name('web.incoming-invoices.reject');
Route::get('/invoices', [InvoiceController::class, 'index'])->name('web.invoices.index');
Route::get('/invoices/create', [InvoiceController::class, 'create'])->name('web.invoices.create');
Route::post('/invoices', [InvoiceController::class, 'store'])->name('web.invoices.store');
Route::get('/invoices/{invoice}/pdf', [InvoiceController::class, 'downloadPdf'])->name('web.invoices.pdf');
Route::get('/invoices/{invoice}/ubl', [InvoiceController::class, 'downloadUbl'])->name('web.invoices.ubl');
Route::get('/invoices/{invoice}', [InvoiceController::class, 'show'])->name('web.invoices.show');
Route::delete('/invoices/{invoice}', [InvoiceController::class, 'destroy'])->name('web.invoices.destroy');
Route::post('/invoices/{invoice}/lines', [InvoiceController::class, 'addLine'])->name('web.invoices.lines.add');
Route::delete('/invoices/{invoice}/lines/{line}', [InvoiceController::class, 'deleteLine'])->name('web.invoices.lines.delete');
Route::post('/invoices/{invoice}/mark-paid', [InvoiceController::class, 'markPaid'])->name('web.invoices.mark-paid');
