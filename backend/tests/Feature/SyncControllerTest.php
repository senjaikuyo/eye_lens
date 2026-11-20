<?php

namespace Tests\Feature;

use App\Models\Pengaturan;
use App\Models\User;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SyncControllerTest extends TestCase
{
    /**
     * Skema dibuat manual di SQLite in-memory agar test ini tidak bergantung
     * pada migration lama `v_public_users` yang memakai CREATE OR REPLACE VIEW
     * (tidak didukung SQLite). Tidak ada file atau data proyek yang diubah.
     */
    protected function setUp(): void
    {
        parent::setUp();

        Schema::dropIfExists('audit_log');
        Schema::dropIfExists('pengaturan');
        Schema::dropIfExists('riwayat');
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

        Schema::create('riwayat', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id');
            $table->string('client_uuid');
            $table->string('judul');
            $table->longText('isi_teks');
            $table->unsignedInteger('jumlah_kata')->default(0);
            $table->string('sumber')->default('kamera');
            $table->timestamp('waktu')->useCurrent();
            $table->timestamps();
            $table->unique(['user_id', 'client_uuid']);
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

    private function payload(string $clientUuid, string $judul = 'Hasil Scan'): array
    {
        return [
            'riwayat' => [
                [
                    'client_uuid' => $clientUuid,
                    'judul' => $judul,
                    'isi_teks' => 'Teks hasil pemindaian',
                    'jumlah_kata' => 4,
                    'sumber' => 'kamera',
                    'waktu' => '2026-11-17T10:00:00',
                ],
            ],
        ];
    }

    private function pengaturanPayload(array $overrides = []): array
    {
        return array_merge([
            'tema' => 'sistem',
            'ukuran_teks' => 18,
            'warna_kursor' => '#FACC15',
            'kontras' => 'normal',
            'otomatis_putar' => true,
            'kecepatan_suara' => 1.0,
            'bahasa_suara' => 'id-ID',
            'bahasa_aplikasi' => 'id',
            'terakhir_diperbarui' => '2026-11-17T10:00:00.000000Z',
        ], $overrides);
    }

    public function test_sync_requires_authentication(): void
    {
        $this->postJson('/api/sync', $this->payload('uuid-401'))
            ->assertStatus(401);

        $this->assertDatabaseCount('riwayat', 0);
    }

    public function test_sync_stores_data_and_returns_acknowledged_uuid(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $this->postJson('/api/sync', $this->payload('uuid-sukses'))
            ->assertOk()
            ->assertJson([
                'status' => 'success',
                'synced_riwayat' => ['uuid-sukses'],
            ]);

        $this->assertDatabaseHas('riwayat', [
            'user_id' => $user->id,
            'client_uuid' => 'uuid-sukses',
            'judul' => 'Hasil Scan',
        ]);

        $this->assertDatabaseHas('audit_log', [
            'user_id' => $user->id,
            'aksi' => 'SYNC_RIWAYAT',
            'result' => 'SUCCESS',
        ]);
    }

    public function test_resending_same_uuid_does_not_duplicate_data(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $this->postJson('/api/sync', $this->payload('uuid-idempoten', 'Judul Awal'))
            ->assertOk();
        $this->postJson('/api/sync', $this->payload('uuid-idempoten', 'Judul Diperbarui'))
            ->assertOk();

        $this->assertDatabaseCount('riwayat', 1);
        $this->assertDatabaseHas('riwayat', [
            'user_id' => $user->id,
            'client_uuid' => 'uuid-idempoten',
            'judul' => 'Judul Diperbarui',
        ]);
    }

    public function test_same_uuid_from_different_users_is_kept_separate(): void
    {
        $userA = User::factory()->create();
        $userB = User::factory()->create();

        Sanctum::actingAs($userA);
        $this->postJson('/api/sync', $this->payload('uuid-bersama', 'Milik A'))->assertOk();

        Sanctum::actingAs($userB);
        $this->postJson('/api/sync', $this->payload('uuid-bersama', 'Milik B'))->assertOk();

        $this->assertDatabaseCount('riwayat', 2);
        $this->assertDatabaseHas('riwayat', [
            'user_id' => $userA->id,
            'client_uuid' => 'uuid-bersama',
            'judul' => 'Milik A',
        ]);
        $this->assertDatabaseHas('riwayat', [
            'user_id' => $userB->id,
            'client_uuid' => 'uuid-bersama',
            'judul' => 'Milik B',
        ]);
    }

    public function test_invalid_payload_is_rejected_without_writing_data(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $payload = $this->payload('uuid-invalid');
        unset($payload['riwayat'][0]['isi_teks']);

        $this->postJson('/api/sync', $payload)
            ->assertStatus(422)
            ->assertJsonValidationErrors('riwayat.0.isi_teks');

        $this->assertDatabaseCount('riwayat', 0);
        $this->assertDatabaseCount('audit_log', 0);
    }

    public function test_user_id_from_payload_is_ignored(): void
    {
        $authenticatedUser = User::factory()->create();
        $otherUser = User::factory()->create();
        Sanctum::actingAs($authenticatedUser);

        $payload = $this->payload('uuid-spoof');
        $payload['user_id'] = $otherUser->id;
        $payload['riwayat'][0]['user_id'] = $otherUser->id;

        $this->postJson('/api/sync', $payload)->assertOk();

        $this->assertDatabaseHas('riwayat', [
            'client_uuid' => 'uuid-spoof',
            'user_id' => $authenticatedUser->id,
        ]);
        $this->assertDatabaseMissing('riwayat', [
            'client_uuid' => 'uuid-spoof',
            'user_id' => $otherUser->id,
        ]);
    }

    public function test_newer_local_pengaturan_is_stored(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $payload = $this->payload('uuid-pengaturan-baru');
        $payload['pengaturan'] = $this->pengaturanPayload([
            'tema' => 'dark',
            'ukuran_teks' => 24,
            'terakhir_diperbarui' => '2026-11-17T12:00:00.000000Z',
        ]);

        $this->postJson('/api/sync', $payload)
            ->assertOk()
            ->assertJsonPath('pengaturan.tema', 'dark')
            ->assertJsonPath('pengaturan.ukuran_teks', 24);

        $this->assertDatabaseHas('pengaturan', [
            'user_id' => $user->id,
            'tema' => 'dark',
            'ukuran_teks' => 24,
        ]);
    }

    public function test_older_local_pengaturan_does_not_overwrite_newer_server_value(): void
    {
        $user = User::factory()->create();
        Pengaturan::create([
            'user_id' => $user->id,
            'tema' => 'terang-server',
            'ukuran_teks' => 20,
            'warna_kursor' => '#FFFFFF',
            'kontras' => 'normal',
            'otomatis_putar' => true,
            'kecepatan_suara' => 1.0,
            'bahasa_suara' => 'id-ID',
            'bahasa_aplikasi' => 'id',
            'terakhir_diperbarui' => '2026-11-17T12:00:00.000000Z',
        ]);
        Sanctum::actingAs($user);

        $payload = $this->payload('uuid-pengaturan-lama');
        $payload['pengaturan'] = $this->pengaturanPayload([
            'tema' => 'gelap-lokal',
            'terakhir_diperbarui' => '2026-11-17T11:00:00.000000Z',
        ]);

        $this->postJson('/api/sync', $payload)
            ->assertOk()
            ->assertJsonPath('pengaturan.tema', 'terang-server');

        $this->assertDatabaseHas('pengaturan', [
            'user_id' => $user->id,
            'tema' => 'terang-server',
        ]);
        $this->assertDatabaseMissing('pengaturan', [
            'user_id' => $user->id,
            'tema' => 'gelap-lokal',
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

        $payload = $this->payload('uuid-per-field');
        $payload['pengaturan'] = $this->pengaturanPayload([
            'tema' => 'lokal-tema-baru',
            'ukuran_teks' => 14,
            'terakhir_diperbarui' => '2026-11-17T13:00:00.000000Z',
            'field_timestamps' => $this->fieldTimestamps('2026-11-17T07:00:00.000000Z', [
                'tema' => '2026-11-17T13:00:00.000000Z',
                'ukuran_teks' => '2026-11-17T08:00:00.000000Z',
            ]),
        ]);

        $this->postJson('/api/sync', $payload)
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

        $payload = $this->payload('uuid-timestamp-sama');
        $payload['pengaturan'] = $this->pengaturanPayload([
            'tema' => 'lokal-tema',
            'terakhir_diperbarui' => '2026-11-17T12:00:00.000000Z',
            'field_timestamps' => $this->fieldTimestamps('2026-11-17T12:00:00.000000Z'),
        ]);

        $this->postJson('/api/sync', $payload)
            ->assertOk()
            ->assertJsonPath('pengaturan.tema', 'server-tema');

        $this->assertDatabaseHas('pengaturan', [
            'user_id' => $user->id,
            'tema' => 'server-tema',
        ]);
    }

    public function test_invalid_field_timestamps_are_rejected(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $payload = $this->payload('uuid-field-timestamp-invalid');
        $payload['pengaturan'] = $this->pengaturanPayload([
            'field_timestamps' => ['tema' => 'bukan-tanggal'],
        ]);

        $this->postJson('/api/sync', $payload)
            ->assertStatus(422)
            ->assertJsonValidationErrors('pengaturan.field_timestamps.tema');

        $this->assertDatabaseCount('riwayat', 0);
        $this->assertDatabaseCount('pengaturan', 0);
    }

    public function test_invalid_pengaturan_is_rejected_without_writing_data(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $payload = $this->payload('uuid-pengaturan-invalid');
        $payload['pengaturan'] = $this->pengaturanPayload([
            'ukuran_teks' => 'besar',
        ]);

        $this->postJson('/api/sync', $payload)
            ->assertStatus(422)
            ->assertJsonValidationErrors('pengaturan.ukuran_teks');

        $this->assertDatabaseCount('riwayat', 0);
        $this->assertDatabaseCount('pengaturan', 0);
        $this->assertDatabaseCount('audit_log', 0);
    }
}
