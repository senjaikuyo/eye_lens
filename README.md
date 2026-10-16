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
- **MySQL Server**: Basis data server (port 3306)
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

3. Pasang dependensi PHP via Composer:
   ```bash
   composer install
   ```

4. Buat Application Encryption Key:
   ```bash
   php artisan key:generate
   ```

5. Konfigurasi koneksi MySQL di file `.env`:
   ```env
   DB_CONNECTION=mysql
   DB_HOST=127.0.0.1
   DB_PORT=3306
   DB_DATABASE=eyelens_db
   DB_USERNAME=root
   DB_PASSWORD=password_kamu
   ```

6. Buat database `eyelens_db` di MySQL, lalu jalankan migrasi tabel:
   ```bash
   php artisan migrate
   ```

7. Jalankan server lokal:
   ```bash
   php artisan serve
   ```
   *Server akan berjalan di `http://127.0.0.1:8000`.*

---

##  Kebijakan Privasi & Keamanan
-

---

##  Pengembang
Dibuat sebagai solusi aksesibilitas digital untuk presbiopia & low vision (EyeLens Team).
