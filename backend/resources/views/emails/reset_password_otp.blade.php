<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Kode Verifikasi Reset Password</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background-color: #f4f6f8;
            margin: 0;
            padding: 24px;
            color: #1a1a1a;
        }
        .container {
            max-width: 520px;
            margin: 0 auto;
            background-color: #ffffff;
            border-radius: 8px;
            padding: 32px;
            border: 1px solid #e2e8f0;
        }
        .header {
            text-align: center;
            margin-bottom: 24px;
        }
        .otp-box {
            background-color: #0d1b2a;
            color: #ffffff;
            font-size: 32px;
            font-weight: bold;
            letter-spacing: 6px;
            text-align: center;
            padding: 16px;
            border-radius: 6px;
            margin: 24px 0;
        }
        .footer {
            font-size: 13px;
            color: #718096;
            margin-top: 24px;
            border-top: 1px solid #edf2f7;
            padding-top: 16px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h2>EyeLens</h2>
            <p>Permintaan Pengaturan Ulang Kata Sandi</p>
        </div>
        <p>Halo,</p>
        <p>Kami menerima permintaan untuk mengatur ulang kata sandi akun EyeLens Anda. Gunakan kode verifikasi 6 digit berikut:</p>
        <div class="otp-box">
            {{ $otp }}
        </div>
        <p>Kode ini berlaku selama <strong>10 menit</strong>. Jika Anda tidak merasa meminta pengaturan ulang kata sandi, abaikan email ini dan kata sandi Anda akan tetap aman.</p>
        <div class="footer">
            <p>&copy; {{ date('Y') }} EyeLens. Pesan ini dikirim secara otomatis, mohon tidak membalas email ini.</p>
        </div>
    </div>
</body>
</html>
