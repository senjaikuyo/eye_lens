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

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onUpdatePressed(AppStrings strings) {
    if (_currentPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(strings.fillAllFields),
          backgroundColor: AppColors.black,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(strings.passwordsDoNotMatch),
          backgroundColor: AppColors.black,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(strings.passwordUpdatedSuccess),
        backgroundColor: AppColors.black,
        duration: const Duration(seconds: 2),
      ),
    );
    Navigator.of(context).pop();
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
                    onTap: () => _onUpdatePressed(strings),
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
