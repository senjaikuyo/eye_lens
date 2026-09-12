import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/haptic_helper.dart';
import '../providers/camera_provider.dart';
import '../providers/settings_provider.dart';
import 'history_screen.dart';
import 'preview_screen.dart';
import 'settings_screen.dart';
import 'widgets/glass_button.dart';
import 'widgets/glass_container.dart';
import 'widgets/reading_guide_overlay.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CameraProvider>(context, listen: false).initCamera();
      _focusNode.requestFocus();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cameraProvider = Provider.of<CameraProvider>(context, listen: false);
    if (!cameraProvider.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      // release camera
    } else if (state == AppLifecycleState.resumed) {
      cameraProvider.initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleCapture() async {
    final cameraProvider = Provider.of<CameraProvider>(context, listen: false);
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    HapticHelper.mediumImpact(enabled: settings.settings.umpanBalikGetar);
    final path = await cameraProvider.capturePhoto();
    if (path != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PreviewScreen(imagePath: path),
        ),
      );
    }
  }

  Future<void> _handlePickGallery() async {
    final cameraProvider = Provider.of<CameraProvider>(context, listen: false);
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    HapticHelper.lightImpact(enabled: settings.settings.umpanBalikGetar);
    final path = await cameraProvider.pickFromGallery();
    if (path != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PreviewScreen(imagePath: path),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cameraProvider = Provider.of<CameraProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isDark = settingsProvider.isDarkMode;
    final fontMultiplier = settingsProvider.settings.fontSizeMultiplier;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        // Intersep tombol volume untuk shutter fisik
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.audioVolumeUp ||
              event.logicalKey == LogicalKeyboardKey.audioVolumeDown) {
            _handleCapture();
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Live Camera Viewfinder
            if (cameraProvider.isInitialized && cameraProvider.service.controller != null)
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: cameraProvider.service.controller!.value.previewSize?.height ?? 1080,
                    height: cameraProvider.service.controller!.value.previewSize?.width ?? 1920,
                    child: CameraPreview(cameraProvider.service.controller!),
                  ),
                ),
              )
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppColors.accentYellow),
                    const SizedBox(height: 16),
                    Text(
                      'Menyiapkan Kamera...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18 * fontMultiplier,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

            // 2. Reading Guide Line (Garis Pembimbing Baca)
            ReadingGuideOverlay(
              isVisible: settingsProvider.settings.garisPanduanAktif,
              windowHeight: 100.0,
            ),

            // 3. Header Kaca Atas (Flash & Riwayat)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Atas Kiri: Flash On/Off
                      GlassButton(
                        minSize: 52,
                        borderRadius: 18,
                        onTap: () => cameraProvider.toggleFlash(),
                        icon: Icon(
                          cameraProvider.isFlashOn ? Icons.flash_on : Icons.flash_off,
                          color: cameraProvider.isFlashOn
                              ? AppColors.accentYellow
                              : (isDark ? Colors.white : AppColors.lightTextPrimary),
                          size: 26,
                        ),
                      ),

                      // Status Privasi Kaca Melayang (Tengah)
                      Flexible(
                        child: GlassContainer(
                          borderRadius: 20,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.accentGreen,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Foto Tidak Disimpan',
                                  style: TextStyle(
                                    fontSize: 12 * fontMultiplier,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Atas Kanan: Tombol Riwayat
                      GlassButton(
                        minSize: 52,
                        borderRadius: 18,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const HistoryScreen()),
                          );
                        },
                        icon: Icon(
                          Icons.history_rounded,
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 4. Kontrol Zoom Kanan (+ dan -) & Badge
            Positioned(
              right: 16,
              top: MediaQuery.of(context).size.height * 0.32,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GlassButton(
                    minSize: 56,
                    borderRadius: 18,
                    onTap: () => cameraProvider.zoomIn(),
                    icon: const Icon(Icons.add, size: 28, color: AppColors.accentBlue),
                  ),
                  const SizedBox(height: 8),
                  GlassContainer(
                    borderRadius: 14,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text(
                      '${cameraProvider.currentZoom.toStringAsFixed(1)}x',
                      style: TextStyle(
                        fontSize: 14 * fontMultiplier,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GlassButton(
                    minSize: 56,
                    borderRadius: 18,
                    onTap: () => cameraProvider.zoomOut(),
                    icon: const Icon(Icons.remove, size: 28, color: AppColors.accentBlue),
                  ),
                ],
              ),
            ),

            // 5. Bilah Bawah (Google Lens Layout: Galeri | Shutter | Pengaturan)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Bawah Kiri: Unggah Galeri
                      GlassButton(
                        minSize: 58,
                        borderRadius: 22,
                        onTap: _handlePickGallery,
                        icon: Icon(
                          Icons.photo_library_outlined,
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                          size: 28,
                        ),
                      ),

                      // Bawah Tengah: Shutter Pindai Utama Raksasa (78x78 dp)
                      GestureDetector(
                        onTap: _handleCapture,
                        child: Container(
                          width: 82,
                          height: 82,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.3),
                            border: Border.all(
                              color: Colors.white,
                              width: 4.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.35),
                                blurRadius: 18,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: 66,
                              height: 66,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                              child: cameraProvider.isTakingPhoto
                                  ? const Center(
                                      child: CircularProgressIndicator(
                                        color: AppColors.accentBlue,
                                        strokeWidth: 3,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 36,
                                      color: AppColors.lightTextPrimary,
                                    ),
                            ),
                          ),
                        ),
                      ),

                      // Bawah Kanan: Pengaturan
                      GlassButton(
                        minSize: 58,
                        borderRadius: 22,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SettingsScreen()),
                          );
                        },
                        icon: Icon(
                          Icons.settings_outlined,
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
