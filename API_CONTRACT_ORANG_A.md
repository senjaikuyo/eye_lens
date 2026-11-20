# Kontrak API untuk Orang A (Backend)

Dokumen ini merinci endpoint yang **belum ada** dan perlu disepakati sebelum
Flutter mengintegrasikannya. Frontend tidak memanggil endpoint yang tidak ada
dan tidak mengarang kontrak. Endpoint yang sudah diimplementasikan pada
pekerjaan ini dicantumkan di bagian akhir sebagai referensi.

Semua endpoint menggunakan `auth:sanctum` dan mengembalikan JSON.
Identitas pengguna **selalu** diambil dari token, bukan dari body request.
Kesalahan validasi memakai format Laravel standar (`422` + `errors`).

---

## 1. Ubah profil — BELUM ADA

Saat ini backend hanya menyediakan `GET /api/me` (read-only). Flutter sudah
menampilkan email/nama asli dari sesi dan menyegarkannya lewat `/api/me`, tetapi
belum ada UI/aksi ubah profil karena endpoint-nya belum ada.

### Usulan kontrak

`PUT /api/profile`

Request:

```json
{
  "name": "Nama Baru",
  "email": "email.baru@example.com"
}
```

Aturan:

- `name`: wajib, string, 1–255 karakter.
- `email`: wajib, format email, unik di tabel `users` (kecuali milik pengguna
  sendiri), maksimal 255 karakter.
- Perubahan email harus mempertimbangkan verifikasi ulang email
  (`email_verified_at = null`) dan pemberitahuan ke email lama/baru.
- `user_id` di body diabaikan.
- Bila email berubah, token Sanctum yang ada tetap boleh dipakai atau dicabut
  sesuai kebijakan keamanan; dokumentasikan pilihannya.

Response sukses (`200`):

```json
{
  "status": "success",
  "user": {
    "id": 12,
    "name": "Nama Baru",
    "email": "email.baru@example.com",
    "email_verified_at": null
  }
}
```

Kode error:

| Kode | Arti |
|---|---|
| `401` | Token tidak ada/tidak sah |
| `422` | Validasi gagal (mis. email sudah dipakai) |

Setelah kontrak disetujui, frontend akan menambahkan
`AuthService.updateProfile()` dan UI edit profil, lalu memanggil
`AuthProvider.validateSession()` agar data sesi lokal ikut diperbarui.

---

## 2. Ubah kata sandi — BELUM ADA (risiko kritis)

`ChangePasswordScreen` saat ini menampilkan dialog sukses palsu tanpa memanggil
backend. Ini **harus** diperbaiki. Frontend belum mengubah layar tersebut karena
tidak ada endpoint dan aturan kata sandi yang disepakati.

### Usulan kontrak

`PUT /api/password`

Request:

```json
{
  "current_password": "SandiLama123!",
  "password": "SandiBaru456!",
  "password_confirmation": "SandiBaru456!"
}
```

Aturan:

- `current_password`: wajib dan harus cocok dengan kata sandi saat ini.
- `password`: wajib, minimal 8 karakter, harus sama dengan
  `password_confirmation`, dan mengikuti kebijakan kompleksitas yang sama
  dengan registrasi/reset (huruf besar, huruf kecil, angka, simbol).
- Kata sandi lama **tidak boleh** disimpan di perangkat.
- Setelah sukses, cabut token Sanctum lain (kecuali token saat ini bila
  diinginkan) dan paksa login ulang bila kebijakan mengharuskan.

Response sukses (`200`):

```json
{
  "status": "success",
  "message": "Kata sandi berhasil diperbarui"
}
```

Kode error:

| Kode | Arti |
|---|---|
| `401` | Token tidak sah |
| `422` | Kata sandi lama salah / validasi gagal |

Sampai endpoint ini ada, fitur ubah kata sandi **tidak boleh** menampilkan
pesan sukses.

---

## 3. Batasan autentikasi offline (Sanctum)

- Token Sanctum bersifat **opaque** (bukan JWT). Validitasnya tidak dapat
  diverifikasi secara kriptografis saat offline.
- Perilaku frontend saat ini:
  - Sesi tersimpan (token + data pengguna) dipulihkan saat aplikasi dibuka,
    sehingga pengguna yang pernah login dapat masuk tanpa jaringan.
  - Saat online, `GET /api/me` dipanggil untuk memvalidasi token.
  - `200` → sesi sah dan data pengguna diperbarui.
  - `401`/`403` → sesi lokal dihapus dan pengguna diarahkan login.
  - Timeout/`5xx`/gangguan jaringan → sesi lokal **dipertahankan** (mode
    offline) dan validasi dicoba lagi saat koneksi kembali.
- Token disimpan di `SharedPreferences` (plaintext) karena belum ada
  persetujuan penambahan `flutter_secure_storage`. Ini risiko yang diketahui
  dan perlu diputuskan terpisah.
- Backend tidak perlu mengubah perilaku Sanctum untuk mendukung ini. Cukup
  pastikan token yang dicabut/kedaluwarsa konsisten mengembalikan `401` pada
  `/api/me`, `/api/sync`, `/api/pengaturan`, dan `/api/masukan`.

---

## 4. Endpoint yang sudah diimplementasikan (referensi)

### `PUT /api/pengaturan`

Menulis pengaturan pengguna dengan aturan **terbaru menang PER-FIELD**.
Setiap field memiliki timestamp sendiri di `field_timestamps`; hanya field
yang timestamp-nya lebih baru dari nilai server yang ditimpa. Field lain tetap
memakai nilai server, sehingga perubahan baru pada satu field tidak tertimpa
oleh field lain yang lebih lama.

`POST /api/sync` memakai aturan konflik yang sama untuk objek `pengaturan`.

Request:

```json
{
  "tema": "dark",
  "ukuran_teks": 24,
  "warna_kursor": "#1678BA",
  "kontras": "tinggi",
  "otomatis_putar": false,
  "kecepatan_suara": 1.5,
  "bahasa_suara": "en-US",
  "bahasa_aplikasi": "en",
  "terakhir_diperbarui": "2026-11-17T12:00:00.000000Z",
  "field_timestamps": {
    "tema": "2026-11-17T12:00:00.000000Z",
    "ukuran_teks": "2026-11-17T10:00:00.000000Z",
    "warna_kursor": "2026-11-17T09:00:00.000000Z",
    "kontras": "2026-11-17T09:00:00.000000Z",
    "otomatis_putar": "2026-11-17T09:00:00.000000Z",
    "kecepatan_suara": "2026-11-17T09:00:00.000000Z",
    "bahasa_suara": "2026-11-17T09:00:00.000000Z",
    "bahasa_aplikasi": "2026-11-17T09:00:00.000000Z"
  }
}
```

`field_timestamps` opsional. Bila tidak dikirim (klien lama), seluruh field
memakai `terakhir_diperbarui` sebagai timestamp (perilaku row-level lama).
Perbandingan bersifat ketat: timestamp yang sama tidak menimpa nilai server.

Response `200` selalu mengembalikan state server terkini, termasuk
`field_timestamps` hasil merge:

```json
{
  "status": "success",
  "pengaturan": {
    "tema": "dark",
    "ukuran_teks": 24,
    "warna_kursor": "#1678BA",
    "kontras": "tinggi",
    "otomatis_putar": false,
    "kecepatan_suara": 1.5,
    "bahasa_suara": "en-US",
    "bahasa_aplikasi": "en",
    "terakhir_diperbarui": "2026-11-17T12:00:00.000000+00:00",
    "field_timestamps": { "...": "..." }
  }
}
```

Bila seluruh field yang dikirim lebih lama dari nilai server, tidak ada nilai
yang ditimpa dan response berisi nilai server.

### `POST /api/masukan`

Request:

```json
{ "pesan": "Tolong tambah mode gelap" }
```

Response `201`:

```json
{
  "status": "success",
  "message": "Masukan berhasil dikirim",
  "masukan": { "id": 1, "pesan": "...", "created_at": "..." }
}
```

Validasi: `pesan` wajib, tidak boleh kosong/whitespace, maksimal 5000 karakter.
Kedua endpoint di atas mencatat `audit_log` dan mengambil `user_id` dari token.
