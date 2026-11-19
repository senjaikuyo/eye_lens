import 'package:flutter/services.dart';

/// Layanan untuk menangkap event penekanan tombol fisik perangkat (hardware keys),
/// khususnya tombol volume fisik (Volume Up & Down) sebagai tombol shutter
/// alternatif yang ramah bagi pengguna lansia dan penderita tremor.
class HardwareKeyService {
  VoidCallback? onShutterTriggered;

  bool _isListening = false;
  bool get isListening => _isListening;

  void startListening(VoidCallback onTrigger) {
    if (_isListening) return;
    onShutterTriggered = onTrigger;
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _isListening = true;
  }

  void stopListening() {
    if (!_isListening) return;
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    onShutterTriggered = null;
    _isListening = false;
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.audioVolumeUp ||
          key == LogicalKeyboardKey.audioVolumeDown) {
        onShutterTriggered?.call();
        return true; // Consume event agar tidak mengubah volume sistem saat membidik
      }
    }
    return false;
  }
}
