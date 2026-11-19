import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:eye_lens/services/auth/auth_service.dart';
import 'package:eye_lens/services/database_helper.dart';
import 'package:eye_lens/services/sync_service.dart';

class FakeConnectivity implements Connectivity {
  final List<ConnectivityResult> results;

  FakeConnectivity(this.results);

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => results;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream<List<ConnectivityResult>>.empty();
}

class FakeAuthService extends AuthService {
  final String? token;
  final int userId;

  FakeAuthService({this.token, required this.userId});

  @override
  Future<AuthSession?> getSession() async {
    if (token == null || token!.isEmpty) return null;
    return AuthSession(token: token!, user: {'id': userId});
  }

  @override
  Future<String?> getToken() async => token;

  @override
  Future<Map<String, dynamic>?> getUser() async => {'id': userId};
}

/// Sesi yang bisa berubah di tengah test untuk mensimulasikan pergantian akun.
class MutableFakeAuthService extends AuthService {
  String? token;
  int userId;

  MutableFakeAuthService({required this.token, required this.userId});

  @override
  Future<AuthSession?> getSession() async {
    if (token == null || token!.isEmpty) return null;
    return AuthSession(token: token!, user: {'id': userId});
  }
}

class FakeClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest request) handler;
  final List<http.BaseRequest> requests = [];

  FakeClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    final response = await handler(request);
    return http.StreamedResponse(
      Stream.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    // Lokasi database unik per file test agar tidak bertabrakan dengan
    // database_helper_test.dart yang berjalan paralel.
    final tempDir = await Directory.systemTemp.createTemp('eyelens_sync_test');
    await databaseFactoryFfi.setDatabasesPath(tempDir.path);
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('tbl_riwayat');
    await db.delete('tbl_pengaturan');
    await DatabaseHelper.instance.setCurrentUserId(10);
  });

  tearDownAll(() async {
    await DatabaseHelper.instance.close();
  });

  http.Response okSyncResponse(List<String> uuids) => http.Response(
    jsonEncode({'status': 'success', 'synced_riwayat': uuids}),
    200,
    headers: {'Content-Type': 'application/json'},
  );

  http.Response okSyncResponseWithPengaturan(
    List<String> uuids,
    Map<String, dynamic> pengaturan,
  ) => http.Response(
    jsonEncode({
      'status': 'success',
      'synced_riwayat': uuids,
      'pengaturan': pengaturan,
    }),
    200,
    headers: {'Content-Type': 'application/json'},
  );

  http.Response okPutResponse(Map<String, dynamic> pengaturan) => http.Response(
    jsonEncode({'status': 'success', 'pengaturan': pengaturan}),
    200,
    headers: {'Content-Type': 'application/json'},
  );

  Map<String, dynamic> serverPengaturan({
    required String terakhirDiperbarui,
    String tema = 'sistem',
    int ukuranTeks = 18,
    Map<String, String>? fieldTimestamps,
  }) => {
    'tema': tema,
    'ukuran_teks': ukuranTeks,
    'warna_kursor': '#FACC15',
    'kontras': 'normal',
    'otomatis_putar': true,
    'kecepatan_suara': 1.0,
    'bahasa_suara': 'id-ID',
    'bahasa_aplikasi': 'id',
    'terakhir_diperbarui': terakhirDiperbarui,
    'field_timestamps': ?fieldTimestamps,
  };

  Future<String> insertPending({int userId = 10}) async {
    await DatabaseHelper.instance.setCurrentUserId(userId);
    final id = await DatabaseHelper.instance.insertRiwayat(
      judul: 'Offline',
      isiTeks: 'Teks offline',
      jumlahKata: 2,
      sumber: 'kamera',
    );
    final row = await DatabaseHelper.instance.getRiwayatById(id);
    return row!['client_uuid'] as String;
  }

  bool isPut(http.BaseRequest request) =>
      request.method == 'PUT' && request.url.path.endsWith('/pengaturan');

  bool isSync(http.BaseRequest request) =>
      request.method == 'POST' && request.url.path.endsWith('/sync');

  test('1.Offline: tidak mengirim dan status tetap is_synch = 0', () async {
    final uuid = await insertPending();
    var called = false;
    final client = FakeClient((_) async {
      called = true;
      return okSyncResponse([uuid]);
    });
    final service = SyncService(
      authService: FakeAuthService(token: 'token', userId: 10),
      client: client,
      connectivity: FakeConnectivity([ConnectivityResult.none]),
    );

    final result = await service.syncPending();
    expect(result.success, isFalse);
    expect(called, isFalse);

    final rows = await DatabaseHelper.instance.getUnsyncedRiwayat();
    expect(rows.length, 1);
  });

  test('2.Sukses: UUID yang dikonfirmasi menjadi is_synch = 1', () async {
    final uuid = await insertPending();
    final client = FakeClient((_) async => okSyncResponse([uuid]));
    final service = SyncService(
      authService: FakeAuthService(token: 'token', userId: 10),
      client: client,
      connectivity: FakeConnectivity([ConnectivityResult.wifi]),
    );

    final result = await service.syncPending();
    expect(result.success, isTrue);
    expect(result.syncedCount, 1);
    expect(
      (await DatabaseHelper.instance.getUnsyncedRiwayat()).isEmpty,
      isTrue,
    );
  });

  test('3.Gagal (HTTP 500): status tetap is_synch = 0', () async {
    await insertPending();
    final client = FakeClient(
      (_) async => http.Response('{"message":"error"}', 500),
    );
    final service = SyncService(
      authService: FakeAuthService(token: 'token', userId: 10),
      client: client,
      connectivity: FakeConnectivity([ConnectivityResult.wifi]),
    );

    final result = await service.syncPending();
    expect(result.success, isFalse);
    expect((await DatabaseHelper.instance.getUnsyncedRiwayat()).length, 1);
  });

  test('4.Hanya UUID yang diakui server yang ditandai', () async {
    final uuidA = await insertPending();
    final uuidB = await insertPending();
    final client = FakeClient((_) async => okSyncResponse([uuidA]));
    final service = SyncService(
      authService: FakeAuthService(token: 'token', userId: 10),
      client: client,
      connectivity: FakeConnectivity([ConnectivityResult.wifi]),
    );

    await service.syncPending();
    final remaining = await DatabaseHelper.instance.getUnsyncedRiwayat();
    expect(remaining.length, 1);
    expect(remaining.first['client_uuid'], uuidB);
  });

  test(
    '5.Request riwayat tidak mengirim user_id dan memakai Bearer token',
    () async {
      await insertPending();
      final client = FakeClient((_) async => okSyncResponse([]));
      final service = SyncService(
        authService: FakeAuthService(token: 'rahasia-token', userId: 10),
        client: client,
        connectivity: FakeConnectivity([ConnectivityResult.mobile]),
      );

      await service.syncPending();
      final request = client.requests.singleWhere(isSync) as http.Request;
      final body = jsonDecode(request.body) as Map<String, dynamic>;

      expect(body.containsKey('user_id'), isFalse);
      expect(body.containsKey('riwayat'), isTrue);
      expect(body.containsKey('pengaturan'), isFalse);
      expect(request.headers['Authorization'], 'Bearer rahasia-token');
    },
  );

  test('6.Data user lain tidak ikut tersinkronisasi', () async {
    await insertPending(userId: 10);
    final uuidUserB = await insertPending(userId: 20);
    await DatabaseHelper.instance.setCurrentUserId(10);

    final client = FakeClient((_) async => okSyncResponse([]));
    final service = SyncService(
      authService: FakeAuthService(token: 'token', userId: 10),
      client: client,
      connectivity: FakeConnectivity([ConnectivityResult.wifi]),
    );
    await service.syncPending();

    final pendingB = await DatabaseHelper.instance.getUnsyncedRiwayat(
      userId: 20,
    );
    expect(pendingB.length, 1);
    expect(pendingB.first['client_uuid'], uuidUserB);
  });

  test('7.Data yang berubah saat sync tidak ikut ditandai', () async {
    final uuid = await insertPending();
    final db = await DatabaseHelper.instance.database;
    final client = FakeClient((_) async {
      // Simulasikan perubahan lokal ketika request sedang berjalan.
      await db.update(
        'tbl_riwayat',
        {'updated_at': DateTime.now().toIso8601String()},
        where: 'client_uuid = ?',
        whereArgs: [uuid],
      );
      return okSyncResponse([uuid]);
    });
    final service = SyncService(
      authService: FakeAuthService(token: 'token', userId: 10),
      client: client,
      connectivity: FakeConnectivity([ConnectivityResult.wifi]),
    );

    await service.syncPending();

    final pending = await DatabaseHelper.instance.getUnsyncedRiwayat();
    expect(pending.length, 1);
  });

  test('8.Mutex berlaku lintas instance SyncService', () async {
    final uuid = await insertPending();
    final requestStarted = Completer<void>();
    final releaseRequest = Completer<void>();

    final firstClient = FakeClient((_) async {
      if (!requestStarted.isCompleted) {
        requestStarted.complete();
      }
      await releaseRequest.future;
      return okSyncResponse([uuid]);
    });
    final firstService = SyncService(
      authService: FakeAuthService(token: 'token', userId: 10),
      client: firstClient,
      connectivity: FakeConnectivity([ConnectivityResult.wifi]),
    );

    final firstResult = firstService.syncPending();
    await requestStarted.future;

    var secondCalled = false;
    final secondClient = FakeClient((_) async {
      secondCalled = true;
      return okSyncResponse([uuid]);
    });
    final secondService = SyncService(
      authService: FakeAuthService(token: 'token', userId: 10),
      client: secondClient,
      connectivity: FakeConnectivity([ConnectivityResult.wifi]),
    );

    final blockedResult = await secondService.syncPending();
    expect(blockedResult.success, isFalse);
    expect(secondCalled, isFalse);

    releaseRequest.complete();
    expect((await firstResult).success, isTrue);
    expect(
      (await DatabaseHelper.instance.getUnsyncedRiwayat()).isEmpty,
      isTrue,
    );
  });

  test(
    '9.Pengaturan lokal dikirim lewat PUT lalu ditandai tersinkron',
    () async {
      const localTime = '2026-11-17T10:00:00.000000Z';
      await DatabaseHelper.instance.updatePengaturan({
        'tema': 'gelap',
      }, terakhirDiperbarui: localTime);

      final client = FakeClient((request) async {
        if (isPut(request)) {
          final body = jsonDecode(
            (request as http.Request).body,
          ) as Map<String, dynamic>;
          expect(body['tema'], 'gelap');
          expect(body.containsKey('user_id'), isFalse);
          return okPutResponse(
            serverPengaturan(
              terakhirDiperbarui: '2026-11-17T09:00:00.000000Z',
              tema: 'sistem',
            ),
          );
        }
        return okSyncResponse([]);
      });
      final service = SyncService(
        authService: FakeAuthService(token: 'token', userId: 10),
        client: client,
        connectivity: FakeConnectivity([ConnectivityResult.wifi]),
      );

      final result = await service.syncPending();
      expect(result.success, isTrue);
      expect(result.settingsSynced, isTrue);
      expect(client.requests.where(isPut).length, 1);

      final row = await DatabaseHelper.instance.getPengaturan();
      expect(row['tema'], 'gelap');
      expect(row['is_synch'], 1);
    },
  );

  test('10.Pengaturan server yang lebih baru menimpa lokal', () async {
    await DatabaseHelper.instance.updatePengaturan({
      'tema': 'lokal',
    }, terakhirDiperbarui: '2026-11-17T10:00:00.000000Z');

    final client = FakeClient((request) async {
      if (isPut(request)) {
        return okPutResponse(
          serverPengaturan(
            terakhirDiperbarui: '2026-11-17T11:00:00.000000Z',
            tema: 'server',
          ),
        );
      }
      return okSyncResponse([]);
    });
    final service = SyncService(
      authService: FakeAuthService(token: 'token', userId: 10),
      client: client,
      connectivity: FakeConnectivity([ConnectivityResult.wifi]),
    );

    await service.syncPending();

    final row = await DatabaseHelper.instance.getPengaturan();
    expect(row['tema'], 'server');
    expect(row['is_synch'], 1);
  });

  test(
    '11.Pengaturan bersih tidak dikirim dan menarik perubahan server',
    () async {
      const localTime = '2026-11-17T10:00:00.000000Z';
      await DatabaseHelper.instance.updatePengaturan({
        'tema': 'lokal',
      }, terakhirDiperbarui: localTime);
      await DatabaseHelper.instance.confirmPengaturanSynced(localTime);

      final client = FakeClient((request) async {
        if (isPut(request)) {
          fail('Pengaturan yang sudah tersinkron tidak boleh dikirim ulang');
        }
        return okSyncResponseWithPengaturan(
          [],
          serverPengaturan(
            terakhirDiperbarui: '2026-11-17T12:00:00.000000Z',
            tema: 'server-baru',
          ),
        );
      });
      final service = SyncService(
        authService: FakeAuthService(token: 'token', userId: 10),
        client: client,
        connectivity: FakeConnectivity([ConnectivityResult.wifi]),
      );

      await service.syncPending();

      final row = await DatabaseHelper.instance.getPengaturan();
      expect(row['tema'], 'server-baru');
      expect(row['is_synch'], 1);
    },
  );

  test('12.Baris pengaturan bawaan tidak dikirim ke server', () async {
    await DatabaseHelper.instance.getPengaturan();

    final client = FakeClient((request) async {
      if (isPut(request)) {
        fail('Baris bawaan tidak boleh menimpa pengaturan server');
      }
      return okSyncResponse([]);
    });
    final service = SyncService(
      authService: FakeAuthService(token: 'token', userId: 10),
      client: client,
      connectivity: FakeConnectivity([ConnectivityResult.wifi]),
    );

    await service.syncPending();

    expect(client.requests.where(isPut), isEmpty);
    expect(client.requests.where(isSync).length, 1);
  });

  test('13.Riwayat dibatasi 100 per batch sesuai validasi backend', () async {
    await DatabaseHelper.instance.setCurrentUserId(10);
    for (var i = 0; i < 105; i++) {
      await DatabaseHelper.instance.insertRiwayat(
        judul: 'Baris $i',
        isiTeks: 'Teks $i',
        jumlahKata: 2,
        sumber: 'kamera',
      );
    }

    List<String>? sentUuids;
    final client = FakeClient((request) async {
      if (isPut(request)) {
        return okPutResponse(
          serverPengaturan(terakhirDiperbarui: '2026-11-17T09:00:00Z'),
        );
      }
      final body =
          jsonDecode((request as http.Request).body) as Map<String, dynamic>;
      final riwayat = body['riwayat'] as List;
      expect(riwayat.length, SyncService.maxRiwayatPerBatch);
      sentUuids = riwayat
          .map(
            (item) => (item as Map<String, dynamic>)['client_uuid'] as String,
          )
          .toList();
      return okSyncResponse(sentUuids!);
    });
    final service = SyncService(
      authService: FakeAuthService(token: 'token', userId: 10),
      client: client,
      connectivity: FakeConnectivity([ConnectivityResult.wifi]),
    );

    await service.syncPending();

    final remaining = await DatabaseHelper.instance.getUnsyncedRiwayat(
      userId: 10,
    );
    expect(remaining.length, 5);
  });

  test('14.Respons akun lama tidak menandai data akun baru', () async {
    final uuidUserA = await insertPending(userId: 10);
    final uuidUserB = await insertPending(userId: 20);
    await DatabaseHelper.instance.setCurrentUserId(10);

    final client = FakeClient((request) async {
      if (isPut(request)) {
        return okPutResponse(
          serverPengaturan(terakhirDiperbarui: '2026-11-17T09:00:00Z'),
        );
      }
      // Pengguna berganti akun ketika request akun lama masih berjalan.
      await DatabaseHelper.instance.setCurrentUserId(20);
      return okSyncResponse([uuidUserA]);
    });
    final service = SyncService(
      authService: FakeAuthService(token: 'token', userId: 10),
      client: client,
      connectivity: FakeConnectivity([ConnectivityResult.wifi]),
    );

    await service.syncPending();

    final pendingB = await DatabaseHelper.instance.getUnsyncedRiwayat(
      userId: 20,
    );
    expect(pendingB.length, 1);
    expect(pendingB.first['client_uuid'], uuidUserB);

    final pendingA = await DatabaseHelper.instance.getUnsyncedRiwayat(
      userId: 10,
    );
    expect(pendingA, isEmpty);
  });

  test('15.Konflik pengaturan diselesaikan per-field, bukan per-baris', () async {
    const temaTime = '2026-11-17T10:00:00.000000Z';
    const ukuranTime = '2026-11-17T08:00:00.000000Z';

    await DatabaseHelper.instance.updatePengaturan({
      'tema': 'lokal-tema',
    }, terakhirDiperbarui: temaTime);
    await DatabaseHelper.instance.updatePengaturan({
      'ukuran_teks': 14,
    }, terakhirDiperbarui: ukuranTime);

    final serverTimes = <String, String>{
      for (final field in DatabaseHelper.syncedPengaturanFields)
        field: DatabaseHelper.baselineTimestamp,
      'tema': '2026-11-17T09:00:00.000000Z',
      'ukuran_teks': '2026-11-17T11:00:00.000000Z',
    };

    final client = FakeClient((request) async {
      if (isPut(request)) {
        final body =
            jsonDecode((request as http.Request).body) as Map<String, dynamic>;
        final sent = body['field_timestamps'] as Map<String, dynamic>;
        expect(sent['tema'], temaTime);
        expect(sent['ukuran_teks'], ukuranTime);
        return okPutResponse(
          serverPengaturan(
            terakhirDiperbarui: '2026-11-17T11:00:00.000000Z',
            tema: 'server-tema',
            ukuranTeks: 30,
            fieldTimestamps: serverTimes,
          ),
        );
      }
      return okSyncResponse([]);
    });
    final service = SyncService(
      authService: FakeAuthService(token: 'token', userId: 10),
      client: client,
      connectivity: FakeConnectivity([ConnectivityResult.wifi]),
    );

    await service.syncPending();

    final row = await DatabaseHelper.instance.getPengaturan();
    // Tema lokal (10:00) lebih baru dari server (09:00): nilai lokal menang.
    expect(row['tema'], 'lokal-tema');
    // Ukuran teks server (11:00) lebih baru dari lokal (08:00): server menang.
    expect(row['ukuran_teks'], 30);
  });

  test(
    '16.Pergantian akun saat request tetap memakai snapshot sesi awal',
    () async {
      final uuidA = await insertPending(userId: 10);
      final uuidB = await insertPending(userId: 20);
      await DatabaseHelper.instance.setCurrentUserId(10);

      final auth = MutableFakeAuthService(token: 'token-akun-10', userId: 10);
      final client = FakeClient((request) async {
        if (isPut(request)) {
          return okPutResponse(
            serverPengaturan(terakhirDiperbarui: '2026-11-17T09:00:00Z'),
          );
        }
        // Pengguna berganti akun ketika request akun lama masih berjalan.
        auth.token = 'token-akun-20';
        auth.userId = 20;
        return okSyncResponse([uuidA]);
      });
      final service = SyncService(
        authService: auth,
        client: client,
        connectivity: FakeConnectivity([ConnectivityResult.wifi]),
      );

      await service.syncPending();

      final syncRequest = client.requests.singleWhere(isSync) as http.Request;
      expect(syncRequest.headers['Authorization'], 'Bearer token-akun-10');

      expect(
        await DatabaseHelper.instance.getUnsyncedRiwayat(userId: 10),
        isEmpty,
      );
      final pendingB = await DatabaseHelper.instance.getUnsyncedRiwayat(
        userId: 20,
      );
      expect(pendingB.length, 1);
      expect(pendingB.first['client_uuid'], uuidB);
    },
  );

  test('17.Request gagal dapat diulang tanpa kehilangan data', () async {
    final uuid = await insertPending();
    var attempts = 0;

    final client = FakeClient((request) async {
      if (isPut(request)) {
        return okPutResponse(
          serverPengaturan(terakhirDiperbarui: '2026-11-17T09:00:00Z'),
        );
      }
      attempts++;
      if (attempts == 1) {
        return http.Response('{"message":"error"}', 500);
      }
      return okSyncResponse([uuid]);
    });
    final service = SyncService(
      authService: FakeAuthService(token: 'token', userId: 10),
      client: client,
      connectivity: FakeConnectivity([ConnectivityResult.wifi]),
    );

    final first = await service.syncPending();
    expect(first.success, isFalse);
    expect((await DatabaseHelper.instance.getUnsyncedRiwayat()).length, 1);

    final second = await service.syncPending();
    expect(second.success, isTrue);
    expect(await DatabaseHelper.instance.getUnsyncedRiwayat(), isEmpty);

    final bodies = client.requests
        .where(isSync)
        .map((request) => (request as http.Request).body)
        .toList();
    expect(bodies.length, 2);
    expect(
      (jsonDecode(bodies.last)
          as Map<String, dynamic>)['riwayat'][0]['client_uuid'],
      uuid,
    );
  });

  test('18.Baseline hasil reassignment tidak dikirim ke server', () async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('tbl_pengaturan');
    DatabaseHelper.instance.clearCurrentUser();

    // Baseline bawaan seperti saat aplikasi pertama kali dibuka.
    await DatabaseHelper.instance.getPengaturan();
    await DatabaseHelper.instance.setCurrentUserId(10);

    final client = FakeClient((request) async {
      if (isPut(request)) {
        fail('Pengaturan baseline tidak boleh dikirim ke server');
      }
      return okSyncResponse([]);
    });
    final service = SyncService(
      authService: FakeAuthService(token: 'token', userId: 10),
      client: client,
      connectivity: FakeConnectivity([ConnectivityResult.wifi]),
    );

    await service.syncPending();

    expect(client.requests.where(isPut), isEmpty);
    final row = await DatabaseHelper.instance.getPengaturan();
    expect(row['is_synch'], 1);
    expect(row['terakhir_diperbarui'], DatabaseHelper.baselineTimestamp);
  });

  test(
    '19.Pengaturan pending valid tetap dikirim setelah reassignment',
    () async {
      const changedAt = '2026-11-17T10:00:00.000000Z';
      final db = await DatabaseHelper.instance.database;
      await db.delete('tbl_pengaturan');
      DatabaseHelper.instance.clearCurrentUser();

      await DatabaseHelper.instance.updatePengaturan(
        {'tema': 'gelap'},
        terakhirDiperbarui: changedAt,
        userId: DatabaseHelper.legacyUserId,
      );
      await DatabaseHelper.instance.setCurrentUserId(10);

      Map<String, dynamic>? sentBody;
      final client = FakeClient((request) async {
        if (isPut(request)) {
          sentBody = jsonDecode(
            (request as http.Request).body,
          ) as Map<String, dynamic>;
          return okPutResponse(
            serverPengaturan(terakhirDiperbarui: changedAt, tema: 'gelap'),
          );
        }
        return okSyncResponse([]);
      });
      final service = SyncService(
        authService: FakeAuthService(token: 'token', userId: 10),
        client: client,
        connectivity: FakeConnectivity([ConnectivityResult.wifi]),
      );

      await service.syncPending();

      expect(sentBody, isNotNull);
      final timestamps = sentBody!['field_timestamps'] as Map<String, dynamic>;
      expect(timestamps['tema'], changedAt);
      expect(sentBody!['terakhir_diperbarui'], changedAt);
      expect(client.requests.where(isPut).length, 1);

      final row = await DatabaseHelper.instance.getPengaturan();
      expect(row['tema'], 'gelap');
      expect(row['is_synch'], 1);
    },
  );
}
