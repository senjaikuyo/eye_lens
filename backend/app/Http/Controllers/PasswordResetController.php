<?php

namespace App\Http\Controllers;

use App\Mail\ResetPasswordOtpMail;
use App\Models\PasswordResetCode;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
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
            // Hapus kode lama milik email ini
            PasswordResetCode::where('email', $email)->delete();

            // Generate kriptografis 6 digit angka
            $otp = (string) random_int(100000, 999999);

            PasswordResetCode::create([
                'email' => $email,
                'otp_hash' => Hash::make($otp),
                'attempts' => 0,
                'expires_at' => Carbon::now()->addMinutes(10),
            ]);

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
     * Verifikasi kode OTP 6 digit dan berikan reset token sementara.
     */
    public function verifyResetCode(Request $request): JsonResponse
    {
        $request->validate([
            'email' => ['required', 'string', 'email'],
            'code' => ['required', 'string', 'regex:/^[0-9]{6}$/'],
        ]);

        $email = strtolower(trim($request->email));
        $code = trim($request->code);

        $record = PasswordResetCode::where('email', $email)
            ->where('expires_at', '>', Carbon::now())
            ->first();

        if (! $record) {
            throw ValidationException::withMessages([
                'code' => ['Kode verifikasi tidak valid atau telah kedaluwarsa.'],
            ]);
        }

        if ($record->attempts >= 5) {
            $record->delete();
            throw ValidationException::withMessages([
                'code' => ['Batas percobaan telah habis. Silakan minta kode baru.'],
            ]);
        }

        if (! Hash::check($code, $record->otp_hash)) {
            $record->increment('attempts');
            $remaining = 5 - $record->attempts;
            
            if ($remaining <= 0) {
                $record->delete();
                throw ValidationException::withMessages([
                    'code' => ['Batas percobaan telah habis. Silakan minta kode baru.'],
                ]);
            }

            throw ValidationException::withMessages([
                'code' => ["Kode verifikasi salah. Sisa percobaan: {$remaining}."],
            ]);
        }

        // OTP valid -> generate reset token 64 karakter
        $plainResetToken = Str::random(64);

        $record->update([
            'reset_token_hash' => hash('sha256', $plainResetToken),
            'reset_token_expires_at' => Carbon::now()->addMinutes(15),
            'attempts' => 0,
        ]);

        return response()->json([
            'message' => 'Kode valid.',
            'reset_token' => $plainResetToken,
        ]);
    }

    /**
     * Simpan password baru menggunakan reset token.
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

        $record = PasswordResetCode::where('email', $email)
            ->where('reset_token_hash', $resetTokenHash)
            ->where('reset_token_expires_at', '>', Carbon::now())
            ->first();

        if (! $record) {
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

            // Hapus record reset code
            PasswordResetCode::where('email', $email)->delete();
        });

        return response()->json([
            'message' => 'Kata sandi berhasil diperbarui. Silakan masuk kembali.',
        ]);
    }
}
