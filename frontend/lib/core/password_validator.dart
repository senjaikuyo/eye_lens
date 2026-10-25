class PasswordValidator {
  static bool hasMinLength(String password) => password.length >= 8;
  static bool hasUppercase(String password) => RegExp(r'[A-Z]').hasMatch(password);
  static bool hasLowercase(String password) => RegExp(r'[a-z]').hasMatch(password);
  static bool hasDigit(String password) => RegExp(r'[0-9]').hasMatch(password);
  static bool hasSpecialChar(String password) =>
      RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\\/~`~]').hasMatch(password);

  static bool isComplex(String password) {
    return hasMinLength(password) &&
        hasUppercase(password) &&
        hasLowercase(password) &&
        hasDigit(password) &&
        hasSpecialChar(password);
  }

  static double calculateStrength(String password) {
    if (password.isEmpty) return 0.0;
    int score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (hasUppercase(password)) score++;
    if (hasLowercase(password)) score++;
    if (hasDigit(password)) score++;
    if (hasSpecialChar(password)) score++;
    return (score / 6.0).clamp(0.0, 1.0);
  }
}
