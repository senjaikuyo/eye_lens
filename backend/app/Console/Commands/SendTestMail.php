<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\Mail;

class SendTestMail extends Command
{
    protected $signature = 'mail:test {email : Alamat email tujuan}';

    protected $description = 'Kirim email uji untuk memverifikasi konfigurasi SMTP';

    public function handle(): int
    {
        $email = (string) $this->argument('email');
        $username = (string) config('mail.mailers.smtp.username');

        $this->line('Mailer   : '.config('mail.default'));
        $this->line('Host     : '.config('mail.mailers.smtp.host').':'.config('mail.mailers.smtp.port'));
        $this->line('Username : '.($username !== '' ? $username : '(kosong)'));
        $this->line('From     : '.(config('mail.from.address') ?: '(kosong)'));
        $this->newLine();

        try {
            Mail::raw(
                'Tes konfigurasi SMTP EyeLens berhasil. Jika email ini diterima, pengiriman OTP lupa password juga akan berfungsi.',
                function ($message) use ($email): void {
                    $message->to($email)->subject('Tes SMTP EyeLens');
                }
            );
        } catch (\Throwable $e) {
            $this->error('Gagal mengirim email: '.$e->getMessage());

            return self::FAILURE;
        }

        $this->info("Email uji berhasil dikirim ke {$email}.");

        return self::SUCCESS;
    }
}
