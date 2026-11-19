<?php

use App\Http\Controllers\Api\MasukanController;
use App\Http\Controllers\Api\PengaturanController;
use App\Http\Controllers\Api\SyncController;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\PasswordResetController;
use Illuminate\Support\Facades\Route;

Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);

// Password Reset Routes
Route::post('/forgot-password', [PasswordResetController::class, 'sendResetCode'])
    ->middleware('throttle:3,15');
Route::post('/verify-reset-code', [PasswordResetController::class, 'verifyResetCode']);
Route::post('/reset-password', [PasswordResetController::class, 'resetPassword']);

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/me', [AuthController::class, 'me']);

    // Route Sinkronisasi
    Route::post('/sync', [SyncController::class, 'sync']);

    // Pengaturan dan masukan
    Route::put('/pengaturan', [PengaturanController::class, 'update']);
    Route::post('/masukan', [MasukanController::class, 'store']);
});
