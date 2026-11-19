<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Api\Concerns\ResolvesPengaturanConflict;
use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\Pengaturan;
use App\Models\Riwayat;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Throwable;

class SyncController extends Controller
{
    use ResolvesPengaturanConflict;

    /**
     * Menerima data lokal yang belum tersinkronisasi.
     *
     * Identitas pengguna selalu diambil dari token Sanctum ($request->user()),
     * bukan dari body request. Proses penyimpanan dibungkus transaksi MySQL
     * dan hanya mengembalikan status sukses setelah commit berhasil.
     *
     * Untuk pengaturan, aturan konfliknya adalah "terbaru menang" PER-FIELD:
     * hanya field dengan timestamp lebih baru yang menimpa nilai server.
     * Server selalu mengembalikan state pengaturan terkininya agar klien dapat
     * menarik perubahan yang dibuat perangkat lain.
     */
    public function sync(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'riwayat' => ['present', 'array', 'max:100'],
            'riwayat.*.client_uuid' => ['required', 'string', 'max:64'],
            'riwayat.*.judul' => ['required', 'string', 'max:255'],
            'riwayat.*.isi_teks' => ['required', 'string'],
            'riwayat.*.jumlah_kata' => ['required', 'integer', 'min:0'],
            'riwayat.*.sumber' => ['required', 'string', 'max:100'],
            'riwayat.*.waktu' => ['required', 'date'],
            'pengaturan' => ['sometimes', 'array'],
            'pengaturan.tema' => ['required_with:pengaturan', 'string', 'max:50'],
            'pengaturan.ukuran_teks' => ['required_with:pengaturan', 'integer', 'min:12', 'max:72'],
            'pengaturan.warna_kursor' => ['required_with:pengaturan', 'string', 'max:20'],
            'pengaturan.kontras' => ['required_with:pengaturan', 'string', 'max:20'],
            'pengaturan.otomatis_putar' => ['required_with:pengaturan', 'boolean'],
            'pengaturan.kecepatan_suara' => ['required_with:pengaturan', 'numeric', 'min:0.5', 'max:3'],
            'pengaturan.bahasa_suara' => ['required_with:pengaturan', 'string', 'max:20'],
            'pengaturan.bahasa_aplikasi' => ['required_with:pengaturan', 'string', 'max:20'],
            'pengaturan.terakhir_diperbarui' => ['required_with:pengaturan', 'date'],
            'pengaturan.field_timestamps' => ['sometimes', 'array'],
            'pengaturan.field_timestamps.*' => ['date'],
        ]);

        $user = $request->user();
        $syncedIds = [];
        $serverPengaturanPayload = null;

        try {
            DB::transaction(function () use ($validated, $user, &$syncedIds, &$serverPengaturanPayload) {
                foreach ($validated['riwayat'] as $item) {
                    // Kunci baris yang sudah ada agar dua request bersamaan
                    // tidak saling menimpa. Unique (user_id, client_uuid)
                    // menjadi pengaman akhir terhadap duplikasi.
                    $riwayat = Riwayat::query()
                        ->where('user_id', $user->id)
                        ->where('client_uuid', $item['client_uuid'])
                        ->lockForUpdate()
                        ->first();

                    if ($riwayat === null) {
                        $riwayat = new Riwayat;
                        $riwayat->user_id = $user->id;
                        $riwayat->client_uuid = $item['client_uuid'];
                    }

                    $riwayat->judul = $item['judul'];
                    $riwayat->isi_teks = $item['isi_teks'];
                    $riwayat->jumlah_kata = $item['jumlah_kata'];
                    $riwayat->sumber = $item['sumber'];
                    $riwayat->waktu = $item['waktu'];
                    $riwayat->save();

                    $syncedIds[] = $item['client_uuid'];
                }

                $serverPengaturan = Pengaturan::query()
                    ->where('user_id', $user->id)
                    ->lockForUpdate()
                    ->first();

                if (isset($validated['pengaturan'])) {
                    [$serverPengaturan] = $this->mergePengaturan(
                        $serverPengaturan,
                        $validated['pengaturan'],
                        $user->id,
                    );
                }

                if ($serverPengaturan !== null) {
                    $serverPengaturanPayload = $this->pengaturanPayload($serverPengaturan);
                }

                // Satu entri audit per batch; tidak menyimpan isi teks sensitif.
                AuditLog::create([
                    'user_id' => $user->id,
                    'aktor' => $user->name,
                    'aksi' => 'SYNC_RIWAYAT',
                    'objek' => 'RIWAYAT',
                    'ip' => request()->ip(),
                    'result' => 'SUCCESS',
                    'user_agent' => request()->userAgent(),
                    'keterangan' => 'Sinkronisasi '.count($syncedIds).' riwayat'
                        .(isset($validated['pengaturan']) ? ' dan pengaturan' : '').' via API',
                    'timestamp' => now(),
                ]);
            }, 3);
        } catch (Throwable $e) {
            report($e);

            return response()->json([
                'status' => 'error',
                'message' => 'Gagal menyimpan data sinkronisasi',
            ], 500);
        }

        return response()->json([
            'status' => 'success',
            'synced_riwayat' => $syncedIds,
            'pengaturan' => $serverPengaturanPayload,
        ], 200);
    }
}
