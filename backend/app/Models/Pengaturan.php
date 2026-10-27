<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Pengaturan extends Model
{
    use HasFactory;

    protected $table = 'pengaturans';

    protected $fillable = [
        'user_id',
        'tema',
        'ukuran_teks',
        'warna_kursor',
        'kontras',
        'otomatis_putar',
        'kecepatan_suara',
        'bahasa_suara',
        'bahasa_aplikasi',
        'terakhir_diperbarui',
    ];

    protected function casts(): array
    {
        return [
            'ukuran_teks' => 'integer',
            'otomatis_putar' => 'boolean',
            'kecepatan_suara' => 'float',
            'terakhir_diperbarui' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
