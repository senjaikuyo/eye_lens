<?php

namespace App\Http\Controllers\Api\Concerns;

use App\Models\Pengaturan;
use Illuminate\Support\Carbon;

/**
 * Menyelesaikan konflik pengaturan dengan aturan "terbaru menang" PER-FIELD.
 *
 * Setiap field memiliki timestamp sendiri di kolom `field_timestamps`. Baris
 * lama yang belum memiliki peta tersebut memakai `terakhir_diperbarui` sebagai
 * timestamp seluruh field, sehingga tetap kompatibel.
 */
trait ResolvesPengaturanConflict
{
    /**
     * @var array<int, string>
     */
    protected array $pengaturanFields = [
        'tema',
        'ukuran_teks',
        'warna_kursor',
        'kontras',
        'otomatis_putar',
        'kecepatan_suara',
        'bahasa_suara',
        'bahasa_aplikasi',
    ];

    /**
     * @param  array<string, mixed>  $incoming
     * @return array{0: Pengaturan, 1: bool}
     */
    protected function mergePengaturan(?Pengaturan $server, array $incoming, int $userId): array
    {
        $rowTime = Carbon::parse($incoming['terakhir_diperbarui'])->utc();
        $incomingTimes = $this->normalizeFieldTimestamps(
            $incoming['field_timestamps'] ?? [],
            $rowTime,
        );

        if ($server === null) {
            $attributes = ['user_id' => $userId];
            foreach ($this->pengaturanFields as $field) {
                $attributes[$field] = $incoming[$field];
            }
            $attributes['terakhir_diperbarui'] = $this->maxTime($incomingTimes);
            $attributes['field_timestamps'] = $this->serializeTimestamps($incomingTimes);

            return [Pengaturan::query()->create($attributes), true];
        }

        $serverRowTime = $server->terakhir_diperbarui
            ? Carbon::parse($server->terakhir_diperbarui)->utc()
            : $rowTime->copy();
        $serverTimes = $this->normalizeFieldTimestamps(
            $server->field_timestamps ?? [],
            $serverRowTime,
        );

        $applied = false;
        foreach ($this->pengaturanFields as $field) {
            $incomingTime = $incomingTimes[$field];
            $serverTime = $serverTimes[$field];

            // Hanya field yang timestamp-nya lebih baru yang boleh menimpa.
            if ($incomingTime->greaterThan($serverTime)) {
                $server->{$field} = $incoming[$field];
                $serverTimes[$field] = $incomingTime;
                $applied = true;
            }
        }

        if ($applied) {
            $server->field_timestamps = $this->serializeTimestamps($serverTimes);
            $server->terakhir_diperbarui = $this->maxTime($serverTimes);
            $server->save();
        }

        return [$server, $applied];
    }

    /**
     * @return array<string, mixed>
     */
    protected function pengaturanPayload(Pengaturan $pengaturan): array
    {
        $rowTime = $pengaturan->terakhir_diperbarui
            ? Carbon::parse($pengaturan->terakhir_diperbarui)->utc()
            : Carbon::now()->utc();
        $times = $this->normalizeFieldTimestamps(
            $pengaturan->field_timestamps ?? [],
            $rowTime,
        );

        $payload = [];
        foreach ($this->pengaturanFields as $field) {
            $payload[$field] = $this->normalizeValue($field, $pengaturan->{$field});
        }
        $payload['terakhir_diperbarui'] = $this->maxTime($times)->toIso8601String();
        $payload['field_timestamps'] = $this->serializeTimestamps($times);

        return $payload;
    }

    /**
     * @param  array<string, mixed>  $input
     * @return array<string, Carbon>
     */
    private function normalizeFieldTimestamps(array $input, Carbon $fallback): array
    {
        $result = [];
        foreach ($this->pengaturanFields as $field) {
            $value = $input[$field] ?? null;
            $parsed = is_string($value) ? Carbon::parse($value)->utc() : null;
            $result[$field] = $parsed ?? $fallback->copy();
        }

        return $result;
    }

    /**
     * @param  array<string, Carbon>  $times
     * @return array<string, string>
     */
    private function serializeTimestamps(array $times): array
    {
        $result = [];
        foreach ($times as $field => $time) {
            $result[$field] = $time->toIso8601String();
        }

        return $result;
    }

    /**
     * @param  array<string, Carbon>  $times
     */
    private function maxTime(array $times): Carbon
    {
        $max = null;
        foreach ($times as $time) {
            if ($max === null || $time->greaterThan($max)) {
                $max = $time;
            }
        }

        return $max ?? Carbon::now()->utc();
    }

    private function normalizeValue(string $field, mixed $value): mixed
    {
        return match ($field) {
            'otomatis_putar' => (bool) $value,
            'kecepatan_suara' => (float) $value,
            'ukuran_teks' => (int) $value,
            default => $value,
        };
    }
}
