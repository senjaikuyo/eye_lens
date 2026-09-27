import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

class AppStrings {
  final bool isIndonesian;

  const AppStrings({required this.isIndonesian});

  static AppStrings of(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    return AppStrings(isIndonesian: languageProvider.isIndonesian);
  }

  // --- Common & Navigation ---
  String get back => isIndonesian ? 'Kembali' : 'Back';
  String get cancel => isIndonesian ? 'Batal' : 'Cancel';
  String get update => isIndonesian ? 'Perbarui' : 'Update';
  String get save => isIndonesian ? 'Simpan' : 'Save';
  String get next => isIndonesian ? 'Lanjut' : 'Next';
  String get start => isIndonesian ? 'Mulai' : 'Start';

  // --- Onboarding ---
  String get onbTitle1 =>
      isIndonesian ? 'Membaca jadi lebih mudah.' : 'Reading made easier.';
  String get onbSub1 => isIndonesian
      ? 'EyeLens membantu Anda melihat dan memahami teks yang terlalu kecil atau sulit dibaca.'
      : 'EyeLens helps you see and understand text that may be too small or difficult to read.';

  String get onbTitle2 => isIndonesian
      ? 'Lihat teks kecil\nlebih jelas.'
      : 'See small text\nmore clearly.';
  String get onbSub2 => isIndonesian
      ? 'Arahkan kamera ke teks dan EyeLens akan membuatnya lebih mudah dibaca.'
      : 'Point your camera at a text and EyeLens will make it easier to read.';

  String get onbTitle3 =>
      isIndonesian ? 'Atau cukup\ndengarkan.' : 'Or simply\nlisten.';
  String get onbSub3 => isIndonesian
      ? 'Biarkan EyeLens membacakan teks dengan suara saat membaca terasa sulit.'
      : 'Let EyeLens read the text aloud when reading feels difficult.';

  // --- Auth ---
  String get email => 'Email';
  String get password => isIndonesian ? 'Kata Sandi' : 'Password';
  String get confirmPassword =>
      isIndonesian ? 'Konfirmasi Kata Sandi' : 'Confirm Password';
  String get login => isIndonesian ? 'Masuk' : 'Login';
  String get register => isIndonesian ? 'Daftar' : 'Register';
  String get haventRegistered =>
      isIndonesian ? 'Belum punya akun?' : 'haven`t register yet?';
  String get alreadyHaveAccount =>
      isIndonesian ? 'Sudah punya akun?' : 'Do you have an account?';
  String get registerSuccess => isIndonesian
      ? 'Pendaftaran berhasil! Silakan masuk.'
      : 'Registration successful! Please login.';

  // --- Camera & Scanner ---
  String get gallery => isIndonesian ? 'Galeri' : 'Gallery';
  String get galleryPickMsg =>
      isIndonesian ? 'Pilih gambar dari Galeri' : 'Pick image from Gallery';

  // --- Speech & Text View ---
  String get speechLanguage =>
      isIndonesian ? 'Bahasa Suara' : 'Speech Language';

  // --- History ---
  String get history => isIndonesian ? 'Riwayat' : 'History';
  String get clearAll => isIndonesian ? 'Hapus Semua' : 'Clear All';
  String get deleteConfirmTitle =>
      isIndonesian ? 'Hapus Riwayat' : 'Delete History';
  String get deleteConfirmMessage => isIndonesian
      ? 'Apakah Anda yakin ingin menghapus item riwayat ini?'
      : 'Are you sure you want to delete this history item?';
  String get clearAllConfirmMessage => isIndonesian
      ? 'Apakah Anda yakin ingin menghapus seluruh riwayat?'
      : 'Are you sure you want to delete all history items?';
  String get delete => isIndonesian ? 'Hapus' : 'Delete';
  String get noHistoryTitle =>
      isIndonesian ? 'Belum Ada Riwayat' : 'No Scan History Yet';
  String get noHistorySubtitle => isIndonesian
      ? 'Teks hasil pemindaian kamera akan muncul di sini.'
      : 'Scanned documents and text will appear here.';

  // --- Auth & Form Validations ---
  String get emailInvalid => isIndonesian
      ? 'Masukkan alamat email yang valid'
      : 'Please enter a valid email address';
  String get passwordTooShort => isIndonesian
      ? 'Kata sandi minimal 6 karakter'
      : 'Password must be at least 6 characters';
  String get passwordRequired => isIndonesian
      ? 'Kata sandi tidak boleh kosong'
      : 'Password is required';
  String get currentPasswordRequired => isIndonesian
      ? 'Kata sandi saat ini harus diisi'
      : 'Current password is required';
  String get newPasswordSameAsOld => isIndonesian
      ? 'Kata sandi baru tidak boleh sama dengan kata sandi saat ini'
      : 'New password cannot be the same as current password';
  String get ok => 'OK';

  // --- Settings ---
  String get settings => isIndonesian ? 'Pengaturan' : 'Settings';
  String get changePassword =>
      isIndonesian ? 'Ubah Kata Sandi' : 'Change Password';
  String get appearance => isIndonesian ? 'Tampilan' : 'Appearance';
  String get autoPlayAudio =>
      isIndonesian ? 'Putar Audio Otomatis' : 'Auto-Play Audio';
  String get languageApp => isIndonesian ? 'Bahasa Aplikasi' : 'Language App';
  String get indonesian => 'Indonesian';
  String get english => 'English';
  String get faq => isIndonesian ? 'Tanya Jawab (FAQ)' : 'FAQ';
  String get about => isIndonesian ? 'Tentang' : 'About';
  String get logOut => isIndonesian ? 'Keluar' : 'Log Out';
  String get logOutConfirmTitle =>
      isIndonesian ? 'Keluar Akun' : 'Log Out';
  String get logOutConfirmMessage => isIndonesian
      ? 'Apakah Anda yakin ingin keluar dari EyeLens?'
      : 'Are you sure you want to log out of EyeLens?';

  // --- Appearance ---
  String get theme => isIndonesian ? 'Tema' : 'Theme';
  String get themeLight => isIndonesian ? 'Terang' : 'Light';
  String get themeDark => isIndonesian ? 'Gelap' : 'Dark';
  String get themeSystem => isIndonesian ? 'Sistem' : 'System';
  String get highContrast =>
      isIndonesian ? 'Kontras Tinggi' : 'High Contrast';
  String get cursorColor => isIndonesian ? 'Warna Kursor' : 'Cursor Color';

  // --- Change Password ---
  String get currentPassword =>
      isIndonesian ? 'Kata Sandi Saat Ini' : 'Current Password';
  String get newPassword =>
      isIndonesian ? 'Kata Sandi Baru' : 'New Password';
  String get fillAllFields => isIndonesian
      ? 'Harap isi semua kolom kata sandi'
      : 'Please fill all password fields';
  String get passwordsDoNotMatch => isIndonesian
      ? 'Kata sandi baru tidak cocok'
      : 'New passwords do not match';
  String get passwordUpdatedSuccess => isIndonesian
      ? 'Kata sandi berhasil diperbarui!'
      : 'Password updated successfully!';

  // --- FAQ Content ---
  List<Map<String, String>> get faqItems => isIndonesian
      ? [
          {
            'q': 'Bagaimana cara memindai teks?',
            'a':
                'Arahkan kamera ke teks cetak atau tulisan tangan apa pun, lalu tekan tombol kamera bulat di tengah untuk memindai.',
          },
          {
            'q': 'Bisakah memindai gambar dari galeri?',
            'a':
                'Ya, tekan tombol "Galeri" di kiri bawah layar pemindai untuk memilih gambar dari perangkat Anda.',
          },
          {
            'q': 'Bagaimana cara memperbesar teks hasil pemindaian?',
            'a':
                'Pada Tampilan Teks, gunakan tombol "+" dan "-" di bar atas untuk menyesuaikan ukuran font sesuai kenyamanan Anda.',
          },
          {
            'q': 'Bahasa apa saja yang didukung untuk Text-to-Speech?',
            'a':
                'EyeLens mendukung Bahasa Indonesia dan Bahasa Inggris. Anda dapat beralih bahasa dengan mengetuk ikon bendera pada pemutar suara.',
          },
          {
            'q': 'Bagaimana cara agar aplikasi membaca teks dengan suara?',
            'a':
                'Setelah memindai atau memilih dari riwayat, cukup tekan tombol Putar (Play) besar di bagian bawah layar.',
          },
        ]
      : [
          {
            'q': 'How do I scan text?',
            'a':
                'Point your camera at any printed or handwritten text and press the center camera button to capture and scan.',
          },
          {
            'q': 'Can I scan an image from my gallery?',
            'a':
                'Yes, tap the "Gallery" button on the bottom left of the scanner screen to select an image from your device.',
          },
          {
            'q': 'How can I make the scanned text bigger?',
            'a':
                'In Text View, use the "+" and "-" buttons on the top bar to adjust the font size to your comfort.',
          },
          {
            'q': 'Which languages are supported for Text-to-Speech?',
            'a':
                'EyeLens currently supports Indonesian and English. You can switch languages by tapping the flag icon on the player.',
          },
          {
            'q': 'How can I make the app read the text aloud?',
            'a':
                'After scanning or selecting from history, simply press the big Play button at the bottom of the screen.',
          },
        ];
}
