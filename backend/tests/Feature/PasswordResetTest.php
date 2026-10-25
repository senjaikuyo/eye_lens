<?php

namespace Tests\Feature;

use App\Mail\ResetPasswordOtpMail;
use App\Models\PasswordResetCode;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Tests\TestCase;

class PasswordResetTest extends TestCase
{
    use RefreshDatabase;

    public function test_send_reset_code_generates_otp_and_sends_email_for_existing_user(): void
    {
        Mail::fake();

        $user = User::factory()->create([
            'email' => 'user@example.com',
        ]);

        $response = $this->postJson('/api/forgot-password', [
            'email' => 'user@example.com',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'message' => 'Jika email terdaftar, kode verifikasi telah dikirim ke email Anda.',
            ]);

        $this->assertDatabaseHas('password_reset_codes', [
            'email' => 'user@example.com',
            'attempts' => 0,
        ]);

        Mail::assertSent(ResetPasswordOtpMail::class, function ($mail) {
            return $mail->hasTo('user@example.com') && strlen($mail->otp) === 6;
        });
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
            ]);

        $this->assertDatabaseMissing('password_reset_codes', [
            'email' => 'unknown@example.com',
        ]);

        Mail::assertNothingSent();
    }

    public function test_forgot_password_is_rate_limited(): void
    {
        Mail::fake();
        User::factory()->create(['email' => 'rate@example.com']);

        for ($i = 0; $i < 3; $i++) {
            $this->postJson('/api/forgot-password', ['email' => 'rate@example.com'])
                ->assertStatus(200);
        }

        // Request ke-4 harus terblokir 429
        $response = $this->postJson('/api/forgot-password', ['email' => 'rate@example.com']);
        $response->assertStatus(429);
    }

    public function test_verify_reset_code_fails_with_invalid_code_and_increments_attempts(): void
    {
        PasswordResetCode::create([
            'email' => 'verify@example.com',
            'otp_hash' => Hash::make('123456'),
            'attempts' => 0,
            'expires_at' => Carbon::now()->addMinutes(10),
        ]);

        $response = $this->postJson('/api/verify-reset-code', [
            'email' => 'verify@example.com',
            'code' => '654321',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['code']);

        $this->assertDatabaseHas('password_reset_codes', [
            'email' => 'verify@example.com',
            'attempts' => 1,
        ]);
    }

    public function test_verify_reset_code_deletes_record_after_max_attempts(): void
    {
        PasswordResetCode::create([
            'email' => 'max@example.com',
            'otp_hash' => Hash::make('123456'),
            'attempts' => 4,
            'expires_at' => Carbon::now()->addMinutes(10),
        ]);

        $response = $this->postJson('/api/verify-reset-code', [
            'email' => 'max@example.com',
            'code' => '000000',
        ]);

        $response->assertStatus(422);

        $this->assertDatabaseMissing('password_reset_codes', [
            'email' => 'max@example.com',
        ]);
    }

    public function test_verify_reset_code_succeeds_and_returns_reset_token(): void
    {
        PasswordResetCode::create([
            'email' => 'success@example.com',
            'otp_hash' => Hash::make('654321'),
            'attempts' => 0,
            'expires_at' => Carbon::now()->addMinutes(10),
        ]);

        $response = $this->postJson('/api/verify-reset-code', [
            'email' => 'success@example.com',
            'code' => '654321',
        ]);

        $response->assertStatus(200)
            ->assertJsonStructure(['message', 'reset_token']);

        $resetToken = $response->json('reset_token');
        $this->assertEquals(64, strlen($resetToken));

        $this->assertDatabaseHas('password_reset_codes', [
            'email' => 'success@example.com',
            'reset_token_hash' => hash('sha256', $resetToken),
        ]);
    }

    public function test_reset_password_rejects_weak_password_or_same_as_old_password(): void
    {
        $oldPassword = 'OldPassword123!';
        $user = User::factory()->create([
            'email' => 'reset@example.com',
            'password' => Hash::make($oldPassword),
        ]);

        $plainResetToken = 'valid-reset-token-sample-string-12345678901234567890123456789012';
        PasswordResetCode::create([
            'email' => 'reset@example.com',
            'otp_hash' => Hash::make('123456'),
            'reset_token_hash' => hash('sha256', $plainResetToken),
            'reset_token_expires_at' => Carbon::now()->addMinutes(15),
            'expires_at' => Carbon::now()->addMinutes(5),
        ]);

        // Coba password yang sama dengan password lama
        $responseSame = $this->postJson('/api/reset-password', [
            'email' => 'reset@example.com',
            'reset_token' => $plainResetToken,
            'password' => $oldPassword,
            'password_confirmation' => $oldPassword,
        ]);
        $responseSame->assertStatus(422)
            ->assertJsonValidationErrors(['password']);

        // Coba password lemah (tidak ada simbol / huruf besar)
        $responseWeak = $this->postJson('/api/reset-password', [
            'email' => 'reset@example.com',
            'reset_token' => $plainResetToken,
            'password' => 'simplepass123',
            'password_confirmation' => 'simplepass123',
        ]);
        $responseWeak->assertStatus(422)
            ->assertJsonValidationErrors(['password']);
    }

    public function test_reset_password_updates_password_and_revokes_tokens(): void
    {
        $user = User::factory()->create([
            'email' => 'complete@example.com',
            'password' => Hash::make('OldPassword123!'),
        ]);

        // Beri user token sanctum aktif
        $sanctumToken = $user->createToken('test_token');
        $this->assertCount(1, $user->tokens);

        $plainResetToken = 'plain-token-complete-test-123456789012345678901234567890123456';
        PasswordResetCode::create([
            'email' => 'complete@example.com',
            'otp_hash' => Hash::make('123456'),
            'reset_token_hash' => hash('sha256', $plainResetToken),
            'reset_token_expires_at' => Carbon::now()->addMinutes(15),
            'expires_at' => Carbon::now()->addMinutes(5),
        ]);

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

        // Token Sanctum harus terhapus
        $this->assertCount(0, $user->tokens);

        // Record password_reset_codes harus terhapus
        $this->assertDatabaseMissing('password_reset_codes', [
            'email' => 'complete@example.com',
        ]);
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
}
