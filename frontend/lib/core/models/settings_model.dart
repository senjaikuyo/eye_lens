class SettingsModel {
  final int id;
  final int userId;
  final String tema;
  final int ukuranTeks;
  final String warnaKursor;
  final String kontras;
  final int otomatisPutar;
  final double kecepatanSuara;
  final String bahasaSuara;
  final String bahasaAplikasi;
  final String terakhirDiperbarui;
  final int isSynch;

  const SettingsModel({
    this.id = 1,
    this.userId = -1,
    this.tema = 'sistem',
    this.ukuranTeks = 18,
    this.warnaKursor = '#FACC15',
    this.kontras = 'normal',
    this.otomatisPutar = 1,
    this.kecepatanSuara = 1.0,
    this.bahasaSuara = 'id-ID',
    this.bahasaAplikasi = 'id',
    required this.terakhirDiperbarui,
    this.isSynch = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'tema': tema,
      'ukuran_teks': ukuranTeks,
      'warna_kursor': warnaKursor,
      'kontras': kontras,
      'otomatis_putar': otomatisPutar,
      'kecepatan_suara': kecepatanSuara,
      'bahasa_suara': bahasaSuara,
      'bahasa_aplikasi': bahasaAplikasi,
      'terakhir_diperbarui': terakhirDiperbarui,
      'is_synch': isSynch,
    };
  }
}
