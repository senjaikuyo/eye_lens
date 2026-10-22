import '../services/lens_selection_helper.dart';

/// Jenis pemicu perubahan bingkai seleksi pada layar OCR.
enum FrameChangeTrigger {
  /// Ketukan pada kelompok teks tertentu (cluster tap).
  tapCluster,

  /// Menggeser/menyeret seluruh bingkai seleksi.
  moveFrame,

  /// Menyeret titik pegangan (handle resize) bingkai seleksi.
  dragHandle,

  /// Menekan tombol "Full image" untuk mereset bingkai ke seluruh gambar.
  fullImage,

  /// Transformasi zoom atau pan pada citra latar.
  zoomPan,

  /// Inisialisasi awal saat layar gambar pertama kali dimuat.
  initialLoad,
}

/// Keputusan tindakan pemutaran suara TTS setelah perubahan bingkai selesai dihitung.
enum AutoPlayDecision {
  /// Membaca teks di dalam bingkai baru secara otomatis.
  speak,

  /// Hanya menyiapkan teks dan memetakan kata tanpa membacanya.
  prepareOnly,

  /// Menampilkan peringatan merah dan suara teks tidak ditemukan.
  alertNoText,
}

/// Helper fungsi murni untuk mengevaluasi keputusan pemutaran otomatis suara TTS.
class AutoPlayHelper {
  const AutoPlayHelper._();

  /// Menentukan apakah teks di dalam bingkai baru harus dibaca otomatis,
  /// hanya disiapkan, atau memicu alert teks tidak ditemukan.
  ///
  /// Aturan:
  /// 1. Pembacaan otomatis HANYA berlaku jika [trigger] adalah [FrameChangeTrigger.tapCluster].
  /// 2. Pemicu lain (moveFrame, dragHandle, fullImage, zoomPan, initialLoad) selalu [AutoPlayDecision.prepareOnly].
  /// 3. Jika sakelar [autoPlayEnabled] mati (false), ketukan kelompok teks mengembalikan [AutoPlayDecision.prepareOnly].
  /// 4. Jika sakelar [autoPlayEnabled] aktif (true) dan [trigger] adalah [FrameChangeTrigger.tapCluster]:
  ///    - Jika bingkai tidak memuat teks valid ([selectionResult.hasText] bernilai false), mengembalikan [AutoPlayDecision.alertNoText].
  ///    - Jika memuat teks valid, mengembalikan [AutoPlayDecision.speak].
  static AutoPlayDecision shouldAutoPlay({
    required FrameChangeTrigger trigger,
    required bool autoPlayEnabled,
    required LensSelectionResult selectionResult,
  }) {
    if (trigger != FrameChangeTrigger.tapCluster) {
      return AutoPlayDecision.prepareOnly;
    }

    if (!autoPlayEnabled) {
      return AutoPlayDecision.prepareOnly;
    }

    if (!selectionResult.hasText || selectionResult.text.trim().isEmpty) {
      return AutoPlayDecision.alertNoText;
    }

    return AutoPlayDecision.speak;
  }
}
