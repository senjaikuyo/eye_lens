class RiwayatModel {
  final int? idRiwayat;
  final int userId;
  final String clientUuid;
  final String judul;
  final String isiTeks;
  final int jumlahKata;
  final String sumber;
  final String waktu; // Format ISO8601 string
  final int statusSinkron; // 0: belum sinkron, 1: tersinkron (kolom is_synch)
  final String updatedAt;

  const RiwayatModel({
    this.idRiwayat,
    this.userId = DatabaseHelperLegacy.userId,
    this.clientUuid = '',
    required this.judul,
    required this.isiTeks,
    required this.jumlahKata,
    required this.sumber,
    required this.waktu,
    this.statusSinkron = 0,
    this.updatedAt = '',
  });

  bool get isSynced => statusSinkron == 1;
  bool get isSynch => statusSinkron == 1;

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
      'user_id': userId,
      'client_uuid': clientUuid,
      'judul': judul,
      'isi_teks': isiTeks,
      'jumlah_kata': jumlahKata,
      'sumber': sumber,
      'waktu': waktu,
      'is_synch': statusSinkron,
      'updated_at': updatedAt,
    };
    if (idRiwayat != null) {
      map['id_riwayat'] = idRiwayat;
    }
    return map;
  }

  factory RiwayatModel.fromMap(Map<String, dynamic> map) {
    return RiwayatModel(
      idRiwayat: map['id_riwayat'] as int?,
      userId: (map['user_id'] as int?) ?? DatabaseHelperLegacy.userId,
      clientUuid: (map['client_uuid'] as String?) ?? '',
      judul: map['judul'] as String? ?? '',
      isiTeks: map['isi_teks'] as String? ?? '',
      jumlahKata: map['jumlah_kata'] as int? ?? 0,
      sumber: map['sumber'] as String? ?? 'kamera',
      waktu: map['waktu'] as String? ?? DateTime.now().toIso8601String(),
      statusSinkron: (map['is_synch'] as int?) ??
          (map['status_sinkron'] as int?) ??
          0,
      updatedAt: (map['updated_at'] as String?) ??
          (map['waktu'] as String?) ??
          DateTime.now().toIso8601String(),
    );
  }

  RiwayatModel copyWith({
    int? idRiwayat,
    int? userId,
    String? clientUuid,
    String? judul,
    String? isiTeks,
    int? jumlahKata,
    String? sumber,
    String? waktu,
    int? statusSinkron,
    String? updatedAt,
  }) {
    return RiwayatModel(
      idRiwayat: idRiwayat ?? this.idRiwayat,
      userId: userId ?? this.userId,
      clientUuid: clientUuid ?? this.clientUuid,
      judul: judul ?? this.judul,
      isiTeks: isiTeks ?? this.isiTeks,
      jumlahKata: jumlahKata ?? this.jumlahKata,
      sumber: sumber ?? this.sumber,
      waktu: waktu ?? this.waktu,
      statusSinkron: statusSinkron ?? this.statusSinkron,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Nilai sentinel yang sama dengan [DatabaseHelper.legacyUserId].
/// Didefinisikan terpisah agar model tidak bergantung pada service layer.
class DatabaseHelperLegacy {
  static const int userId = -1;
}
