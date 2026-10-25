# EyeLens 

**EyeLens** adalah aplikasi pembaca teks mandiri berbasis mobile (*Flutter*) dan backend cloud (*Laravel*) yang dirancang khusus untuk membantu **lansia (45+ tahun) dengan presbiopia** dan penderita **low vision**. Aplikasi ini mengusung arsitektur **Hybrid Offline-First**, memungkinkan pengguna memotret dan mendengarkan teks obat, struk, atau dokumen cetak secara instan tanpa membutuhkan kuota internet.

---

##  Fitur Utama
- **Digital Magnifier (1.0x – 10.0x)**: Perbesaran kamera fleksibel via slider kanan atau swipe 1 jari vertikal.
- **On-Device OCR (<500 ms)**: Ekstraksi teks aksara Latin langsung di memori RAM via Google ML Kit tanpa internet.
- **Ephemeral Memory (Privasi Terjaga)**: Citra kamera hanya ditahan di RAM untuk ekstraksi teks dan langsung dimusnahkan (`0 byte` file foto tersimpan di penyimpanan gawai).
- **Text-to-Speech (TTS) & Auto-Scroll**: Pembacaan suara otomatis dengan penyorotan kata aktif (*synchronized word highlighting*) yang otomatis bergulir mengikuti alur bacaan.
- **Penyimpanan Lokal (SQLite)**: Riwayat bacaan tersimpan di basis data lokal HP dengan batas maksimal 50 data terbaru (`trg_limit_riwayat_50`).
- **Cloud Sync (Laravel Backend)**: Penyelarasan riwayat dan preferensi pengguna dua arah saat internet aktif, dengan enkripsi **AES-256-CBC** untuk isi teks di server.

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
- **Node.js & npm**: v18+ (untuk build aset Vite/CSS Admin)
- **MySQL / MariaDB Server**: Basis data server (port 3306)
- **Android SDK / Device**: HP Android fisik (mode USB Debugging aktif) atau Android Emulator

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
   *File installer akan tersedia di: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.*

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
   npm run build
   ```
   *(Gunakan `npm run dev` jika sedang melakukan pengembangan antarmuka Blade).*

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
   *Akun administrator bawaan untuk panel web:*
   - **URL Panel**: `http://localhost:8000/`
   - **Email**: `admin@gmail.com`
   - **Password**: `admin123`

9. Jalankan server lokal:
   ```bash
   php artisan serve --host=0.0.0.0 --port=8000
   ```
   *Server akan berjalan di `http://0.0.0.0:8000` sehingga dapat diakses oleh gawai fisik Android pada jaringan yang sama.*

---

### 4. Setup Backend dengan Docker Compose (Alternatif Portabel)

Jika tidak ingin memasang PHP 8.3, Composer, atau basis data lokal di mesin host, backend dapat dijalankan secara terisolasi via Docker Compose.

#### Layanan yang Disediakan
- **app (`eyelens`)**: PHP 8.3 FPM Alpine (Backend Laravel 11 & Sanctum API)
- **webserver (`nginx:alpine`)**: Port host `8000:80`
- **db (`mariadb:10.11`)**: Port host `3307:3306` (agar tidak konflik dengan MariaDB lokal host)
- **phpmyadmin (`phpmyadmin/phpmyadmin`)**: Port host `8080:80`

#### Langkah Menjalankan
1. Pastikan Docker dan Docker Compose telah terpasang dan service Docker berjalan.
2. Dari root proyek (`eye_lens/`), jalankan:
   ```bash
   docker-compose up -d --build
   ```
3. Jalankan migrasi dan seeder database awal:
   ```bash
   docker-compose exec app php artisan migrate --seed
   ```
4. Akses layanan:
   - Panel Admin: `http://localhost:8000/` (Email: `admin@gmail.com` | Password: `admin123`)
   - Endpoint API: `http://localhost:8000/api/`
   - phpMyAdmin: `http://localhost:8080/` (User: `eyelens_app` | Password: `eyelens123`)

#### Mematikan Layanan
```bash
docker-compose down
```

#### Ekspor dan Migrasi Image ke Lingkungan Lain
1. Ekspor image backend ke file `.tar`:
   ```bash
   docker save -o eyelens.tar eyelens:latest
   ```
2. Di lingkungan/komputer lain:
   - Salin file `docker-compose.yml`, folder `backend/`, dan file `eyelens.tar`.
   - Muat image ke Docker:
     ```bash
     docker load -i eyelens.tar
     ```
   - Jalankan stack tanpa build ulang:
     ```bash
     docker-compose up -d
     docker-compose exec app php artisan migrate --seed
     ```

---

##  Kebijakan Privasi & Keamanan
-

---

##  Pengembang
Dibuat sebagai solusi aksesibilitas digital untuk presbiopia & low vision (EyeLens Team).
