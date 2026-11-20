import 'package:flutter/material.dart';

import 'package:eye_lens/app/theme/app_colors.dart';
import 'package:eye_lens/core/constants/app_strings.dart';
import 'package:eye_lens/core/widgets/custom_auth_field.dart';
import 'package:eye_lens/features/auth/screen/widgets/forgot_password_header_widgets.dart';

class ForgotPasswordEmailStep extends StatelessWidget {
  final AppStrings strings;
  final bool isDark;
  final bool isLoading;
  final TextEditingController emailController;
  final String? emailError;
  final VoidCallback onEmailChanged;
  final VoidCallback onSubmit;

  const ForgotPasswordEmailStep({
    super.key,
    required this.strings,
    required this.isDark,
    required this.isLoading,
    required this.emailController,
    required this.emailError,
    required this.onEmailChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          strings.forgotPasswordTitle,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.white : AppColors.black,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          strings.forgotPasswordStep1Desc,
          style: TextStyle(
            fontSize: 16,
            color: isDark ? Colors.white70 : Colors.black87,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),
        CustomAuthField(
          label: strings.email,
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          errorText: emailError,
          onChanged: (_) => onEmailChanged(),
        ),
        const SizedBox(height: 32),
        ForgotPasswordActionButton(
          onPressed: onSubmit,
          label: strings.sendCode,
          isDark: isDark,
          isLoading: isLoading,
        ),
      ],
    );
  }
}
