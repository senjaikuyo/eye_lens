<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Menyimpan timestamp per field agar konflik pengaturan diselesaikan
     * per-field (newest-wins), bukan menimpa seluruh baris.
     */
    public function up(): void
    {
        Schema::table('pengaturan', function (Blueprint $table) {
            $table->json('field_timestamps')->nullable()->after('terakhir_diperbarui');
        });
    }

    public function down(): void
    {
        Schema::table('pengaturan', function (Blueprint $table) {
            $table->dropColumn('field_timestamps');
        });
    }
};
