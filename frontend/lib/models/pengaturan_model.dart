class PengaturanModel {
  final int id;
  final String tema;
  final int ukuranTeks;
  final String warnaKursor;
  final String kontras;
  final int otomatisPutar;
  final double kecepatanSuara;
  final String bahasaSuara;
  final String bahasaAplikasi;
  final String terakhirDiperbarui;

  const PengaturanModel({
    this.id = 1,
    this.tema = 'sistem',
    this.ukuranTeks = 18,
    this.warnaKursor = '#FACC15',
    this.kontras = 'normal',
    this.otomatisPutar = 1,
    this.kecepatanSuara = 1.0,
    this.bahasaSuara = 'id-ID',
    this.bahasaAplikasi = 'id',
    required this.terakhirDiperbarui,
  });

  bool get isOtomatisPutar => otomatisPutar == 1;

  Map<String, dynamic> toMap() {
    return {
      'id': 1,
      'tema': tema,
      'ukuran_teks': ukuranTeks,
      'warna_kursor': warnaKursor,
      'kontras': kontras,
      'otomatis_putar': otomatisPutar,
      'kecepatan_suara': kecepatanSuara,
      'bahasa_suara': bahasaSuara,
      'bahasa_aplikasi': bahasaAplikasi,
      'terakhir_diperbarui': terakhirDiperbarui,
    };
  }

  factory PengaturanModel.fromMap(Map<String, dynamic> map) {
    return PengaturanModel(
      id: map['id'] as int? ?? 1,
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
    );
  }

  factory PengaturanModel.defaults() {
    return PengaturanModel(
      id: 1,
      tema: 'sistem',
      ukuranTeks: 18,
      warnaKursor: '#FACC15',
      kontras: 'normal',
      otomatisPutar: 1,
      kecepatanSuara: 1.0,
      bahasaSuara: 'id-ID',
      bahasaAplikasi: 'id',
      terakhirDiperbarui: DateTime.now().toIso8601String(),
    );
  }

  PengaturanModel copyWith({
    String? tema,
    int? ukuranTeks,
    String? warnaKursor,
    String? kontras,
    int? otomatisPutar,
    double? kecepatanSuara,
    String? bahasaSuara,
    String? bahasaAplikasi,
    String? terakhirDiperbarui,
  }) {
    return PengaturanModel(
      id: 1,
      tema: tema ?? this.tema,
      ukuranTeks: ukuranTeks ?? this.ukuranTeks,
      warnaKursor: warnaKursor ?? this.warnaKursor,
      kontras: kontras ?? this.kontras,
      otomatisPutar: otomatisPutar ?? this.otomatisPutar,
      kecepatanSuara: kecepatanSuara ?? this.kecepatanSuara,
      bahasaSuara: bahasaSuara ?? this.bahasaSuara,
      bahasaAplikasi: bahasaAplikasi ?? this.bahasaAplikasi,
      terakhirDiperbarui: terakhirDiperbarui ?? this.terakhirDiperbarui,
    );
  }
}
