<?php

namespace App\Http\Controllers;

use App\Mail\ResetPasswordOtpMail;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Str;
use Illuminate\Validation\Rules\Password;
use Illuminate\Validation\ValidationException;

class PasswordResetController extends Controller
{
    /**
     * Kirim kode OTP 6-digit ke email pengguna.
     *
     * Respons selalu sama untuk email terdaftar maupun tidak terdaftar agar
     * penyerang tidak dapat memakai endpoint ini untuk memetakan akun.
     */
    public function sendResetCode(Request $request): JsonResponse
    {
        $request->validate([
            'email' => ['required', 'string', 'email'],
        ]);

        $email = $this->normalizeEmail((string) $request->input('email'));
        $cooldownSeconds = max(1, (int) config('eyelens.otp.resend_cooldown_seconds', 60));
        $cooldownKey = $this->cooldownKey($email);

        // Cache::add bersifat atomik: hanya request pertama dalam 60 detik
        // yang boleh mengirim/mengganti OTP untuk email ini.
        $cooldownEndsAt = now()->addSeconds($cooldownSeconds)->getTimestamp();

        if (! Cache::add($cooldownKey, $cooldownEndsAt, $cooldownSeconds)) {
            $retryAfter = max(
                1,
                (int) Cache::get($cooldownKey, $cooldownEndsAt) - now()->getTimestamp()
            );

            return response()
                ->json([
                    'message' => "Mohon tunggu {$retryAfter} detik sebelum meminta kode baru.",
                    'retry_after' => $retryAfter,
                ], 429)
                ->header('Retry-After', (string) $retryAfter);
        }

        // OTP dan reset token lama tidak boleh dipakai lagi.
        Cache::forget($this->resetTokenKey($email));
        Cache::forget($this->otpKey($email));

        $otp = (string) random_int(100000, 999999);
        $expiresAt = now()->addMinutes($this->otpExpiryMinutes());

        // Simpan hash OTP, bukan kode aslinya. Payload juga menyimpan waktu
        // kedaluwarsa agar sisa TTL tidak ikut bertambah saat percobaan salah.
        Cache::put($this->otpKey($email), [
            'otp_hash' => Hash::make($otp),
            'attempts' => 0,
            'expires_at' => $expiresAt->getTimestamp(),
        ], $expiresAt);

        // Selalu buat entri OTP (termasuk untuk email yang tidak terdaftar)
        // supaya respons verifikasi tidak membocorkan keberadaan akun.
        $user = $this->findUserByEmail($email);

        if ($user !== null) {
            try {
                Mail::to($user->email)->send(
                    new ResetPasswordOtpMail($otp, $this->otpExpiryMinutes())
                );
            } catch (\Throwable $e) {
                // Jangan bocorkan detail SMTP ke pengguna. Catat untuk admin.
                Log::error('Gagal mengirim OTP reset password.', [
                    'email' => $email,
                    'error' => $e->getMessage(),
                ]);
            }
        }

        return response()->json([
            'message' => 'Jika email terdaftar, kode verifikasi telah dikirim ke email Anda.',
            'expires_in' => $this->otpExpiryMinutes() * 60,
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

        $email = $this->normalizeEmail((string) $request->input('email'));
        $code = trim((string) $request->input('code'));
        $cacheKey = $this->otpKey($email);
        $cacheData = Cache::get($cacheKey);

        if (! is_array($cacheData) || ! isset($cacheData['otp_hash'])) {
            throw ValidationException::withMessages([
                'code' => ['Kode verifikasi tidak valid atau telah kedaluwarsa.'],
            ]);
        }

        if ((int) ($cacheData['expires_at'] ?? 0) <= now()->getTimestamp()) {
            Cache::forget($cacheKey);

            throw ValidationException::withMessages([
                'code' => ['Kode verifikasi tidak valid atau telah kedaluwarsa.'],
            ]);
        }

        $maxAttempts = max(1, (int) config('eyelens.otp.max_attempts', 5));
        $attempts = (int) ($cacheData['attempts'] ?? 0);

        if ($attempts >= $maxAttempts) {
            Cache::forget($cacheKey);

            throw ValidationException::withMessages([
                'code' => ['Batas percobaan telah habis. Silakan minta kode baru.'],
            ]);
        }

        if (! Hash::check($code, (string) $cacheData['otp_hash'])) {
            $attempts++;
            $remaining = $maxAttempts - $attempts;

            if ($remaining <= 0) {
                Cache::forget($cacheKey);

                throw ValidationException::withMessages([
                    'code' => ['Batas percobaan telah habis. Silakan minta kode baru.'],
                ]);
            }

            $remainingSeconds = max(
                1,
                (int) $cacheData['expires_at'] - now()->getTimestamp()
            );

            Cache::put($cacheKey, [
                'otp_hash' => $cacheData['otp_hash'],
                'attempts' => $attempts,
                'expires_at' => $cacheData['expires_at'],
            ], $remainingSeconds);

            throw ValidationException::withMessages([
                'code' => ["Kode verifikasi salah. Sisa percobaan: {$remaining}."],
            ]);
        }

        // OTP valid. Hapus OTP terlebih dahulu agar tidak dapat dipakai dua kali.
        Cache::forget($cacheKey);

        $plainResetToken = Str::random(64);
        $resetTokenTtl = max(1, (int) config('eyelens.otp.reset_token_ttl_minutes', 15));

        Cache::put(
            $this->resetTokenKey($email),
            hash('sha256', $plainResetToken),
            now()->addMinutes($resetTokenTtl)
        );

        return response()->json([
            'message' => 'Kode valid.',
            'reset_token' => $plainResetToken,
            'expires_in' => $resetTokenTtl * 60,
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

        $email = $this->normalizeEmail((string) $request->input('email'));
        $resetTokenHash = hash('sha256', (string) $request->input('reset_token'));
        $cacheKey = $this->resetTokenKey($email);
        $cachedTokenHash = Cache::get($cacheKey);

        if (! is_string($cachedTokenHash) || ! hash_equals($cachedTokenHash, $resetTokenHash)) {
            throw ValidationException::withMessages([
                'reset_token' => ['Sesi reset password tidak valid atau telah kedaluwarsa. Silakan ulangi proses.'],
            ]);
        }

        $user = $this->findUserByEmail($email);

        // Jangan bocorkan keberadaan akun. Token tetap dihapus agar tidak
        // dapat dipakai ulang, lalu kembalikan respons sukses yang seragam.
        if ($user === null) {
            Cache::forget($cacheKey);

            return response()->json([
                'message' => 'Kata sandi berhasil diperbarui. Silakan masuk kembali.',
            ]);
        }

        if (Hash::check((string) $request->input('password'), $user->password)) {
            throw ValidationException::withMessages([
                'password' => ['Kata sandi baru tidak boleh sama dengan kata sandi saat ini.'],
            ]);
        }

        // Konsumsi token secara atomik agar reset token hanya bisa dipakai sekali.
        $consumedTokenHash = Cache::pull($cacheKey);

        if (! is_string($consumedTokenHash) || ! hash_equals($consumedTokenHash, $resetTokenHash)) {
            throw ValidationException::withMessages([
                'reset_token' => ['Sesi reset password tidak valid atau telah kedaluwarsa. Silakan ulangi proses.'],
            ]);
        }

        DB::transaction(function () use ($user, $request): void {
            $user->forceFill([
                'password' => Hash::make((string) $request->input('password')),
            ])->save();

            // Revokasi seluruh token Sanctum aktif setelah password berubah.
            $user->tokens()->delete();
        });

        return response()->json([
            'message' => 'Kata sandi berhasil diperbarui. Silakan masuk kembali.',
        ]);
    }

    private function normalizeEmail(string $email): string
    {
        return strtolower(trim($email));
    }

    private function findUserByEmail(string $email): ?User
    {
        return User::where('email', $email)->first()
            ?? User::whereRaw('LOWER(email) = ?', [$email])->first();
    }

    private function otpExpiryMinutes(): int
    {
        return max(1, (int) config('eyelens.otp.expiry_minutes', 5));
    }

    private function otpKey(string $email): string
    {
        return "pwd_reset:{$email}";
    }

    private function resetTokenKey(string $email): string
    {
        return "pwd_reset_token:{$email}";
    }

    private function cooldownKey(string $email): string
    {
        return "pwd_reset_cooldown:{$email}";
    }
}
