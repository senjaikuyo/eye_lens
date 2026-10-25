import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_strings.dart';
import '../../core/password_validator.dart';
import '../../services/auth/auth_service.dart';
import '../../widgets/custom_auth_field.dart';
import '../../widgets/eyelash_icon.dart';
import 'widgets/otp_input_row.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final AuthService? authService;

  const ForgotPasswordScreen({super.key, this.authService});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final AuthService _authService;

  int _currentStep = 1;
  bool _isLoading = false;

  // Step 1: Email
  final TextEditingController _emailController = TextEditingController();
  String? _emailError;

  // Step 2: OTP
  String _otpCode = '';
  String? _otpError;
  int _resendCountdown = 60;
  Timer? _resendTimer;

  // Step 3: Password Baru
  String? _resetToken;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _passwordError;
  String? _confirmPasswordError;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _resendCountdown = 60;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCountdown > 1) {
        setState(() {
          _resendCountdown--;
        });
      } else {
        setState(() {
          _resendCountdown = 0;
        });
        timer.cancel();
      }
    });
  }

  // --- Step 1: Kirim Kode ---
  Future<void> _handleSendCode(AppStrings strings) async {
    final email = _emailController.text.trim();
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

    if (email.isEmpty || !emailRegex.hasMatch(email)) {
      setState(() {
        _emailError = strings.emailInvalid;
      });
      return;
    }

    setState(() {
      _emailError = null;
      _isLoading = true;
    });

    try {
      await _authService.requestPasswordReset(email);
      if (!mounted) return;
      _startResendTimer();
      setState(() {
        _currentStep = 2;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- Step 2: Kirim Ulang Kode ---
  Future<void> _handleResendCode(AppStrings strings) async {
    if (_resendCountdown > 0 || _isLoading) return;

    setState(() {
      _isLoading = true;
      _otpError = null;
    });

    try {
      final email = _emailController.text.trim();
      await _authService.requestPasswordReset(email);
      if (!mounted) return;
      _startResendTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${strings.codeSentTo} $email'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- Step 2: Verifikasi Kode ---
  Future<void> _handleVerifyCode(AppStrings strings) async {
    if (_otpCode.length != 6) {
      setState(() {
        _otpError = 'Harap isi 6 digit kode verifikasi';
      });
      return;
    }

    setState(() {
      _otpError = null;
      _isLoading = true;
    });

    try {
      final token = await _authService.verifyResetCode(
        email: _emailController.text.trim(),
        code: _otpCode,
      );
      if (!mounted) return;
      setState(() {
        _resetToken = token;
        _currentStep = 3;
      });
    } catch (e) {
      if (!mounted) return;
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      setState(() {
        _otpError = errorMsg;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- Step 3: Simpan Password Baru ---
  Future<void> _handleResetPassword(AppStrings strings) async {
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    bool isValid = true;

    if (password.isEmpty) {
      setState(() {
        _passwordError = strings.passwordRequired;
      });
      isValid = false;
    } else if (!PasswordValidator.isComplex(password)) {
      setState(() {
        _passwordError = strings.passwordComplexityRequirements;
      });
      isValid = false;
    } else {
      setState(() {
        _passwordError = null;
      });
    }

    if (confirmPassword.isEmpty) {
      setState(() {
        _confirmPasswordError = strings.passwordRequired;
      });
      isValid = false;
    } else if (confirmPassword != password) {
      setState(() {
        _confirmPasswordError = strings.passwordsDoNotMatch;
      });
      isValid = false;
    } else {
      setState(() {
        _confirmPasswordError = null;
      });
    }

    if (!isValid || _isLoading || _resetToken == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.resetPassword(
        email: _emailController.text.trim(),
        resetToken: _resetToken!,
        password: password,
        passwordConfirmation: confirmPassword,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(strings.passwordResetSuccessMessage),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildStepIndicator(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final step = index + 1;
        final isActive = step == _currentStep;
        final isCompleted = step < _currentStep;

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
                        : (isDark ? const Color(0xFF333333) : const Color(0xFFE5E7EB))),
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
                    : (isDark ? const Color(0xFF333333) : const Color(0xFFE5E7EB)),
              ),
          ],
        );
      }),
    );
  }

  Widget _buildActionButton({
    required VoidCallback? onPressed,
    required String label,
    required bool isDark,
  }) {
    return Center(
      child: Material(
        color: isDark ? const Color(0xFF1E1E1E) : AppColors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: _isLoading ? null : onPressed,
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
              child: _isLoading
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

  Widget _buildStep1(AppStrings strings, bool isDark) {
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
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          errorText: _emailError,
          onChanged: (_) {
            if (_emailError != null) {
              setState(() {
                _emailError = null;
              });
            }
          },
        ),
        const SizedBox(height: 32),
        _buildActionButton(
          onPressed: () => _handleSendCode(strings),
          label: strings.sendCode,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildStep2(AppStrings strings, bool isDark) {
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
          '${strings.forgotPasswordStep2Desc} ${_emailController.text}',
          style: TextStyle(
            fontSize: 16,
            color: isDark ? Colors.white70 : Colors.black87,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          strings.codeExpiresNotice,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 32),
        OtpInputRow(
          onChanged: (code) {
            setState(() {
              _otpCode = code;
              if (_otpError != null) _otpError = null;
            });
          },
          onCompleted: (_) => _handleVerifyCode(strings),
        ),
        if (_otpError != null) ...[
          const SizedBox(height: 8),
          Text(
            _otpError!,
            style: const TextStyle(color: Colors.red, fontSize: 14),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _currentStep = 1;
                });
              },
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
              onTap: _resendCountdown == 0 ? () => _handleResendCode(strings) : null,
              child: Text(
                _resendCountdown > 0
                    ? strings.resendInSeconds(_resendCountdown)
                    : strings.resendCode,
                style: TextStyle(
                  color: _resendCountdown == 0 ? AppColors.linkBlue : Colors.grey,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        _buildActionButton(
          onPressed: () => _handleVerifyCode(strings),
          label: strings.verifyCode,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildStep3(AppStrings strings, bool isDark) {
    final passwordText = _passwordController.text;
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
          controller: _passwordController,
          obscureText: _obscurePassword,
          errorText: _passwordError,
          onChanged: (_) {
            setState(() {
              if (_passwordError != null) _passwordError = null;
            });
          },
          suffixIcon: EyelashIcon(
            isObscured: _obscurePassword,
            onTap: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
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
                    backgroundColor: isDark ? const Color(0xFF333333) : const Color(0xFFE5E7EB),
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
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          errorText: _confirmPasswordError,
          onChanged: (_) {
            setState(() {
              if (_confirmPasswordError != null) _confirmPasswordError = null;
            });
          },
          suffixIcon: EyelashIcon(
            isObscured: _obscureConfirmPassword,
            onTap: () {
              setState(() {
                _obscureConfirmPassword = !_obscureConfirmPassword;
              });
            },
          ),
        ),
        const SizedBox(height: 32),
        _buildActionButton(
          onPressed: () => _handleResetPassword(strings),
          label: strings.saveNewPassword,
          isDark: isDark,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings.of(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.black : AppColors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDark ? AppColors.white : AppColors.black,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              _buildStepIndicator(isDark),
              const SizedBox(height: 36),
              if (_currentStep == 1) _buildStep1(strings, isDark),
              if (_currentStep == 2) _buildStep2(strings, isDark),
              if (_currentStep == 3) _buildStep3(strings, isDark),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
