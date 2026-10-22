import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:eye_lens/services/camera_lifecycle_manager.dart';

void main() {
  group('CameraLifecycleManager Unit Tests', () {
    test('1. Urutan normal: start() berhasil lalu stop()', () async {
      int startCount = 0;
      int stopCount = 0;

      final manager = CameraLifecycleManager(
        onStart: () async {
          startCount++;
          return true;
        },
        onStop: () async {
          stopCount++;
        },
      );

      expect(manager.status, CameraStatus.idle);
      expect(manager.isIdle, isTrue);

      final startFuture = manager.start();
      expect(manager.status, CameraStatus.starting);
      expect(manager.isStarting, isTrue);

      final success = await startFuture;
      expect(success, isTrue);
      expect(manager.status, CameraStatus.ready);
      expect(manager.isReady, isTrue);
      expect(startCount, 1);

      final stopFuture = manager.stop();
      expect(manager.status, CameraStatus.stopping);
      expect(manager.isStopping, isTrue);

      await stopFuture;
      expect(manager.status, CameraStatus.idle);
      expect(manager.isIdle, isTrue);
      expect(stopCount, 1);
    });

    test('2. stop() saat belum start (status idle) tidak memicu onStop', () async {
      int stopCount = 0;
      final manager = CameraLifecycleManager(
        onStart: () async => true,
        onStop: () async {
          stopCount++;
        },
      );

      await manager.stop();
      expect(manager.status, CameraStatus.idle);
      expect(stopCount, 0);
    });

    test('3. start() dua kali berturut-turut tidak mengeksekusi onStart ganda', () async {
      int startCount = 0;
      final manager = CameraLifecycleManager(
        onStart: () async {
          startCount++;
          await Future.delayed(const Duration(milliseconds: 30));
          return true;
        },
        onStop: () async {},
      );

      final f1 = manager.start();
      final f2 = manager.start();

      final results = await Future.wait([f1, f2]);
      expect(results[0], isTrue);
      expect(results[1], isTrue);
      expect(startCount, 1);
      expect(manager.isReady, isTrue);
    });

    test('4. stop() dipanggil saat start() sedang berjalan langsung menghentikan kamera', () async {
      int startCount = 0;
      int stopCount = 0;
      final startCompleter = Completer<bool>();

      final manager = CameraLifecycleManager(
        onStart: () async {
          startCount++;
          return await startCompleter.future;
        },
        onStop: () async {
          stopCount++;
        },
      );

      final startFuture = manager.start();
      expect(manager.isStarting, isTrue);

      final stopFuture = manager.stop();

      // Selesaikan start di latar belakang
      startCompleter.complete(true);

      await Future.wait([startFuture, stopFuture]);

      expect(startCount, 1);
      expect(stopCount, 1);
      expect(manager.status, CameraStatus.idle);
    });

    test('5. start() dipanggil saat stop() sedang berjalan menunggu stop selesai lalu start lagi', () async {
      int startCount = 0;
      int stopCount = 0;
      final stopCompleter = Completer<void>();

      final manager = CameraLifecycleManager(
        onStart: () async {
          startCount++;
          return true;
        },
        onStop: () async {
          stopCount++;
          await stopCompleter.future;
        },
      );

      await manager.start();
      expect(manager.isReady, isTrue);

      final stopFuture = manager.stop();
      expect(manager.isStopping, isTrue);

      final restartFuture = manager.start();

      stopCompleter.complete();
      await stopFuture;
      final restartSuccess = await restartFuture;

      expect(restartSuccess, isTrue);
      expect(startCount, 2);
      expect(stopCount, 1);
      expect(manager.isReady, isTrue);
    });

    test('6. Inisialisasi onStart yang gagal atau melempar exception menghasilkan status error', () async {
      final manager = CameraLifecycleManager(
        onStart: () async {
          throw Exception('Kamera dipakai aplikasi lain');
        },
        onStop: () async {},
      );

      final success = await manager.start();
      expect(success, isFalse);
      expect(manager.status, CameraStatus.error);
      expect(manager.isError, isTrue);
      expect(manager.errorMessage, contains('Kamera dipakai aplikasi lain'));
    });
  });
}
