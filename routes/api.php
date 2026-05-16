<?php

use App\Http\Controllers\Api\ContactController;
use App\Http\Controllers\Api\InvoiceController;
use App\Http\Controllers\Api\InvoiceLineController;
use App\Http\Controllers\Api\ProductController;
use Illuminate\Support\Facades\Route;

Route::get('/health', fn () => ['ok' => true]);

Route::apiResource('contacts', ContactController::class);
Route::apiResource('products', ProductController::class);
Route::apiResource('invoices', InvoiceController::class);

Route::post('/invoices/{invoice}/recalculate', [InvoiceController::class, 'recalculate']);
Route::post('/invoices/{invoice}/lines', [InvoiceLineController::class, 'store']);
Route::put('/invoices/{invoice}/lines/{line}', [InvoiceLineController::class, 'update']);
Route::delete('/invoices/{invoice}/lines/{line}', [InvoiceLineController::class, 'destroy']);
