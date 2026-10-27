<?php

namespace App\Http\Controllers;

use App\Mail\ResetPasswordOtpMail;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Str;
use Illuminate\Validation\Rules\Password;
use Illuminate\Validation\ValidationException;

class PasswordResetController extends Controller
{
    /**
     * Kirim kode OTP 6-digit ke email pengguna.
     */
    public function sendResetCode(Request $request): JsonResponse
    {
        $request->validate([
            'email' => ['required', 'string', 'email'],
        ]);

        $email = strtolower(trim($request->email));
        $user = User::where('email', $email)->first();

        if ($user) {
            // Hapus cache OTP dan token lama jika ada
            Cache::forget("pwd_reset:{$email}");
            Cache::forget("pwd_reset_token:{$email}");

            // Generate kriptografis 6 digit angka
            $otp = (string) random_int(100000, 999999);

            // Simpan hash OTP di Cache selama 10 menit
            Cache::put("pwd_reset:{$email}", [
                'otp_hash' => Hash::make($otp),
                'attempts' => 0,
            ], now()->addMinutes(10));

            // Kirim email
            try {
                Mail::to($email)->send(new ResetPasswordOtpMail($otp));
            } catch (\Throwable $e) {
                // Abaikan kesalahan koneksi mailer agar tidak membocorkan status internal
            }
        }

        // Pesan seragam untuk mencegah user enumeration
        return response()->json([
            'message' => 'Jika email terdaftar, kode verifikasi telah dikirim ke email Anda.',
        ]);
    }

    /**
     * Verifikasi kode OTP 6 digit dan berikan reset token sementara via Cache.
     */
    public function verifyResetCode(Request $request): JsonResponse
    {
        $request->validate([
            'email' => ['required', 'string', 'email'],
            'code' => ['required', 'string', 'regex:/^[0-9]{6}$/'],
        ]);

        $email = strtolower(trim($request->email));
        $code = trim($request->code);

        $cacheData = Cache::get("pwd_reset:{$email}");

        if (! $cacheData) {
            throw ValidationException::withMessages([
                'code' => ['Kode verifikasi tidak valid atau telah kedaluwarsa.'],
            ]);
        }

        if ($cacheData['attempts'] >= 5) {
            Cache::forget("pwd_reset:{$email}");
            throw ValidationException::withMessages([
                'code' => ['Batas percobaan telah habis. Silakan minta kode baru.'],
            ]);
        }

        if (! Hash::check($code, $cacheData['otp_hash'])) {
            $cacheData['attempts']++;
            $remaining = 5 - $cacheData['attempts'];

            if ($remaining <= 0) {
                Cache::forget("pwd_reset:{$email}");
                throw ValidationException::withMessages([
                    'code' => ['Batas percobaan telah habis. Silakan minta kode baru.'],
                ]);
            }

            Cache::put("pwd_reset:{$email}", $cacheData, now()->addMinutes(10));

            throw ValidationException::withMessages([
                'code' => ["Kode verifikasi salah. Sisa percobaan: {$remaining}."],
            ]);
        }

        // OTP valid -> generate reset token 64 karakter
        $plainResetToken = Str::random(64);

        // Simpan token hash di Cache selama 15 menit
        Cache::put("pwd_reset_token:{$email}", hash('sha256', $plainResetToken), now()->addMinutes(15));
        
        // Hapus cache OTP karena sudah berhasil diverifikasi
        Cache::forget("pwd_reset:{$email}");

        return response()->json([
            'message' => 'Kode valid.',
            'reset_token' => $plainResetToken,
        ]);
    }

    /**
     * Simpan password baru menggunakan reset token dari Cache.
     */
    public function resetPassword(Request $request): JsonResponse
    {
        $request->validate([
            'email' => ['required', 'string', 'email'],
            'reset_token' => ['required', 'string'],
            'password' => [
                'required',
                'string',
                'confirmed',
                Password::min(8)
                    ->letters()
                    ->mixedCase()
                    ->numbers()
                    ->symbols(),
            ],
        ]);

        $email = strtolower(trim($request->email));
        $resetTokenHash = hash('sha256', $request->reset_token);

        $cachedTokenHash = Cache::get("pwd_reset_token:{$email}");

        if (! $cachedTokenHash || ! hash_equals($cachedTokenHash, $resetTokenHash)) {
            throw ValidationException::withMessages([
                'reset_token' => ['Sesi reset password tidak valid atau telah kedaluwarsa. Silakan ulangi proses.'],
            ]);
        }

        $user = User::where('email', $email)->first();

        if (! $user) {
            throw ValidationException::withMessages([
                'email' => ['Pengguna tidak ditemukan.'],
            ]);
        }

        // Cek apakah password baru sama dengan password lama
        if (Hash::check($request->password, $user->password)) {
            throw ValidationException::withMessages([
                'password' => ['Kata sandi baru tidak boleh sama dengan kata sandi saat ini.'],
            ]);
        }

        // DB Transaction atomik
        DB::transaction(function () use ($user, $request, $email) {
            $user->update([
                'password' => Hash::make($request->password),
            ]);

            // Revokasi seluruh token Sanctum aktif
            $user->tokens()->delete();

            // Hapus reset token dari cache
            Cache::forget("pwd_reset_token:{$email}");
        });

        return response()->json([
            'message' => 'Kata sandi berhasil diperbarui. Silakan masuk kembali.',
        ]);
    }
}
