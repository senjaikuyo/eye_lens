import 'package:flutter/material.dart';

import 'package:eye_lens/app/theme/app_colors.dart';

class ForgotPasswordStepIndicator extends StatelessWidget {
  final int currentStep;
  final bool isDark;

  const ForgotPasswordStepIndicator({
    super.key,
    required this.currentStep,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final step = index + 1;
        final isActive = step == currentStep;
        final isCompleted = step < currentStep;
        return Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? (isDark ? AppColors.white : AppColors.black)
                    : (isCompleted
                          ? Colors.green
                          : (isDark
                                ? const Color(0xFF333333)
                                : const Color(0xFFE5E7EB))),
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check, size: 18, color: Colors.white)
                    : Text(
                        '$step',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isActive
                              ? (isDark ? AppColors.black : AppColors.white)
                              : (isDark ? Colors.white70 : Colors.black54),
                        ),
                      ),
              ),
            ),
            if (index < 2)
              Container(
                width: 36,
                height: 2,
                color: isCompleted
                    ? Colors.green
                    : (isDark
                          ? const Color(0xFF333333)
                          : const Color(0xFFE5E7EB)),
              ),
          ],
        );
      }),
    );
  }
}

class ForgotPasswordActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final bool isDark;
  final bool isLoading;

  const ForgotPasswordActionButton({
    super.key,
    required this.onPressed,
    required this.label,
    required this.isDark,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: isDark ? const Color(0xFF1E1E1E) : AppColors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? Colors.white : AppColors.black,
                width: 1.2,
              ),
            ),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isDark ? Colors.white : AppColors.black,
                      ),
                    )
                  : Text(
                      label,
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
