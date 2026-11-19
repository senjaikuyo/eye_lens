import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_strings.dart';
import '../../main.dart';
import '../../models/ocr_element.dart';
import '../../providers/history_provider.dart';
import '../../providers/display_preferences_provider.dart';
import '../../services/camera_lifecycle_manager.dart';
import '../../services/camera_service.dart';
import '../../services/hardware_key_service.dart';
import '../../services/ocr_service.dart';
import '../../services/image_blur_detector.dart';
import '../../services/image_cache_cleanup.dart';
import '../../services/ocr_text_validator.dart';
import '../../services/tts_service.dart';
import '../../widgets/zoom_ruler.dart';
import '../../utils/image_dimension_helper.dart';
import '../speech/speech_screen.dart';
import 'widgets/blur_warning_banner.dart';
import 'widgets/camera_viewfinder.dart';
import 'widgets/no_text_alert_banner.dart';
import 'widgets/ocr_processing_overlay.dart';
import 'widgets/scan_bottom_bar.dart';
import 'widgets/scan_top_bar.dart';
import 'widgets/zoom_pill_indicator.dart';

class ScanningScreen extends StatefulWidget {
  const ScanningScreen({super.key});

  @override
  State<ScanningScreen> createState() => _ScanningScreenState();
}

class _ScanningScreenState extends State<ScanningScreen>
    with RouteAware, WidgetsBindingObserver {
  final CameraService _cameraService = CameraService();
  final OcrService _ocrService = OcrService();
  final ImagePicker _imagePicker = ImagePicker();
  final HardwareKeyService _hardwareKeyService = HardwareKeyService();
  final TtsService _ttsService = TtsService();

  bool _isSubscribedToRouteObserver = false;
  bool _isFlashOn = false;
  double _currentZoom = 1.0;
  bool _isBlurry = false;
  bool _isProcessingOcr = false;
  Timer? _blurTimer;

  bool _isNoTextAlertVisible = false;
  String _noTextTitle = '';
  String _noTextMessage = '';
  Timer? _noTextAlertTimer;

  static const double _minZoom = 1.0;
  static const double _maxZoom = 10.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cameraService.lifecycle.addListener(_onCameraLifecycleChanged);

    _initCamera();
    _hardwareKeyService.startListening(() {
      if (mounted && !_isProcessingOcr && _cameraService.isInitialized) {
        _onCapturePressed();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isSubscribedToRouteObserver) {
      final route = ModalRoute.of(context);
      if (route is PageRoute) {
        routeObserver.subscribe(this, route);
        _isSubscribedToRouteObserver = true;
      }
    }
  }

  @override
  void didPushNext() {
    // Saat berpindah rute ke halaman lain (misal SpeechScreen), matikan kamera sepenuhnya
    _cameraService.stop();
  }

  @override
  void didPopNext() {
    // Saat kembali ke ScanningScreen dari halaman lain, nyalakan kamera kembali
    _cameraService.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // Saat aplikasi berada di background / lockscreen, lepaskan hardware kamera
      _cameraService.stop();
    } else if (state == AppLifecycleState.resumed) {
      // Hanya nyalakan kamera jika ScanningScreen adalah rute teratas yang sedang aktif
      final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? false;
      if (isCurrentRoute) {
        _cameraService.start();
      }
    }
  }

  void _onCameraLifecycleChanged() {
    if (!mounted) return;
    setState(() {
      _currentZoom = _cameraService.currentZoom;
      _isFlashOn = _cameraService.isFlashOn;
    });
  }

  Future<void> _initCamera() async {
    final success = await _cameraService.initialize();
    if (success && mounted) {
      setState(() {
        _currentZoom = _cameraService.currentZoom;
      });
    }
  }

  @override
  void dispose() {
    if (_isSubscribedToRouteObserver) {
      routeObserver.unsubscribe(this);
    }
    WidgetsBinding.instance.removeObserver(this);
    _cameraService.lifecycle.removeListener(_onCameraLifecycleChanged);

    _hardwareKeyService.stopListening();
    _blurTimer?.cancel();
    _noTextAlertTimer?.cancel();
    _cameraService.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  Future<void> _showNoTextAlert({
    required String title,
    required String message,
  }) async {
    _noTextAlertTimer?.cancel();
    if (!mounted) return;

    setState(() {
      _noTextTitle = title;
      _noTextMessage = message;
      _isNoTextAlertVisible = true;
    });

    HapticFeedback.mediumImpact();

    final isIndo = AppStrings.of(context, listen: false).isIndonesian;
    final fullSpokenText = '$title. $message';

    SemanticsService.sendAnnouncement(
      View.of(context),
      fullSpokenText,
      TextDirection.ltr,
    );

    try {
      await _ttsService.stop();
      await _ttsService.setLanguage(isIndo ? 'id-ID' : 'en-US');
      await _ttsService.speak(fullSpokenText);
    } catch (e) {
      debugPrint('[ScanningScreen] TTS no-text alert failed: $e');
    }

    _noTextAlertTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isNoTextAlertVisible = false;
        });
      }
    });
  }

  void _dismissNoTextAlert() {
    _noTextAlertTimer?.cancel();
    if (_isNoTextAlertVisible && mounted) {
      setState(() {
        _isNoTextAlertVisible = false;
      });
    }
  }

  void _updateZoom(double newZoom) {
    final clamped = newZoom.clamp(_minZoom, _maxZoom);
    if ((clamped - _currentZoom).abs() > 0.01) {
      setState(() {
        _currentZoom = clamped;
      });
      _cameraService.setZoom(clamped);
    }
  }

  void _triggerBlurAlert(AppStrings strings) {
    _blurTimer?.cancel();
    setState(() {
      _isBlurry = true;
    });

    HapticFeedback.heavyImpact();

    SemanticsService.sendAnnouncement(
      View.of(context),
      strings.imageBlurryAlert,
      TextDirection.ltr,
    );

    _blurTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _isBlurry = false;
        });
      }
    });
  }

  Future<void> _onCapturePressed() async {
    if (_isProcessingOcr || !_cameraService.isInitialized) return;

    _dismissNoTextAlert();
    HapticFeedback.mediumImpact();

    if (_cameraService.isInitialized) {
      setState(() {
        _isProcessingOcr = true;
      });

      try {
        final bytes = await _cameraService.captureFrameToRAM();
        if (bytes == null || !mounted) {
          setState(() {
            _isProcessingOcr = false;
          });
          return;
        }

        // Matikan sensor kamera secepatnya setelah citra aman di RAM
        // agar lampu indikator kamera padam dan baterai terlindungi
        await _cameraService.stop();

        final ocrResult = await _ocrService.processImageWithCoordinates(
          bytes,
          captureMetadata: _cameraService.lastCaptureMetadata,
        );
        final check = OcrTextValidator.validateResult(ocrResult);

        if (!mounted) return;

        if (!check.hasText) {
          setState(() {
            _isProcessingOcr = false;
          });
          // Hidupkan kamera kembali karena masih berada di ScanningScreen
          _cameraService.start();
          final strings = AppStrings.of(context, listen: false);
          await _showNoTextAlert(
            title: check.getAlertTitle(strings),
            message: check.getAlertInstruction(strings),
          );
        } else {
          final finalText = check.text;

          if (mounted) {
            _checkAndShowLowQualityWarning(ocrResult);

            // Simpan hasil pemindaian langsung ke SQLite
            await context.read<HistoryProvider>().addRiwayat(
              text: finalText,
              sumber: 'kamera',
            );

            if (!mounted) return;

            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => SpeechScreen(
                  text: finalText,
                  hasImage: true,
                  imageBytes: bytes, // Mengirim citra foto asli
                  ocrResult: ocrResult,
                ),
              ),
            );

            // K0: tampilkan tombol salin log diagnostik (hanya build debug).
            _maybeShowDiagnosticSnackBar(ocrResult);
          }
        }
      } catch (e) {
        debugPrint('[ScanningScreen] Tangkap & OCR gagal: $e');
        if (mounted) {
          _cameraService.start();
        }
      } finally {
        if (mounted) {
          setState(() {
            _isProcessingOcr = false;
          });
        }
      }
    } else {
      // Alur fallback / simulasi (misal di simulator tanpa sensor kamera)
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const SpeechScreen(
            text: 'yesterday\ntoday\ntomorrow',
            hasImage: false,
            imageBytes: null,
          ),
        ),
      );
    }
  }

  Future<void> _onGalleryPressed() async {
    if (_isProcessingOcr) return;

    _dismissNoTextAlert();
    HapticFeedback.selectionClick();

    // Hentikan kamera saat pengguna membuka pemilih gambar galeri
    await _cameraService.stop();

    XFile? pickedFile;
    try {
      pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery);

      if (pickedFile == null || !mounted) {
        // Jika pengguna batal memilih dari galeri, nyalakan kembali kamera
        _cameraService.start();
        return;
      }

      setState(() {
        _isProcessingOcr = true;
      });

      // Picker returns an app-cache copy, not the original gallery asset.
      final original = await pickedFile.readAsBytes();
      final originalSize = await ImageDimensionHelper.getImageSize(original);
      final bytes = await ImageBlurDetector.boundGalleryImage(original);
      final ocrResult = await _ocrService.processImageWithCoordinates(
        bytes,
        captureMetadata: {
          'source': 'gallery',
          'originalWidth': originalSize.width,
          'originalHeight': originalSize.height,
          'resizedForMemoryBudget': !identical(original, bytes),
        },
      );
      final check = OcrTextValidator.validateResult(ocrResult);

      if (!mounted) return;

      if (!check.hasText) {
        setState(() {
          _isProcessingOcr = false;
        });
        // Nyalakan kembali kamera karena pemindaian galeri tidak menghasilkan teks
        _cameraService.start();
        final strings = AppStrings.of(context, listen: false);
        await _showNoTextAlert(
          title: check.getAlertTitle(strings),
          message: check.getAlertInstruction(strings),
        );
      } else {
        final extractedText = check.text;
        _checkAndShowLowQualityWarning(ocrResult);

        // Simpan hasil pemindaian galeri langsung ke SQLite
        await context.read<HistoryProvider>().addRiwayat(
          text: extractedText,
          sumber: 'galeri',
        );

        if (!mounted) return;

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SpeechScreen(
              text: extractedText,
              hasImage: true,
              imageBytes: bytes,
              ocrResult: ocrResult,
            ),
          ),
        );

        // K0: tampilkan tombol salin log diagnostik (hanya build debug).
        _maybeShowDiagnosticSnackBar(ocrResult);
      }
    } catch (e) {
      debugPrint('[ScanningScreen] Ambil gambar galeri gagal: $e');
      if (mounted) {
        _cameraService.start();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppStrings.of(context).isIndonesian
                  ? 'Gagal memuat gambar dari galeri.'
                  : 'Failed to pick image from gallery.',
              style: const TextStyle(fontSize: 16),
            ),
            backgroundColor: AppColors.black,
          ),
        );
      }
    } finally {
      if (pickedFile != null) {
        try {
          await ImageCacheCleanup.delete(pickedFile.path);
        } catch (e) {
          debugPrint(
            '[ScanningScreen] Gallery cache cleanup failed: ${e.runtimeType}',
          );
        }
      }
      if (mounted) {
        setState(() {
          _isProcessingOcr = false;
        });
      }
    }
  }

  /// K0: Menampilkan aksi "Salin log (JSON)" setelah pemindaian pada build
  /// debug. Dua pilihan: dengan teks atau tanpa teks. Tidak tampil di release.
  void _maybeShowDiagnosticSnackBar(OcrResult ocrResult) {
    final json = ocrResult.diagnosticJson;
    if (json == null || !kDebugMode || !mounted) return;

    final strings = AppStrings.of(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 10),
        content: Text(
          strings.isIndonesian
              ? 'Log diagnostik OCR siap.'
              : 'OCR diagnostic log is ready.',
          style: const TextStyle(fontSize: 16),
        ),
        action: SnackBarAction(
          label: strings.isIndonesian ? 'Salin log' : 'Copy log',
          onPressed: () => _showDiagnosticCopySheet(json),
        ),
      ),
    );
  }

  /// K0: Lembar pilihan salin log dengan/tanpa isi teks.
  Future<void> _showDiagnosticCopySheet(String withTextJson) async {
    if (!mounted) return;
    final strings = AppStrings.of(context, listen: false);

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.copy_all_outlined),
                title: Text(
                  strings.isIndonesian
                      ? 'Salin log + teks'
                      : 'Copy log with text',
                ),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: withTextJson));
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: Text(
                  strings.isIndonesian
                      ? 'Salin log tanpa teks'
                      : 'Copy log without text',
                ),
                subtitle: Text(
                  strings.isIndonesian
                      ? 'Hanya metrik, isi teks disensor'
                      : 'Metrics only, text content redacted',
                ),
                onTap: () async {
                  final sanitized = _stripTextFromDiagnosticJson(withTextJson);
                  await Clipboard.setData(ClipboardData(text: sanitized));
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Menghapus isi teks dari JSON diagnostik (mempertahankan panjangnya).
  String _stripTextFromDiagnosticJson(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final texts = decoded['texts'];
      if (texts is Map) {
        decoded['texts'] = {
          'rawLength': (texts['raw'] as String?)?.length ?? 0,
          'filteredLength': (texts['filtered'] as String?)?.length ?? 0,
          'formattedLength': (texts['formatted'] as String?)?.length ?? 0,
        };
      }
      for (final key in ['rejectedLines', 'doubtfulLines']) {
        final entries = decoded[key];
        if (entries is! List) continue;
        for (final item in entries) {
          if (item is Map) {
            item['text'] = '<disembunyikan>';
            item['explanation'] = '<disembunyikan>';
          }
        }
      }
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (e) {
      debugPrint('[ScanningScreen] Gagal menyensor log diagnostik: $e');
      return '{"error":"diagnostic_redaction_failed"}';
    }
  }

  void _checkAndShowLowQualityWarning(OcrResult ocrResult) {
    if (ocrResult.hasLowQualityWarning && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.of(context).isIndonesian
                ? 'Gambar kurang jelas, teks mungkin kurang akurat.'
                : 'Image is unclear, text may be less accurate.',
            style: const TextStyle(fontSize: 16),
          ),
          backgroundColor: const Color(0xFFE58E1B),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final strings = AppStrings.of(context);
    final themeProvider = context.watch<DisplayPreferencesProvider>();
    final isDark = themeProvider.isDark(context);

    final isCameraStarting = _cameraService.status == CameraStatus.starting;
    final isCameraError = _cameraService.status == CameraStatus.error;

    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Viewfinder Kamera dengan gesture pinch & swipe zoom, loading, dan error banner
          CameraViewfinder(
            cameraService: _cameraService,
            currentZoom: _currentZoom,
            onZoomChanged: _updateZoom,
            isBlurry: _isBlurry,
            size: size,
            isInitializing: isCameraStarting,
            errorMessage: isCameraError ? strings.cameraInitError : null,
            initializingText: strings.cameraInitializing,
            retryText: strings.retry,
            onRetry: () => _cameraService.start(),
          ),

          // 2. Top Action Bar: Flash, History, dan Popup Menu
          ScanTopBar(
            topPadding: topPadding,
            isFlashOn: _isFlashOn,
            onToggleFlash: () async {
              final status = await _cameraService.toggleFlash();
              setState(() {
                _isFlashOn = status;
              });
            },
            isDark: isDark,
            strings: strings,
          ),

          // 3. Slider Zoom Vertikal di Kanan Tengah
          Positioned(
            right: 0,
            top: (size.height - 190) / 2,
            child: ZoomRuler(
              currentZoom: _currentZoom,
              minZoom: _minZoom,
              maxZoom: _maxZoom,
              onZoomChanged: _updateZoom,
            ),
          ),

          // 4. Indikator Nilai Zoom di Tengah Bawah
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomPadding + 180,
            child: ZoomPillIndicator(
              currentZoom: _currentZoom,
              onTap: () => _updateZoom(1.0),
            ),
          ),

          // 5. Floating Blur Warning Alert Banner
          BlurWarningBanner(
            isVisible: _isBlurry,
            bottomPadding: bottomPadding,
            message: strings.imageBlurryAlert,
          ),

          // 5b. Floating No-Text Alert Banner di atas tombol rana
          NoTextAlertBanner(
            isVisible: _isNoTextAlertVisible,
            bottomPadding: bottomPadding,
            title: _noTextTitle,
            message: _noTextMessage,
            onClose: _dismissNoTextAlert,
            closeLabel: strings.close,
          ),

          // 6. Bottom Controls: Galeri & Shutter
          ScanBottomBar(
            bottomPadding: bottomPadding,
            galleryText: strings.gallery,
            onGalleryPressed: _onGalleryPressed,
            onCapturePressed: _onCapturePressed,
            onCaptureLongPressed: () => _triggerBlurAlert(strings),
            isProcessing: _isProcessingOcr,
            isReady: _cameraService.isInitialized,
          ),

          // 7. OCR Processing Overlay
          if (_isProcessingOcr) OcrProcessingOverlay(strings: strings),
        ],
      ),
    );
  }
}
