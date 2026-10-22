<?php

use Illuminate\Support\Facades\Route;


// Login
Route::get('/', function () {
    return view('auth.login');
})->name('login');


// Dashboard
Route::get('/admin/dashboard', function () {
    return view('Admin.dashboardAdmin');
})->name('admin.dashboard');


// Log Activity
Route::get('/admin/logActivity', function () {
    return view('Admin.logActivity');
})->name('admin.logActivity');


// Feedback User
Route::get('/admin/feedback', function () {
    return view('Admin.feedbackUser');
})->name('admin.feedback');