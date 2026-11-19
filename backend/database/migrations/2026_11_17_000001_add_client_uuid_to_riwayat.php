<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

return new class extends Migration
{
    /**
     * Idempotency kunci sinkronisasi: client_uuid unik per pengguna.
     */
    public function up(): void
    {
        Schema::table('riwayat', function (Blueprint $table) {
            $table->string('client_uuid')->nullable()->after('user_id');
        });

        // Backfill data lama tanpa SQL spesifik MySQL agar migration tetap
        // dapat dijalankan pada SQLite saat pengujian.
        DB::table('riwayat')->orderBy('id')->each(function ($row) {
            DB::table('riwayat')
                ->where('id', $row->id)
                ->update(['client_uuid' => (string) Str::uuid()]);
        });

        Schema::table('riwayat', function (Blueprint $table) {
            $table->string('client_uuid')->nullable(false)->change();
            $table->unique(['user_id', 'client_uuid'], 'riwayat_user_client_uuid_unique');
        });
    }

    public function down(): void
    {
        Schema::table('riwayat', function (Blueprint $table) {
            $table->dropUnique('riwayat_user_client_uuid_unique');
            $table->dropColumn('client_uuid');
        });
    }
};
