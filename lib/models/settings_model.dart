class SettingsModel {
  final int id;
  final String modeTema; // 'light' or 'dark'
  final String skalaFont; // 'normal', 'large', 'extra_large'
  final double kecepatanSuara; // 0.75, 1.0, 1.25
  final String bahasaSuara; // 'id-ID' or 'en-US'
  final bool garisPanduanAktif;
  final bool umpanBalikGetar;
  final double zoomBawaan;
  final String? terakhirDiperbarui;

  SettingsModel({
    this.id = 1,
    this.modeTema = 'light',
    this.skalaFont = 'large',
    this.kecepatanSuara = 1.0,
    this.bahasaSuara = 'id-ID',
    this.garisPanduanAktif = true,
    this.umpanBalikGetar = true,
    this.zoomBawaan = 1.0,
    this.terakhirDiperbarui,
  });

  factory SettingsModel.fromMap(Map<String, dynamic> map) {
    return SettingsModel(
      id: map['id'] as int? ?? 1,
      modeTema: map['mode_tema'] as String? ?? 'light',
      skalaFont: map['skala_font'] as String? ?? 'large',
      kecepatanSuara: (map['kecepatan_suara'] as num?)?.toDouble() ?? 1.0,
      bahasaSuara: map['bahasa_suara'] as String? ?? 'id-ID',
      garisPanduanAktif: (map['garis_panduan_aktif'] as int? ?? 1) == 1,
      umpanBalikGetar: (map['umpan_balik_getar'] as int? ?? 1) == 1,
      zoomBawaan: (map['zoom_bawaan'] as num?)?.toDouble() ?? 1.0,
      terakhirDiperbarui: map['terakhir_diperbarui'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mode_tema': modeTema,
      'skala_font': skalaFont,
      'kecepatan_suara': kecepatanSuara,
      'bahasa_suara': bahasaSuara,
      'garis_panduan_aktif': garisPanduanAktif ? 1 : 0,
      'umpan_balik_getar': umpanBalikGetar ? 1 : 0,
      'zoom_bawaan': zoomBawaan,
      'terakhir_diperbarui': DateTime.now().toIso8601String(),
    };
  }

  SettingsModel copyWith({
    int? id,
    String? modeTema,
    String? skalaFont,
    double? kecepatanSuara,
    String? bahasaSuara,
    bool? garisPanduanAktif,
    bool? umpanBalikGetar,
    double? zoomBawaan,
  }) {
    return SettingsModel(
      id: id ?? this.id,
      modeTema: modeTema ?? this.modeTema,
      skalaFont: skalaFont ?? this.skalaFont,
      kecepatanSuara: kecepatanSuara ?? this.kecepatanSuara,
      bahasaSuara: bahasaSuara ?? this.bahasaSuara,
      garisPanduanAktif: garisPanduanAktif ?? this.garisPanduanAktif,
      umpanBalikGetar: umpanBalikGetar ?? this.umpanBalikGetar,
      zoomBawaan: zoomBawaan ?? this.zoomBawaan,
      terakhirDiperbarui: DateTime.now().toIso8601String(),
    );
  }

  double get fontSizeMultiplier {
    switch (skalaFont) {
      case 'normal':
        return 1.0;
      case 'extra_large':
        return 1.35;
      case 'large':
      default:
        return 1.18;
    }
  }
}
