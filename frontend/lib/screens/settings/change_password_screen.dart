import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_strings.dart';
import '../../widgets/custom_auth_field.dart';
import '../../widgets/eyelash_icon.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  String? _currentPasswordError;
  String? _newPasswordError;
  String? _confirmPasswordError;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _validate(AppStrings strings) {
    bool isValid = true;
    final current = _currentPasswordController.text;
    final newPass = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    // Current password
    if (current.isEmpty) {
      setState(() {
        _currentPasswordError = strings.currentPasswordRequired;
      });
      isValid = false;
    } else {
      setState(() {
        _currentPasswordError = null;
      });
    }

    // New password
    if (newPass.isEmpty) {
      setState(() {
        _newPasswordError = strings.passwordRequired;
      });
      isValid = false;
    } else if (newPass.length < 6) {
      setState(() {
        _newPasswordError = strings.passwordTooShort;
      });
      isValid = false;
    } else if (newPass == current && current.isNotEmpty) {
      setState(() {
        _newPasswordError = strings.newPasswordSameAsOld;
      });
      isValid = false;
    } else {
      setState(() {
        _newPasswordError = null;
      });
    }

    // Confirm password
    if (confirm.isEmpty) {
      setState(() {
        _confirmPasswordError = strings.passwordRequired;
      });
      isValid = false;
    } else if (confirm != newPass) {
      setState(() {
        _confirmPasswordError = strings.passwordsDoNotMatch;
      });
      isValid = false;
    } else {
      setState(() {
        _confirmPasswordError = null;
      });
    }

    return isValid;
  }

  void _onUpdatePressed(AppStrings strings, bool isDark) {
    if (!_validate(strings)) return;

    // Show refined success dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFF22C55E),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              strings.passwordUpdatedSuccess,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.black,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : AppColors.black,
                foregroundColor: isDark ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              ),
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Back to Settings
              },
              child: Text(
                strings.ok,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings.of(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.black : AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),

              // Header: Back Button + "Change Password"
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2A2A2A)
                          : const Color(0xFFD9D9D9),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: isDark ? Colors.white : Colors.black,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    strings.changePassword,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.black,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // 1. Current Password
              CustomAuthField(
                label: strings.currentPassword,
                controller: _currentPasswordController,
                obscureText: _obscureCurrent,
                errorText: _currentPasswordError,
                onChanged: (_) {
                  if (_currentPasswordError != null) {
                    setState(() {
                      _currentPasswordError = null;
                    });
                  }
                },
                suffixIcon: EyelashIcon(
                  isObscured: _obscureCurrent,
                  onTap: () {
                    setState(() {
                      _obscureCurrent = !_obscureCurrent;
                    });
                  },
                ),
              ),

              const SizedBox(height: 20),

              // 2. New Password
              CustomAuthField(
                label: strings.newPassword,
                controller: _newPasswordController,
                obscureText: _obscureNew,
                errorText: _newPasswordError,
                onChanged: (_) {
                  if (_newPasswordError != null) {
                    setState(() {
                      _newPasswordError = null;
                    });
                  }
                },
                suffixIcon: EyelashIcon(
                  isObscured: _obscureNew,
                  onTap: () {
                    setState(() {
                      _obscureNew = !_obscureNew;
                    });
                  },
                ),
              ),

              const SizedBox(height: 20),

              // 3. Confirm Password
              CustomAuthField(
                label: strings.confirmPassword,
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                errorText: _confirmPasswordError,
                onChanged: (_) {
                  if (_confirmPasswordError != null) {
                    setState(() {
                      _confirmPasswordError = null;
                    });
                  }
                },
                suffixIcon: EyelashIcon(
                  isObscured: _obscureConfirm,
                  onTap: () {
                    setState(() {
                      _obscureConfirm = !_obscureConfirm;
                    });
                  },
                ),
              ),

              const SizedBox(height: 36),

              // Update Button (Outlined pill, centered)
              Center(
                child: Material(
                  color: isDark ? const Color(0xFF1E1E1E) : AppColors.white,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: () => _onUpdatePressed(strings, isDark),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 110),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : AppColors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? Colors.white : AppColors.black,
                          width: 1.0,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        strings.update,
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }
}
