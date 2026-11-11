<?php

use App\Http\Controllers\AuthController;
use App\Http\Controllers\PasswordResetController;
use Illuminate\Support\Facades\Route;

Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);

// Password Reset Routes
// Cooldown kirim ulang 60 detik ditangani per-email di controller.
// Throttle di sini melindungi dari penyalahgunaan per alamat IP.
Route::post('/forgot-password', [PasswordResetController::class, 'sendResetCode'])
    ->middleware('throttle:10,1');
Route::post('/verify-reset-code', [PasswordResetController::class, 'verifyResetCode'])
    ->middleware('throttle:10,1');
Route::post('/reset-password', [PasswordResetController::class, 'resetPassword'])
    ->middleware('throttle:10,1');

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/me', [AuthController::class, 'me']);
});
