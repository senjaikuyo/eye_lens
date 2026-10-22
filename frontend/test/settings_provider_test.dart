import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eye_lens/core/app_constants.dart';
import 'package:eye_lens/providers/settings_provider.dart';

void main() {
  group('SettingsProvider Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('1. Nilai bawaan (default) sakelar autoPlayAudio adalah true', () async {
      final prefs = await SharedPreferences.getInstance();
      final provider = SettingsProvider(preferences: prefs);

      expect(provider.autoPlayAudio, isTrue);
    });

    test('2. Mengubah nilai autoPlayAudio tersimpan ke SharedPreferences dan memicu listener', () async {
      final prefs = await SharedPreferences.getInstance();
      final provider = SettingsProvider(preferences: prefs);

      var notified = false;
      provider.addListener(() {
        notified = true;
      });

      await provider.setAutoPlayAudio(false);

      expect(provider.autoPlayAudio, isFalse);
      expect(notified, isTrue);
      expect(prefs.getBool(AppPreferenceKeys.autoPlayAudio), isFalse);
    });

    test('3. Nilai yang tersimpan terbaca kembali saat provider diinisialisasi ulang', () async {
      SharedPreferences.setMockInitialValues({
        AppPreferenceKeys.autoPlayAudio: false,
      });

      final prefs = await SharedPreferences.getInstance();
      final provider = SettingsProvider(preferences: prefs);

      expect(provider.autoPlayAudio, isFalse);
    });
  });
}
