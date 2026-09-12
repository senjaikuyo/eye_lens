class HistoryModel {
  final int? id;
  final String judul;
  final String isiTeks;
  final int jumlahKata;
  final String tanggalPindai;

  HistoryModel({
    this.id,
    required this.judul,
    required this.isiTeks,
    required this.jumlahKata,
    required this.tanggalPindai,
  });

  factory HistoryModel.fromMap(Map<String, dynamic> map) {
    return HistoryModel(
      id: map['id'] as int?,
      judul: map['judul'] as String? ?? 'Tanpa Judul',
      isiTeks: map['isi_teks'] as String? ?? '',
      jumlahKata: map['jumlah_kata'] as int? ?? 0,
      tanggalPindai: map['tanggal_pindai'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'judul': judul,
      'isi_teks': isiTeks,
      'jumlah_kata': jumlahKata,
      'tanggal_pindai': tanggalPindai,
    };
  }

  static String generateJudul(String fullText) {
    final clean = fullText.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty) return 'Teks Kosong';
    final words = clean.split(' ');
    if (words.length <= 5) return clean;
    return '${words.take(5).join(' ')}...';
  }

  static int countWords(String fullText) {
    final clean = fullText.trim();
    if (clean.isEmpty) return 0;
    return clean.split(RegExp(r'\s+')).length;
  }
}
