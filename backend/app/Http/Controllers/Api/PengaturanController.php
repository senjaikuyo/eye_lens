<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Api\Concerns\ResolvesPengaturanConflict;
use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\Pengaturan;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Throwable;

class PengaturanController extends Controller
{
    use ResolvesPengaturanConflict;

    /**
     * Menyimpan pengaturan pengguna yang terautentikasi.
     *
     * Konflik diselesaikan PER-FIELD: hanya field dengan timestamp lebih baru
     * yang menimpa nilai server. Identitas pengguna selalu dari token.
     */
    public function update(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'tema' => ['required', 'string', 'max:50'],
            'ukuran_teks' => ['required', 'integer', 'min:12', 'max:72'],
            'warna_kursor' => ['required', 'string', 'max:20'],
            'kontras' => ['required', 'string', 'max:20'],
            'otomatis_putar' => ['required', 'boolean'],
            'kecepatan_suara' => ['required', 'numeric', 'min:0.5', 'max:3'],
            'bahasa_suara' => ['required', 'string', 'max:20'],
            'bahasa_aplikasi' => ['required', 'string', 'max:20'],
            'terakhir_diperbarui' => ['required', 'date'],
            'field_timestamps' => ['sometimes', 'array'],
            'field_timestamps.*' => ['date'],
        ]);

        $user = $request->user();
        $applied = false;

        try {
            $pengaturan = DB::transaction(function () use ($validated, $user, &$applied) {
                $server = Pengaturan::query()
                    ->where('user_id', $user->id)
                    ->lockForUpdate()
                    ->first();

                [$pengaturan, $applied] = $this->mergePengaturan(
                    $server,
                    $validated,
                    $user->id,
                );

                AuditLog::create([
                    'user_id' => $user->id,
                    'aktor' => $user->name,
                    'aksi' => 'UPDATE_PENGATURAN',
                    'objek' => 'PENGATURAN',
                    'ip' => request()->ip(),
                    'result' => 'SUCCESS',
                    'user_agent' => request()->userAgent(),
                    'keterangan' => $applied
                        ? 'Pengaturan diperbarui via API (per-field)'
                        : 'Tidak ada field yang lebih baru dari server',
                    'timestamp' => now(),
                ]);

                return $pengaturan;
            }, 3);
        } catch (Throwable $e) {
            report($e);

            return response()->json([
                'status' => 'error',
                'message' => 'Gagal menyimpan pengaturan',
            ], 500);
        }

        return response()->json([
            'status' => 'success',
            'pengaturan' => $this->pengaturanPayload($pengaturan),
        ], 200);
    }
}
