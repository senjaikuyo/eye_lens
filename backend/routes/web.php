<?php

use App\Http\Controllers\AdminAuthController;
use App\Http\Middleware\EnsureUserIsAdmin;
use Illuminate\Support\Facades\Route;

// Login & Logout Admin
Route::get('/', [AdminAuthController::class, 'showLoginForm'])->name('login');
Route::post('/admin/login', [AdminAuthController::class, 'login'])->name('admin.login.submit');
Route::post('/admin/logout', [AdminAuthController::class, 'logout'])->name('admin.logout');

// Rute Panel Admin Terproteksi
Route::middleware(EnsureUserIsAdmin::class)->prefix('admin')->name('admin.')->group(function () {
    Route::get('/dashboard', function () {
        return view('Admin.dashboardAdmin');
    })->name('dashboard');

    Route::get('/logActivity', function () {
        return view('Admin.logActivity');
    })->name('logActivity');

    Route::get('/feedback', function () {
        return view('Admin.feedbackUser');
    })->name('feedback');
});
