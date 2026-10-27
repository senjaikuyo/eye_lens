<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('riwayat', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('judul');
            $table->longText('isi_teks'); // Tersimpan sebagai ciphertext AES-256-CBC
            $table->unsignedInteger('jumlah_kata')->default(0);
            $table->string('sumber')->default('kamera');
            $table->timestamp('waktu')->useCurrent();
            $table->timestamps();

            $table->index(['user_id', 'waktu']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('riwayat');
    }
};
