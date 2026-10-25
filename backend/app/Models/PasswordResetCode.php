<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class PasswordResetCode extends Model
{
    use HasFactory;

    protected $table = 'password_reset_codes';

    protected $fillable = [
        'email',
        'otp_hash',
        'reset_token_hash',
        'attempts',
        'expires_at',
        'reset_token_expires_at',
    ];

    protected $casts = [
        'attempts' => 'integer',
        'expires_at' => 'datetime',
        'reset_token_expires_at' => 'datetime',
    ];
}
