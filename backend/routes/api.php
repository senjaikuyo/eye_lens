<?php

use App\Http\Controllers\UsersController;
use App\Http\Controllers\ChangePasswordController;
use Illuminate\Support\Facades\Route;

// Rute Publik (Autentikasi & Reset Password)
Route::post('/register', [UsersController::class, 'register']);
Route::post('/login', [UsersController::class, 'login']);

// Password Reset Routes
// Cooldown kirim ulang 60 detik ditangani per-email di controller.
// Throttle di sini melindungi dari penyalahgunaan per alamat IP.
Route::post('/forgot-password', [ChangePasswordController::class, 'sendResetCode'])
    ->middleware('throttle:10,1');
Route::post('/verify-reset-code', [ChangePasswordController::class, 'verifyResetCode'])
    ->middleware('throttle:10,1');
Route::post('/reset-password', [ChangePasswordController::class, 'resetPassword'])
    ->middleware('throttle:10,1');

// Rute Terproteksi Sanctum
Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [UsersController::class, 'logout']);
    Route::get('/me', [UsersController::class, 'getProfile']);
    Route::get('/profile', [UsersController::class, 'getProfile']);
    Route::post('/change-password', [ChangePasswordController::class, 'changePassword']);
});
