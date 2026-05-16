<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Product;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ProductController extends Controller
{
    public function index(): JsonResponse
    {
        return response()->json(Product::orderBy('name')->get());
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'unit_price_ex_vat' => ['required', 'numeric', 'min:0'],
            'vat_rate' => ['required', 'numeric', 'min:0', 'max:100'],
            'unit_code' => ['nullable', 'string', 'max:20'],
            'account_code' => ['nullable', 'string', 'max:50'],
        ]);

        $product = Product::create($data);

        return response()->json($product, 201);
    }

    public function show(Product $product): JsonResponse
    {
        return response()->json($product);
    }

    public function update(Request $request, Product $product): JsonResponse
    {
        $data = $request->validate([
            'name' => ['sometimes', 'required', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'unit_price_ex_vat' => ['sometimes', 'required', 'numeric', 'min:0'],
            'vat_rate' => ['sometimes', 'required', 'numeric', 'min:0', 'max:100'],
            'unit_code' => ['nullable', 'string', 'max:20'],
            'account_code' => ['nullable', 'string', 'max:50'],
        ]);

        $product->update($data);

        return response()->json($product->refresh());
    }

    public function destroy(Product $product): JsonResponse
    {
        $product->delete();

        return response()->json(['deleted' => true]);
    }
}
