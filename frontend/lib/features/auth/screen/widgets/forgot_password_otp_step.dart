import 'package:flutter/material.dart';

import 'package:eye_lens/app/theme/app_colors.dart';
import 'package:eye_lens/core/constants/app_strings.dart';
import 'package:eye_lens/features/auth/screen/widgets/forgot_password_header_widgets.dart';
import 'package:eye_lens/features/auth/screen/widgets/otp_input_row.dart';

class ForgotPasswordOtpStep extends StatelessWidget {
  final AppStrings strings;
  final bool isDark;
  final bool isLoading;
  final String email;
  final int otpGeneration;
  final String? otpError;
  final int resendCountdown;
  final ValueChanged<String> onOtpChanged;
  final VoidCallback onVerify;
  final VoidCallback onChangeEmail;
  final VoidCallback onResend;

  const ForgotPasswordOtpStep({
    super.key,
    required this.strings,
    required this.isDark,
    required this.isLoading,
    required this.email,
    required this.otpGeneration,
    required this.otpError,
    required this.resendCountdown,
    required this.onOtpChanged,
    required this.onVerify,
    required this.onChangeEmail,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    final errorText = otpError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          strings.verifyCode,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.white : AppColors.black,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${strings.forgotPasswordStep2Desc} $email',
          style: TextStyle(
            fontSize: 16,
            color: isDark ? Colors.white70 : Colors.black87,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          strings.codeExpiresNotice,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 32),
        OtpInputRow(
          key: ValueKey<int>(otpGeneration),
          onChanged: onOtpChanged,
          onCompleted: (_) => onVerify(),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            errorText,
            style: const TextStyle(color: Colors.red, fontSize: 14),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: onChangeEmail,
              child: const Text(
                'Ubah Email',
                style: TextStyle(
                  color: AppColors.linkBlue,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            GestureDetector(
              onTap: resendCountdown == 0 ? onResend : null,
              child: Text(
                resendCountdown > 0
                    ? strings.resendInSeconds(resendCountdown)
                    : strings.resendCode,
                style: TextStyle(
                  color: resendCountdown == 0
                      ? AppColors.linkBlue
                      : Colors.grey,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        ForgotPasswordActionButton(
          onPressed: onVerify,
          label: strings.verifyCode,
          isDark: isDark,
          isLoading: isLoading,
        ),
      ],
    );
  }
}
