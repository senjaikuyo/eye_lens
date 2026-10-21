class RiwayatModel {
  final int? idRiwayat;
  final String judul;
  final String isiTeks;
  final int jumlahKata;
  final String sumber;
  final String waktu; // Format ISO8601 string
  final int statusSinkron; // 0: belum sinkron, 1: tersinkron

  const RiwayatModel({
    this.idRiwayat,
    required this.judul,
    required this.isiTeks,
    required this.jumlahKata,
    required this.sumber,
    required this.waktu,
    this.statusSinkron = 0,
  });

  bool get isSynced => statusSinkron == 1;

  DateTime get waktuDateTime {
    try {
      return DateTime.parse(waktu);
    } catch (_) {
      return DateTime.now();
    }
  }

  String get formattedDate {
    final dt = waktuDateTime;
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    return '$day/$month/$year';
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'judul': judul,
      'isi_teks': isiTeks,
      'jumlah_kata': jumlahKata,
      'sumber': sumber,
      'waktu': waktu,
      'status_sinkron': statusSinkron,
    };
    if (idRiwayat != null) {
      map['id_riwayat'] = idRiwayat;
    }
    return map;
  }

  factory RiwayatModel.fromMap(Map<String, dynamic> map) {
    return RiwayatModel(
      idRiwayat: map['id_riwayat'] as int?,
      judul: map['judul'] as String? ?? '',
      isiTeks: map['isi_teks'] as String? ?? '',
      jumlahKata: map['jumlah_kata'] as int? ?? 0,
      sumber: map['sumber'] as String? ?? 'kamera',
      waktu: map['waktu'] as String? ?? DateTime.now().toIso8601String(),
      statusSinkron: map['status_sinkron'] as int? ?? 0,
    );
  }

  RiwayatModel copyWith({
    int? idRiwayat,
    String? judul,
    String? isiTeks,
    int? jumlahKata,
    String? sumber,
    String? waktu,
    int? statusSinkron,
  }) {
    return RiwayatModel(
      idRiwayat: idRiwayat ?? this.idRiwayat,
      judul: judul ?? this.judul,
      isiTeks: isiTeks ?? this.isiTeks,
      jumlahKata: jumlahKata ?? this.jumlahKata,
      sumber: sumber ?? this.sumber,
      waktu: waktu ?? this.waktu,
      statusSinkron: statusSinkron ?? this.statusSinkron,
    );
  }
}
