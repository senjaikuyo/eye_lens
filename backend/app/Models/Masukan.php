<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Masukan extends Model
{
    use HasFactory;

    protected $table = 'masukan';

    protected $fillable = [
        'user_id',
        'pesan',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
