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
        Schema::create('pengaturans', function (Blueprint $table) {
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
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('pengaturans');
    }
};
