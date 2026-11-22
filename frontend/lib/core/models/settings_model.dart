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

  factory SettingsModel.fromMap(Map<String, dynamic> map) {
    return SettingsModel(
      id: map['id'] as int? ?? 1,
      userId: (map['user_id'] as int?) ?? -1,
      tema: map['tema'] as String? ?? 'sistem',
      ukuranTeks: map['ukuran_teks'] as int? ?? 18,
      warnaKursor: map['warna_kursor'] as String? ?? '#FACC15',
      kontras: map['kontras'] as String? ?? 'normal',
      otomatisPutar: map['otomatis_putar'] as int? ?? 1,
      kecepatanSuara: (map['kecepatan_suara'] as num?)?.toDouble() ?? 1.0,
      bahasaSuara: map['bahasa_suara'] as String? ?? 'id-ID',
      bahasaAplikasi: map['bahasa_aplikasi'] as String? ?? 'id',
      terakhirDiperbarui:
          map['terakhir_diperbarui'] as String? ??
          DateTime.now().toIso8601String(),
      isSynch: (map['is_synch'] as int?) ?? 0,
    );
  }
}
