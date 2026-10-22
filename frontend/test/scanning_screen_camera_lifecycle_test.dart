import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eye_lens/core/app_strings.dart';
import 'package:eye_lens/screens/scan/widgets/camera_viewfinder.dart';
import 'package:eye_lens/screens/scan/widgets/scan_bottom_bar.dart';
import 'package:eye_lens/services/camera_lifecycle_manager.dart';
import 'package:eye_lens/services/camera_service.dart';

void main() {
  group('Camera Viewfinder & Controls Lifecycle UI Tests', () {
    testWidgets('1. Menampilkan indikator loading saat kamera sedang starting', (
      tester,
    ) async {
      final cameraService = CameraService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CameraViewfinder(
              cameraService: cameraService,
              currentZoom: 1.0,
              onZoomChanged: (_) {},
              isBlurry: false,
              size: const Size(400, 800),
              isInitializing: true,
              initializingText: 'Menyiapkan kamera...',
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Menyiapkan kamera...'), findsOneWidget);
    });

    testWidgets('2. Menampilkan pesan error dan tombol coba lagi saat kamera gagal', (
      tester,
    ) async {
      final cameraService = CameraService();
      bool retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CameraViewfinder(
              cameraService: cameraService,
              currentZoom: 1.0,
              onZoomChanged: (_) {},
              isBlurry: false,
              size: const Size(400, 800),
              isInitializing: false,
              errorMessage:
                  'Kamera gagal diinisialisasi. Pastikan izin kamera aktif.',
              retryText: 'Coba Lagi',
              onRetry: () {
                retried = true;
              },
            ),
          ),
        ),
      );

      expect(
        find.text('Kamera gagal diinisialisasi. Pastikan izin kamera aktif.'),
        findsOneWidget,
      );
      expect(find.text('Coba Lagi'), findsOneWidget);

      await tester.tap(find.text('Coba Lagi'));
      await tester.pump();
      expect(retried, isTrue);
    });

    testWidgets('3. Tombol rana kamera dinonaktifkan saat isReady false', (
      tester,
    ) async {
      bool capturePressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                ScanBottomBar(
                  bottomPadding: 0,
                  galleryText: 'Galeri',
                  onGalleryPressed: () {},
                  onCapturePressed: () {
                    capturePressed = true;
                  },
                  onCaptureLongPressed: () {},
                  isReady: false,
                ),
              ],
            ),
          ),
        ),
      );

      final shutterIcon = find.byIcon(Icons.camera_alt_outlined);
      expect(shutterIcon, findsOneWidget);

      await tester.tap(shutterIcon);
      await tester.pump();
      expect(capturePressed, isFalse);
    });

    testWidgets('4. Tombol rana kamera aktif saat isReady true', (
      tester,
    ) async {
      bool capturePressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                ScanBottomBar(
                  bottomPadding: 0,
                  galleryText: 'Galeri',
                  onGalleryPressed: () {},
                  onCapturePressed: () {
                    capturePressed = true;
                  },
                  onCaptureLongPressed: () {},
                  isReady: true,
                ),
              ],
            ),
          ),
        ),
      );

      final shutterIcon = find.byIcon(Icons.camera_alt_outlined);
      await tester.tap(shutterIcon);
      await tester.pump();
      expect(capturePressed, isTrue);
    });
  });
}
