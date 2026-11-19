<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class MasukanControllerTest extends TestCase
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
        Schema::dropIfExists('masukan');
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

        Schema::create('masukan', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->text('pesan');
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

    public function test_feedback_requires_authentication(): void
    {
        $this->postJson('/api/masukan', ['pesan' => 'Saran'])
            ->assertStatus(401);

        $this->assertDatabaseCount('masukan', 0);
    }

    public function test_feedback_is_stored_for_authenticated_user(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $this->postJson('/api/masukan', ['pesan' => '  Tolong tambah mode gelap  '])
            ->assertStatus(201)
            ->assertJsonPath('status', 'success')
            ->assertJsonPath('masukan.pesan', 'Tolong tambah mode gelap');

        $this->assertDatabaseHas('masukan', [
            'user_id' => $user->id,
            'pesan' => 'Tolong tambah mode gelap',
        ]);

        $this->assertDatabaseHas('audit_log', [
            'user_id' => $user->id,
            'aksi' => 'KIRIM_MASUKAN',
            'result' => 'SUCCESS',
        ]);
    }

    public function test_user_id_from_payload_is_ignored(): void
    {
        $authenticated = User::factory()->create();
        $other = User::factory()->create();
        Sanctum::actingAs($authenticated);

        $this->postJson('/api/masukan', [
            'pesan' => 'Saran',
            'user_id' => $other->id,
        ])->assertStatus(201);

        $this->assertDatabaseHas('masukan', [
            'user_id' => $authenticated->id,
        ]);
        $this->assertDatabaseMissing('masukan', [
            'user_id' => $other->id,
        ]);
    }

    public function test_empty_or_whitespace_feedback_is_rejected(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $this->postJson('/api/masukan', ['pesan' => '   '])
            ->assertStatus(422)
            ->assertJsonValidationErrors('pesan');

        $this->assertDatabaseCount('masukan', 0);
    }

    public function test_feedback_longer_than_limit_is_rejected(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $this->postJson('/api/masukan', [
            'pesan' => str_repeat('a', 5001),
        ])
            ->assertStatus(422)
            ->assertJsonValidationErrors('pesan');

        $this->assertDatabaseCount('masukan', 0);
    }
}
