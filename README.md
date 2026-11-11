# EyeLens 

**EyeLens** adalah aplikasi pembaca teks mandiri berbasis mobile (*Flutter*) dan backend cloud (*Laravel*) yang dirancang khusus untuk membantu **lansia (45+ tahun) dengan presbiopia** dan penderita **low vision**. Aplikasi ini mengusung arsitektur **Hybrid Offline-First**, memungkinkan pengguna memotret dan mendengarkan teks obat, struk, atau dokumen cetak secara instan tanpa membutuhkan kuota internet.

---

##  Fitur Utama
- **Digital Magnifier (1.0x – 10.0x)**: Perbesaran kamera fleksibel via slider kanan atau swipe 1 jari vertikal.
- **On-Device OCR**: Ekstraksi teks aksara Latin langsung di memori RAM via Google ML Kit tanpa internet.
- **Text-to-Speech (TTS) & Auto-Scroll**: Pembacaan suara otomatis dengan penyorotan kata aktif yang otomatis bergulir mengikuti alur bacaan.

---

##  Struktur Monorepo
```text
eye_lens/
├── frontend/    # Aplikasi Mobile Flutter (Android, iOS)
└── backend/     # Backend REST API Laravel (Sanctum, MySQL)
```

---

## Setup

### 1. Prasyarat Sistem
- **Flutter SDK**: v3.24+ / 3.35+
- **PHP**: v8.2+ atau v8.3+
- **Composer**: Dependency manager PHP
- **Node.js & npm**: v18+
- **MySQL / MariaDB Server**: Basis data server (port 3306)
- **Android SDK / Device**: HP Android fisik atau Android Emulator

---

### 2. Setup Frontend (Flutter)

1. Masuk ke direktori `frontend`:
   ```bash
   cd frontend
   ```

2. Unduh dependensi Flutter:
   ```bash
   flutter pub get
   ```

3. Jalankan aplikasi di HP atau emulator:
   ```bash
   # Pastikan HP atau emulator terdeteksi
   flutter devices

   # Menjalankan aplikasi (mode live debug & hot reload)
   flutter run
   ```

4. Build APK rilis berukuran ramping (khusus HP target arm64, ~39 MB):
   ```bash
   flutter build apk --release --split-per-abi
   ```
   *File installer tersedia di: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.*

---

### 3. Setup Backend (Laravel)

1. Masuk ke direktori `backend`:
   ```bash
   cd backend
   ```

2. Salin environment file:
   ```bash
   cp .env.example .env
   ```

3. Pasang dependensi PHP dan Node.js:
   ```bash
   composer install
   npm install
   ```

4. Build aset frontend & panel admin:
   ```bash
   npm run build / `npm run dev`
   ```

5. Buat Application Encryption Key:
   ```bash
   php artisan key:generate
   ```

6. Siapkan basis data dan hak akses pengguna di MariaDB/MySQL:
   ```bash
   sudo mariadb -e "CREATE DATABASE IF NOT EXISTS db_eyelens;
   CREATE USER IF NOT EXISTS 'eyelens_app'@'127.0.0.1' IDENTIFIED BY 'eyelens123';
   GRANT ALL PRIVILEGES ON db_eyelens.* TO 'eyelens_app'@'127.0.0.1';
   FLUSH PRIVILEGES;"
   ```

7. Konfigurasi koneksi MySQL di file `.env`:
   ```env
   DB_CONNECTION=mysql
   DB_HOST=127.0.0.1
   DB_PORT=3306
   DB_DATABASE=db_eyelens
   DB_USERNAME=eyelens_app
   DB_PASSWORD=eyelens123
   ```

8. Jalankan migrasi tabel beserta seeder akun admin:
   ```bash
   php artisan migrate --seed
   ```
9. Jalankan server lokal:
   ```bash
   php artisan serve --host=0.0.0.0 --port=8000
   ```
   *Server akan berjalan di `http://0.0.0.0:8000` sehingga dapat diakses oleh gawai fisik Android pada jaringan yang sama.*

---

### 4. Konfigurasi Email OTP Lupa Password (Gmail SMTP)

Fitur lupa password mengirim kode OTP 6 digit ke email pengguna melalui Gmail SMTP.

1. Aktifkan **Verifikasi 2 Langkah** pada akun Google yang akan dipakai.
2. Buat **App Password 16 digit** di <https://myaccount.google.com/apppasswords>.
3. Isi konfigurasi berikut di `backend/.env`. File yang sama juga dipakai saat menjalankan aplikasi lewat Docker:

   ```env
   MAIL_MAILER=smtp
   MAIL_SCHEME=smtp
   MAIL_HOST=smtp.gmail.com
   MAIL_PORT=587
   MAIL_USERNAME=email_anda@gmail.com
   MAIL_PASSWORD=app_password_16_digit
   MAIL_FROM_ADDRESS=email_anda@gmail.com
   MAIL_FROM_NAME="EyeLens"
   MAIL_TIMEOUT=15

   OTP_EXPIRY_MINUTES=5
   OTP_RESEND_COOLDOWN_SECONDS=60
   OTP_MAX_ATTEMPTS=5
   OTP_RESET_TOKEN_TTL_MINUTES=15
   ```

4. Bersihkan cache konfigurasi setelah mengubah `.env`:

   ```bash
   cd backend
   php artisan config:clear
   ```

   Jika memakai Docker, buat ulang container agar environment baru diterapkan:

   ```bash
   docker-compose up -d --force-recreate app
   docker exec eyelens_app php artisan config:clear
   ```

5. Uji pengiriman email tanpa harus lewat alur lupa password:

   ```bash
   # Di host (non-Docker)
   cd backend
   php artisan mail:test email_anda@gmail.com

   # Di Docker
   docker exec eyelens_app php artisan mail:test email_anda@gmail.com
   ```

   Jika perintah ini berhasil, OTP juga akan terkirim. Jika gagal, pesan error SMTP akan ditampilkan langsung.

**Ketentuan keamanan yang diterapkan:**
- OTP 6 digit hanya disimpan sebagai hash, berlaku **5 menit**, dan hangus setelah dipakai.
- Kirim ulang OTP dibatasi **60 detik** per email (HTTP 429 + `retry_after`).
- Maksimal **5 percobaan** verifikasi per kode.
- Reset token 64 karakter di-hash, berlaku 15 menit, dan hanya bisa dipakai sekali.
- Respons untuk email terdaftar dan tidak terdaftar dibuat seragam.
- Seluruh token Sanctum pengguna direvoke setelah password berhasil diubah.

**Endpoint API:**
- `POST /api/forgot-password`
- `POST /api/verify-reset-code`
- `POST /api/reset-password`

**Menjalankan test fitur:**

```bash
cd backend
vendor/bin/phpunit --filter=PasswordResetTest

cd ../frontend
flutter test test/auth_password_reset_test.dart test/forgot_password_screen_test.dart
```

---

### 5. Setup Docker

#### A. Menjalankan di Komputer Baru (Pertama Kali)
Saat repository baru di-clone di perangkat/komputer lain:
1. Pastikan Docker dan Docker Compose telah terpasang dan aktif.
2. Build dan jalankan seluruh container:
   ```bash
   docker-compose up -d --build
   ```
3. Inisialisasi basis data dan data bawaan (karena MariaDB di perangkat baru masih kosong):
   ```bash
   docker-compose exec app php artisan migrate --seed
   ```
   *Setelah langkah ini selesai, API siap digunakan di `http://localhost:8000` dan phpMyAdmin di `http://localhost:8080`.*

#### B. Menjalankan Sehari-hari (Setelah Setup Pertama Selesai)
Jika perangkat sudah pernah menjalankan langkah inisialisasi di atas (volume data sudah terbentuk), cukup jalankan satu perintah:
```bash
docker-compose up -d
```

Catatan Docker:
- Folder `vendor` disimpan di Docker volume `eye_lens_vendor` (bukan bind mount Windows) agar request tidak lambat. Setelah mengubah dependensi PHP, jalankan `docker-compose exec app composer install`.
- Aset Vite (`public/build`) dibangun otomatis saat image Docker dibuat, jadi tidak perlu menjalankan `npm run build` di host untuk mode Docker.

#### C. Pengaturan Email OTP Lupa Password di Docker
Docker membaca konfigurasi yang sama dari `backend/.env` (lihat langkah 4 pada bagian setup email).

- **Kirim ke Gmail Nyata**:
  1. Isi `MAIL_USERNAME` (alamat Gmail) dan `MAIL_PASSWORD` (App Password 16 digit) di `backend/.env`.
  2. Buat ulang container agar environment baru diterapkan:
     ```bash
     docker-compose up -d --force-recreate app
     docker exec eyelens_app php artisan config:clear
     ```
  3. Verifikasi:
     ```bash
     docker exec eyelens_app php artisan mail:test email_anda@gmail.com
     ```

- **Mode pengembangan tanpa SMTP**: ubah `MAIL_MAILER=log` pada `backend/.env`, lalu jalankan `docker-compose up -d --force-recreate app`. Kode OTP akan tercatat di log container:
  ```bash
  docker-compose logs -f app
  ```

#### D. Mematikan Layanan
```bash
docker-compose down
```

#### E. Menjalankan Secara Offline / Tanpa Build Ulang
1. Ekspor image backend ke file `.tar` dari komputer pengembang:
   ```bash
   docker save -o eyelens.tar eyelens:latest
   ```
2. Di komputer lain tanpa koneksi internet:
   - Salin file `docker-compose.yml`, folder `backend/`, dan file `eyelens.tar`.
   - Muat image ke Docker:
     ```bash
     docker load -i eyelens.tar
     ```
   - Jalankan container dan inisialisasi database:
     ```bash
     docker-compose up -d
     docker-compose exec app php artisan migrate --seed
     ```

---

---

##  Pengembang
EyeLens.
