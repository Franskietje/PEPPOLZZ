<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\Contact;
use App\Models\IncomingInvoice;
use App\Models\Invoice;
use App\Models\Product;
use App\Models\Receipt;
use Illuminate\View\View;

class DashboardController extends Controller
{
    public function __invoke(): View
    {
        return view('dashboard', [
            'contactsCount' => Contact::count(),
            'productsCount' => Product::count(),
            'invoicesCount' => Invoice::count(),
            'incomingInvoicesCount' => IncomingInvoice::count(),
            'receiptsCount' => Receipt::count(),
            'recentInvoices' => Invoice::with('customer')->latest('id')->limit(5)->get(),
        ]);
    }
}
