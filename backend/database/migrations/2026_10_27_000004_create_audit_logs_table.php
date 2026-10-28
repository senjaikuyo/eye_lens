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
        Schema::create('audit_log', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->nullable()->constrained('users')->nullOnDelete();
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

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('audit_log');
    }
};
