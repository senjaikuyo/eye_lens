import 'package:flutter_test/flutter_test.dart';
import 'package:eye_lens/core/password_validator.dart';

void main() {
  group('PasswordValidator Tests', () {
    test('isComplex menolak password kurang dari 8 karakter', () {
      expect(PasswordValidator.isComplex('Ab1!'), isFalse);
    });

    test('isComplex menolak password tanpa huruf besar', () {
      expect(PasswordValidator.isComplex('password123!'), isFalse);
    });

    test('isComplex menolak password tanpa huruf kecil', () {
      expect(PasswordValidator.isComplex('PASSWORD123!'), isFalse);
    });

    test('isComplex menolak password tanpa angka', () {
      expect(PasswordValidator.isComplex('Password!@#'), isFalse);
    });

    test('isComplex menolak password tanpa simbol', () {
      expect(PasswordValidator.isComplex('Password1234'), isFalse);
    });

    test('isComplex menerima password valid dengan huruf besar, kecil, angka, dan simbol', () {
      expect(PasswordValidator.isComplex('Rahasia123!'), isTrue);
      expect(PasswordValidator.isComplex('SuperS3cure@2026'), isTrue);
    });

    test('calculateStrength mengembalikan nilai proporsional', () {
      expect(PasswordValidator.calculateStrength(''), 0.0);
      expect(PasswordValidator.calculateStrength('abc'), lessThan(0.3));
      expect(PasswordValidator.calculateStrength('Abcdefg1'), inInclusiveRange(0.4, 0.7));
      expect(PasswordValidator.calculateStrength('SangatKuat123!@#'), greaterThanOrEqualTo(0.8));
    });
  });
}
