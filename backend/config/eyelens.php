<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Password Reset / OTP
    |--------------------------------------------------------------------------
    |
    | Pengaturan keamanan untuk alur lupa password berbasis OTP email.
    | Nilai default mengikuti kebutuhan produk: OTP 6 digit, berlaku 5 menit,
    | dan dapat dikirim ulang setelah 60 detik.
    |
    */

    'otp' => [
        'expiry_minutes' => (int) env('OTP_EXPIRY_MINUTES', 5),
        'resend_cooldown_seconds' => (int) env('OTP_RESEND_COOLDOWN_SECONDS', 60),
        'max_attempts' => (int) env('OTP_MAX_ATTEMPTS', 5),
        'reset_token_ttl_minutes' => (int) env('OTP_RESET_TOKEN_TTL_MINUTES', 15),
    ],

];
