<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\Masukan;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use Throwable;

class MasukanController extends Controller
{
    /**
     * Menyimpan masukan/feedback pengguna yang terautentikasi.
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'pesan' => ['required', 'string', 'max:5000'],
        ]);

        $pesan = trim($validated['pesan']);
        if ($pesan === '') {
            throw ValidationException::withMessages([
                'pesan' => 'Pesan masukan tidak boleh kosong.',
            ]);
        }

        $user = $request->user();

        try {
            $masukan = DB::transaction(function () use ($user, $pesan) {
                $masukan = Masukan::query()->create([
                    'user_id' => $user->id,
                    'pesan' => $pesan,
                ]);

                AuditLog::create([
                    'user_id' => $user->id,
                    'aktor' => $user->name,
                    'aksi' => 'KIRIM_MASUKAN',
                    'objek' => 'MASUKAN',
                    'ip' => request()->ip(),
                    'result' => 'SUCCESS',
                    'user_agent' => request()->userAgent(),
                    'keterangan' => 'Masukan dikirim via API',
                    'timestamp' => now(),
                ]);

                return $masukan;
            }, 3);
        } catch (Throwable $e) {
            report($e);

            return response()->json([
                'status' => 'error',
                'message' => 'Gagal menyimpan masukan',
            ], 500);
        }

        return response()->json([
            'status' => 'success',
            'message' => 'Masukan berhasil dikirim',
            'masukan' => [
                'id' => $masukan->id,
                'pesan' => $masukan->pesan,
                'created_at' => $masukan->created_at?->toIso8601String(),
            ],
        ], 201);
    }
}
