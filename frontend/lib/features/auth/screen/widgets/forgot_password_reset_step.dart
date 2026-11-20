import 'package:flutter/material.dart';

import 'package:eye_lens/app/theme/app_colors.dart';
import 'package:eye_lens/core/constants/app_strings.dart';
import 'package:eye_lens/core/utils/password_validator.dart';
import 'package:eye_lens/core/widgets/custom_auth_field.dart';
import 'package:eye_lens/core/widgets/eyelash_icon.dart';
import 'package:eye_lens/features/auth/screen/widgets/forgot_password_header_widgets.dart';

class ForgotPasswordResetStep extends StatelessWidget {
  final AppStrings strings;
  final bool isDark;
  final bool isLoading;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool obscurePassword;
  final bool obscureConfirmPassword;
  final String? passwordError;
  final String? confirmPasswordError;
  final VoidCallback onPasswordChanged;
  final VoidCallback onConfirmPasswordChanged;
  final VoidCallback onToggleObscurePassword;
  final VoidCallback onToggleObscureConfirmPassword;
  final VoidCallback onSubmit;

  const ForgotPasswordResetStep({
    super.key,
    required this.strings,
    required this.isDark,
    required this.isLoading,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.obscurePassword,
    required this.obscureConfirmPassword,
    required this.passwordError,
    required this.confirmPasswordError,
    required this.onPasswordChanged,
    required this.onConfirmPasswordChanged,
    required this.onToggleObscurePassword,
    required this.onToggleObscureConfirmPassword,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final passwordText = passwordController.text;
    final strength = PasswordValidator.calculateStrength(passwordText);
    String strengthLabel = strings.passwordStrengthWeak;
    Color strengthColor = Colors.red;

    if (strength > 0.6) {
      strengthLabel = strings.passwordStrengthStrong;
      strengthColor = Colors.green;
    } else if (strength > 0.3) {
      strengthLabel = strings.passwordStrengthMedium;
      strengthColor = Colors.orange;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          strings.createNewPassword,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.white : AppColors.black,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          strings.forgotPasswordStep3Desc,
          style: TextStyle(
            fontSize: 16,
            color: isDark ? Colors.white70 : Colors.black87,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        CustomAuthField(
          label: strings.newPassword,
          controller: passwordController,
          obscureText: obscurePassword,
          errorText: passwordError,
          onChanged: (_) => onPasswordChanged(),
          suffixIcon: EyelashIcon(
            isObscured: obscurePassword,
            onTap: onToggleObscurePassword,
          ),
        ),
        if (passwordText.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: strength,
                    color: strengthColor,
                    backgroundColor: isDark
                        ? const Color(0xFF333333)
                        : const Color(0xFFE5E7EB),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${strings.passwordStrengthLabel}: $strengthLabel',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: strengthColor,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        CustomAuthField(
          label: strings.confirmNewPassword,
          controller: confirmPasswordController,
          obscureText: obscureConfirmPassword,
          errorText: confirmPasswordError,
          onChanged: (_) => onConfirmPasswordChanged(),
          suffixIcon: EyelashIcon(
            isObscured: obscureConfirmPassword,
            onTap: onToggleObscureConfirmPassword,
          ),
        ),
        const SizedBox(height: 32),
        ForgotPasswordActionButton(
          onPressed: onSubmit,
          label: strings.saveNewPassword,
          isDark: isDark,
          isLoading: isLoading,
        ),
      ],
    );
  }
}
