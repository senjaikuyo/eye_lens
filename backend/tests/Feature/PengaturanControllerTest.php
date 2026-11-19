<?php

namespace Tests\Feature;

use App\Models\Pengaturan;
use App\Models\User;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PengaturanControllerTest extends TestCase
{
    /**
     * Skema dibuat manual di SQLite in-memory agar tidak bergantung pada
     * migration lama `v_public_users` yang memakai CREATE OR REPLACE VIEW
     * (tidak didukung SQLite).
     */
    protected function setUp(): void
    {
        parent::setUp();

        Schema::dropIfExists('audit_log');
        Schema::dropIfExists('pengaturan');
        Schema::dropIfExists('users');

        Schema::create('users', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('email')->unique();
            $table->string('password');
            $table->timestamp('email_verified_at')->nullable();
            $table->rememberToken();
            $table->string('role')->default('user');
            $table->timestamps();
        });

        Schema::create('pengaturan', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->unique()->constrained('users')->cascadeOnDelete();
            $table->string('tema')->default('sistem');
            $table->unsignedInteger('ukuran_teks')->default(18);
            $table->string('warna_kursor')->default('#FACC15');
            $table->string('kontras')->default('normal');
            $table->boolean('otomatis_putar')->default(true);
            $table->float('kecepatan_suara')->default(1.0);
            $table->string('bahasa_suara')->default('id-ID');
            $table->string('bahasa_aplikasi')->default('id');
            $table->timestamp('terakhir_diperbarui')->useCurrent();
            $table->json('field_timestamps')->nullable();
            $table->timestamps();
        });

        Schema::create('audit_log', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->nullable();
            $table->string('aktor')->nullable();
            $table->string('aksi', 50);
            $table->string('objek', 100);
            $table->string('ip', 45)->nullable();
            $table->string('result', 20)->default('SUCCESS');
            $table->text('user_agent')->nullable();
            $table->text('keterangan')->nullable();
            $table->timestamp('timestamp')->useCurrent();
        });
    }

    private function fieldTimestamps(string $default, array $overrides = []): array
    {
        $fields = [
            'tema', 'ukuran_teks', 'warna_kursor', 'kontras',
            'otomatis_putar', 'kecepatan_suara', 'bahasa_suara', 'bahasa_aplikasi',
        ];

        return array_merge(array_fill_keys($fields, $default), $overrides);
    }

    private function payload(array $overrides = []): array
    {
        return array_merge([
            'tema' => 'dark',
            'ukuran_teks' => 24,
            'warna_kursor' => '#1678BA',
            'kontras' => 'tinggi',
            'otomatis_putar' => false,
            'kecepatan_suara' => 1.5,
            'bahasa_suara' => 'en-US',
            'bahasa_aplikasi' => 'en',
            'terakhir_diperbarui' => '2026-11-17T12:00:00.000000Z',
        ], $overrides);
    }

    public function test_update_requires_authentication(): void
    {
        $this->putJson('/api/pengaturan', $this->payload())
            ->assertStatus(401);

        $this->assertDatabaseCount('pengaturan', 0);
        $this->assertDatabaseCount('audit_log', 0);
    }

    public function test_settings_are_created_for_authenticated_user(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $this->putJson('/api/pengaturan', $this->payload())
            ->assertOk()
            ->assertJsonPath('status', 'success')
            ->assertJsonPath('pengaturan.tema', 'dark')
            ->assertJsonPath('pengaturan.ukuran_teks', 24)
            ->assertJsonPath('pengaturan.otomatis_putar', false);

        $this->assertDatabaseHas('pengaturan', [
            'user_id' => $user->id,
            'tema' => 'dark',
            'ukuran_teks' => 24,
        ]);

        $this->assertDatabaseHas('audit_log', [
            'user_id' => $user->id,
            'aksi' => 'UPDATE_PENGATURAN',
            'result' => 'SUCCESS',
        ]);
    }

    public function test_newer_incoming_settings_are_stored(): void
    {
        $user = User::factory()->create();
        Pengaturan::create([
            'user_id' => $user->id,
            'tema' => 'light',
            'ukuran_teks' => 18,
            'warna_kursor' => '#FACC15',
            'kontras' => 'normal',
            'otomatis_putar' => true,
            'kecepatan_suara' => 1.0,
            'bahasa_suara' => 'id-ID',
            'bahasa_aplikasi' => 'id',
            'terakhir_diperbarui' => '2026-11-17T10:00:00.000000Z',
        ]);
        Sanctum::actingAs($user);

        $this->putJson('/api/pengaturan', $this->payload([
            'terakhir_diperbarui' => '2026-11-17T11:00:00.000000Z',
        ]))
            ->assertOk()
            ->assertJsonPath('pengaturan.tema', 'dark');

        $this->assertDatabaseHas('pengaturan', [
            'user_id' => $user->id,
            'tema' => 'dark',
            'ukuran_teks' => 24,
        ]);
    }

    public function test_older_incoming_settings_do_not_overwrite_server(): void
    {
        $user = User::factory()->create();
        Pengaturan::create([
            'user_id' => $user->id,
            'tema' => 'server-baru',
            'ukuran_teks' => 30,
            'warna_kursor' => '#FFFFFF',
            'kontras' => 'tinggi',
            'otomatis_putar' => true,
            'kecepatan_suara' => 1.0,
            'bahasa_suara' => 'id-ID',
            'bahasa_aplikasi' => 'id',
            'terakhir_diperbarui' => '2026-11-17T12:00:00.000000Z',
        ]);
        Sanctum::actingAs($user);

        $this->putJson('/api/pengaturan', $this->payload([
            'tema' => 'lokal-lama',
            'ukuran_teks' => 18,
            'terakhir_diperbarui' => '2026-11-17T11:00:00.000000Z',
        ]))
            ->assertOk()
            ->assertJsonPath('pengaturan.tema', 'server-baru')
            ->assertJsonPath('pengaturan.ukuran_teks', 30);

        $this->assertDatabaseHas('pengaturan', [
            'user_id' => $user->id,
            'tema' => 'server-baru',
            'ukuran_teks' => 30,
        ]);
        $this->assertDatabaseMissing('pengaturan', [
            'user_id' => $user->id,
            'tema' => 'lokal-lama',
        ]);
    }

    public function test_user_id_from_payload_is_ignored(): void
    {
        $authenticated = User::factory()->create();
        $other = User::factory()->create();
        Sanctum::actingAs($authenticated);

        $payload = $this->payload();
        $payload['user_id'] = $other->id;

        $this->putJson('/api/pengaturan', $payload)->assertOk();

        $this->assertDatabaseHas('pengaturan', [
            'user_id' => $authenticated->id,
        ]);
        $this->assertDatabaseMissing('pengaturan', [
            'user_id' => $other->id,
        ]);
    }

    public function test_settings_of_other_users_are_not_modified(): void
    {
        $userA = User::factory()->create();
        $userB = User::factory()->create();
        Pengaturan::create([
            'user_id' => $userB->id,
            'tema' => 'milik-b',
            'ukuran_teks' => 20,
            'warna_kursor' => '#FACC15',
            'kontras' => 'normal',
            'otomatis_putar' => true,
            'kecepatan_suara' => 1.0,
            'bahasa_suara' => 'id-ID',
            'bahasa_aplikasi' => 'id',
            'terakhir_diperbarui' => '2026-11-17T12:00:00.000000Z',
        ]);
        Sanctum::actingAs($userA);

        $this->putJson('/api/pengaturan', $this->payload())->assertOk();

        $this->assertDatabaseHas('pengaturan', [
            'user_id' => $userA->id,
            'tema' => 'dark',
        ]);
        $this->assertDatabaseHas('pengaturan', [
            'user_id' => $userB->id,
            'tema' => 'milik-b',
        ]);
    }

    public function test_newer_field_updates_only_that_field(): void
    {
        $user = User::factory()->create();
        Pengaturan::create([
            'user_id' => $user->id,
            'tema' => 'server-tema',
            'ukuran_teks' => 30,
            'warna_kursor' => '#FFFFFF',
            'kontras' => 'normal',
            'otomatis_putar' => true,
            'kecepatan_suara' => 1.0,
            'bahasa_suara' => 'id-ID',
            'bahasa_aplikasi' => 'id',
            'terakhir_diperbarui' => '2026-11-17T12:00:00.000000Z',
            'field_timestamps' => $this->fieldTimestamps('2026-11-17T12:00:00.000000Z', [
                'ukuran_teks' => '2026-11-17T09:00:00.000000Z',
            ]),
        ]);
        Sanctum::actingAs($user);

        $this->putJson('/api/pengaturan', $this->payload([
            'tema' => 'lokal-tema-baru',
            'ukuran_teks' => 14,
            'terakhir_diperbarui' => '2026-11-17T13:00:00.000000Z',
            'field_timestamps' => $this->fieldTimestamps('2026-11-17T07:00:00.000000Z', [
                'tema' => '2026-11-17T13:00:00.000000Z',
                'ukuran_teks' => '2026-11-17T08:00:00.000000Z',
            ]),
        ]))
            ->assertOk()
            ->assertJsonPath('pengaturan.tema', 'lokal-tema-baru')
            ->assertJsonPath('pengaturan.ukuran_teks', 30);

        $this->assertDatabaseHas('pengaturan', [
            'user_id' => $user->id,
            'tema' => 'lokal-tema-baru',
            'ukuran_teks' => 30,
        ]);
    }

    public function test_equal_field_timestamp_keeps_server_value(): void
    {
        $user = User::factory()->create();
        Pengaturan::create([
            'user_id' => $user->id,
            'tema' => 'server-tema',
            'ukuran_teks' => 20,
            'warna_kursor' => '#FFFFFF',
            'kontras' => 'normal',
            'otomatis_putar' => true,
            'kecepatan_suara' => 1.0,
            'bahasa_suara' => 'id-ID',
            'bahasa_aplikasi' => 'id',
            'terakhir_diperbarui' => '2026-11-17T12:00:00.000000Z',
            'field_timestamps' => $this->fieldTimestamps('2026-11-17T12:00:00.000000Z'),
        ]);
        Sanctum::actingAs($user);

        $this->putJson('/api/pengaturan', $this->payload([
            'tema' => 'lokal-tema',
            'terakhir_diperbarui' => '2026-11-17T12:00:00.000000Z',
            'field_timestamps' => $this->fieldTimestamps('2026-11-17T12:00:00.000000Z'),
        ]))
            ->assertOk()
            ->assertJsonPath('pengaturan.tema', 'server-tema');

        $this->assertDatabaseHas('pengaturan', [
            'user_id' => $user->id,
            'tema' => 'server-tema',
        ]);
    }

    public function test_invalid_settings_are_rejected_without_writing_data(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $this->putJson('/api/pengaturan', $this->payload([
            'ukuran_teks' => 'besar',
            'terakhir_diperbarui' => 'bukan-tanggal',
        ]))
            ->assertStatus(422)
            ->assertJsonValidationErrors(['ukuran_teks', 'terakhir_diperbarui']);

        $this->assertDatabaseCount('pengaturan', 0);
        $this->assertDatabaseCount('audit_log', 0);
    }
}
