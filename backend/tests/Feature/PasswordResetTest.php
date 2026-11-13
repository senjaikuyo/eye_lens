<?php

namespace Tests\Feature;

use App\Mail\ResetPasswordOtpMail;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Tests\TestCase;

class PasswordResetTest extends TestCase
{
    use RefreshDatabase;

    public function test_send_reset_code_generates_otp_and_sends_email_for_existing_user(): void
    {
        Mail::fake();

        User::factory()->create([
            'email' => 'user@example.com',
        ]);

        $response = $this->postJson('/api/forgot-password', [
            'email' => 'user@example.com',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'message' => 'Jika email terdaftar, kode verifikasi telah dikirim ke email Anda.',
                'expires_in' => 300,
            ]);

        $cacheData = Cache::get('pwd_reset:user@example.com');

        $this->assertIsArray($cacheData);
        $this->assertSame(0, $cacheData['attempts']);
        $this->assertGreaterThan(now()->getTimestamp(), $cacheData['expires_at']);

        $sentOtp = null;
        Mail::assertSent(ResetPasswordOtpMail::class, function ($mail) use (&$sentOtp) {
            $sentOtp = $mail->otp;

            return $mail->hasTo('user@example.com') && strlen($mail->otp) === 6;
        });

        $this->assertNotNull($sentOtp);
        $this->assertTrue(Hash::check($sentOtp, $cacheData['otp_hash']));
    }

    public function test_send_reset_code_returns_same_message_for_non_existent_email(): void
    {
        Mail::fake();

        $response = $this->postJson('/api/forgot-password', [
            'email' => 'unknown@example.com',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'message' => 'Jika email terdaftar, kode verifikasi telah dikirim ke email Anda.',
                'expires_in' => 300,
            ]);

        Mail::assertNothingSent();

        // Entri OTP dummy tetap dibuat agar verifikasi tidak membocorkan
        // apakah email benar-benar terdaftar atau tidak.
        $this->assertIsArray(Cache::get('pwd_reset:unknown@example.com'));
    }

    public function test_new_otp_request_invalidates_previous_reset_token(): void
    {
        Mail::fake();
        User::factory()->create(['email' => 'invalidate@example.com']);
        $this->seedResetToken('invalidate@example.com', 'old-reset-token');

        $this->postJson('/api/forgot-password', ['email' => 'invalidate@example.com'])
            ->assertStatus(200);

        $this->assertNull(Cache::get('pwd_reset_token:invalidate@example.com'));
    }

    public function test_forgot_password_enforces_60_second_resend_cooldown(): void
    {
        Mail::fake();
        User::factory()->create(['email' => 'resend@example.com']);

        $this->postJson('/api/forgot-password', ['email' => 'resend@example.com'])
            ->assertStatus(200);

        $blocked = $this->postJson('/api/forgot-password', ['email' => 'resend@example.com']);

        $blocked->assertStatus(429)
            ->assertJsonStructure(['message', 'retry_after']);

        $this->assertGreaterThan(0, $blocked->json('retry_after'));
        $this->assertLessThanOrEqual(60, $blocked->json('retry_after'));

        $this->travel(61)->seconds();

        $this->postJson('/api/forgot-password', ['email' => 'resend@example.com'])
            ->assertStatus(200);

        Mail::assertSentTimes(ResetPasswordOtpMail::class, 2);
    }

    public function test_verify_reset_code_fails_with_invalid_code_and_does_not_extend_expiry(): void
    {
        $this->seedOtp('verify@example.com', '123456');
        $before = Cache::get('pwd_reset:verify@example.com');

        $response = $this->postJson('/api/verify-reset-code', [
            'email' => 'verify@example.com',
            'code' => '654321',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['code']);

        $after = Cache::get('pwd_reset:verify@example.com');

        $this->assertSame(1, $after['attempts']);
        $this->assertSame($before['expires_at'], $after['expires_at']);
    }

    public function test_verify_reset_code_deletes_otp_after_max_attempts(): void
    {
        $this->seedOtp('max@example.com', '123456', attempts: 4);

        $response = $this->postJson('/api/verify-reset-code', [
            'email' => 'max@example.com',
            'code' => '000000',
        ]);

        $response->assertStatus(422);
        $this->assertNull(Cache::get('pwd_reset:max@example.com'));
    }

    public function test_verify_reset_code_rejects_expired_otp(): void
    {
        Cache::put('pwd_reset:expired@example.com', [
            'otp_hash' => Hash::make('123456'),
            'attempts' => 0,
            'expires_at' => now()->subMinute()->getTimestamp(),
        ], now()->addMinute());

        $response = $this->postJson('/api/verify-reset-code', [
            'email' => 'expired@example.com',
            'code' => '123456',
        ]);

        $response->assertStatus(422);
        $this->assertNull(Cache::get('pwd_reset:expired@example.com'));
    }

    public function test_verify_reset_code_succeeds_and_can_only_be_used_once(): void
    {
        $this->seedOtp('success@example.com', '654321');

        $response = $this->postJson('/api/verify-reset-code', [
            'email' => 'success@example.com',
            'code' => '654321',
        ]);

        $response->assertStatus(200)
            ->assertJsonStructure(['message', 'reset_token', 'expires_in']);

        $resetToken = (string) $response->json('reset_token');
        $this->assertSame(64, strlen($resetToken));

        $this->assertNull(Cache::get('pwd_reset:success@example.com'));
        $this->assertSame(
            hash('sha256', $resetToken),
            Cache::get('pwd_reset_token:success@example.com')
        );

        // OTP yang sama tidak boleh dipakai untuk kedua kalinya.
        $this->postJson('/api/verify-reset-code', [
            'email' => 'success@example.com',
            'code' => '654321',
        ])->assertStatus(422);
    }

    public function test_reset_password_updates_hash_and_revokes_tokens(): void
    {
        $user = User::factory()->create([
            'email' => 'complete@example.com',
            'password' => Hash::make('OldPassword123!'),
        ]);

        $user->createToken('test_token');
        $this->assertCount(1, $user->tokens);

        $plainResetToken = 'plain-token-complete-test-123456789012345678901234567890123456';
        $this->seedResetToken('complete@example.com', $plainResetToken);

        $newPassword = 'NewSecretPassword2026@!';
        $response = $this->postJson('/api/reset-password', [
            'email' => 'complete@example.com',
            'reset_token' => $plainResetToken,
            'password' => $newPassword,
            'password_confirmation' => $newPassword,
        ]);

        $response->assertStatus(200)
            ->assertJson(['message' => 'Kata sandi berhasil diperbarui. Silakan masuk kembali.']);

        $user->refresh();
        $this->assertTrue(Hash::check($newPassword, $user->password));
        $this->assertCount(0, $user->tokens);
        $this->assertNull(Cache::get('pwd_reset_token:complete@example.com'));

        // Reset token juga hanya dapat dipakai sekali.
        $this->postJson('/api/reset-password', [
            'email' => 'complete@example.com',
            'reset_token' => $plainResetToken,
            'password' => 'AnotherPassword2026@!',
            'password_confirmation' => 'AnotherPassword2026@!',
        ])->assertStatus(422)
            ->assertJsonValidationErrors(['reset_token']);
    }

    public function test_reset_password_rejects_weak_password_or_same_as_old_password(): void
    {
        $oldPassword = 'OldPassword123!';
        User::factory()->create([
            'email' => 'reset@example.com',
            'password' => Hash::make($oldPassword),
        ]);

        $plainResetToken = 'valid-reset-token-sample-string-12345678901234567890123456789012';
        $this->seedResetToken('reset@example.com', $plainResetToken);

        $responseSame = $this->postJson('/api/reset-password', [
            'email' => 'reset@example.com',
            'reset_token' => $plainResetToken,
            'password' => $oldPassword,
            'password_confirmation' => $oldPassword,
        ]);
        $responseSame->assertStatus(422)
            ->assertJsonValidationErrors(['password']);

        // Token belum boleh hangus jika password ditolak.
        $this->assertNotNull(Cache::get('pwd_reset_token:reset@example.com'));

        $responseWeak = $this->postJson('/api/reset-password', [
            'email' => 'reset@example.com',
            'reset_token' => $plainResetToken,
            'password' => 'simplepass123',
            'password_confirmation' => 'simplepass123',
        ]);
        $responseWeak->assertStatus(422)
            ->assertJsonValidationErrors(['password']);

        $this->assertNotNull(Cache::get('pwd_reset_token:reset@example.com'));
    }

    public function test_register_enforces_complex_password_rules(): void
    {
        // Gagal jika tanpa huruf besar/angka/simbol
        $response = $this->postJson('/api/register', [
            'name' => 'Test User',
            'email' => 'newuser@example.com',
            'password' => 'weakpass',
            'password_confirmation' => 'weakpass',
        ]);
        $response->assertStatus(422)->assertJsonValidationErrors(['password']);

        // Berhasil dengan kombinasi huruf besar, kecil, angka, simbol minimal 8 char
        $validResponse = $this->postJson('/api/register', [
            'name' => 'Valid User',
            'email' => 'validuser@example.com',
            'password' => 'SecurePass123!',
            'password_confirmation' => 'SecurePass123!',
        ]);
        $validResponse->assertStatus(201);
    }

    private function seedOtp(string $email, string $otp, int $attempts = 0): void
    {
        $expiresAt = now()->addMinutes(5);

        Cache::put("pwd_reset:{$email}", [
            'otp_hash' => Hash::make($otp),
            'attempts' => $attempts,
            'expires_at' => $expiresAt->getTimestamp(),
        ], $expiresAt);
    }

    private function seedResetToken(string $email, string $plainToken): void
    {
        Cache::put(
            "pwd_reset_token:{$email}",
            hash('sha256', $plainToken),
            now()->addMinutes(15)
        );
    }
}
