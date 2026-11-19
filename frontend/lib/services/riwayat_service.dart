import 'dart:async';

import 'database_helper.dart';
import 'sync_service.dart';

/// Pembungkus lama untuk menyimpan riwayat sekaligus memicu sinkronisasi.
/// Kredensial tidak lagi dikirimkan oleh pemanggil: [SyncService] membacanya
/// langsung dari [AuthService]. Parameter userId/authToken dipertahankan
/// hanya untuk kompatibilitas API.
class RiwayatService {
  final SyncService syncService;

  RiwayatService({required this.syncService});

  Future<int> simpanRiwayatBaru({
    required int userId,
    required String judul,
    required String isiTeks,
    required int jumlahKata,
    required String sumber,
    required String authToken,
  }) async {
    final dbHelper = DatabaseHelper.instance;
    await dbHelper.setCurrentUserId(userId);

    final insertedId = await dbHelper.insertRiwayat(
      judul: judul,
      isiTeks: isiTeks,
      jumlahKata: jumlahKata,
      sumber: sumber,
    );

    // Fire-and-forget: kegagalan tetap meninggalkan is_synch = 0.
    unawaited(syncService.syncPending());

    return insertedId;
  }
}
