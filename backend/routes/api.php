<?php

use App\Http\Controllers\UsersController;
use App\Http\Controllers\ChangePasswordController;
use Illuminate\Support\Facades\Route;

// Rute Publik (Autentikasi & Reset Password)
Route::post('/register', [UsersController::class, 'register']);
Route::post('/login', [UsersController::class, 'login']);

Route::post('/forgot-password', [ChangePasswordController::class, 'sendResetCode'])
    ->middleware('throttle:3,15');
Route::post('/verify-reset-code', [ChangePasswordController::class, 'verifyResetCode']);
Route::post('/reset-password', [ChangePasswordController::class, 'resetPassword']);

// Rute Terproteksi Sanctum
Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [UsersController::class, 'logout']);
    Route::get('/me', [UsersController::class, 'getProfile']);
    Route::get('/profile', [UsersController::class, 'getProfile']);
    Route::post('/change-password', [ChangePasswordController::class, 'changePassword']);
});
