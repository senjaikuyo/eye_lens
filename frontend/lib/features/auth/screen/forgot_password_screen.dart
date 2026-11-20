import 'dart:async';

import 'package:flutter/material.dart';

import 'package:eye_lens/app/theme/app_colors.dart';
import 'package:eye_lens/core/constants/app_strings.dart';
import 'package:eye_lens/core/utils/password_validator.dart';
import 'package:eye_lens/features/auth/logic/auth_service.dart';
import 'package:eye_lens/features/auth/screen/login_screen.dart';
import 'package:eye_lens/features/auth/screen/widgets/forgot_password_email_step.dart';
import 'package:eye_lens/features/auth/screen/widgets/forgot_password_header_widgets.dart';
import 'package:eye_lens/features/auth/screen/widgets/forgot_password_otp_step.dart';
import 'package:eye_lens/features/auth/screen/widgets/forgot_password_reset_step.dart';

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
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _passwordError;
  String? _confirmPasswordError;

  // Dipakai untuk me-reset seluruh kotak OTP saat kode baru dikirim.
  int _otpGeneration = 0;

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

  String get _email => _emailController.text.trim().toLowerCase();

  // --- Step 1: Kirim Kode ---
  Future<void> _handleSendCode(AppStrings strings) async {
    if (_isLoading) return;

    final email = _email;
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
        _otpCode = '';
        _otpError = null;
        _otpGeneration++;
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
      final email = _email;
      await _authService.requestPasswordReset(email);
      if (!mounted) return;
      _startResendTimer();
      setState(() {
        _otpCode = '';
        _otpError = null;
        _otpGeneration++;
      });
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
    if (_isLoading) return;

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
        email: _email,
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
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
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
        email: _email,
        resetToken: _resetToken!,
        password: password,
        passwordConfirmation: confirmPassword,
      );
      if (!mounted) return;

      // Backend sudah merevoke seluruh token Sanctum. Bersihkan juga sesi
      // lokal agar token lama tidak tertinggal di perangkat.
      await _authService.logout();
      if (!mounted) return;

      await _showResetSuccessDialog(
        strings,
        Theme.of(context).brightness == Brightness.dark,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
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

  Future<void> _showResetSuccessDialog(AppStrings strings, bool isDark) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.accentGreen,
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
              strings.passwordResetSuccessTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.black,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              strings.passwordResetSuccessMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark
                    ? const Color(0xFFCCCCCC)
                    : const Color(0xFF555555),
                fontSize: 16,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              key: const Key('backToLoginButton'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : AppColors.black,
                foregroundColor: isDark ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                strings.backToLogin,
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
              ForgotPasswordStepIndicator(
                currentStep: _currentStep,
                isDark: isDark,
              ),
              const SizedBox(height: 36),
              if (_currentStep == 1)
                ForgotPasswordEmailStep(
                  strings: strings,
                  isDark: isDark,
                  isLoading: _isLoading,
                  emailController: _emailController,
                  emailError: _emailError,
                  onEmailChanged: () {
                    if (_emailError != null) {
                      setState(() {
                        _emailError = null;
                      });
                    }
                  },
                  onSubmit: () => _handleSendCode(strings),
                ),
              if (_currentStep == 2)
                ForgotPasswordOtpStep(
                  strings: strings,
                  isDark: isDark,
                  isLoading: _isLoading,
                  email: _email,
                  otpGeneration: _otpGeneration,
                  otpError: _otpError,
                  resendCountdown: _resendCountdown,
                  onOtpChanged: (code) {
                    setState(() {
                      _otpCode = code;
                      if (_otpError != null) _otpError = null;
                    });
                  },
                  onVerify: () => _handleVerifyCode(strings),
                  onChangeEmail: () {
                    _resendTimer?.cancel();
                    setState(() {
                      _currentStep = 1;
                      _resendCountdown = 0;
                      _otpCode = '';
                      _otpError = null;
                      _otpGeneration++;
                    });
                  },
                  onResend: () => _handleResendCode(strings),
                ),
              if (_currentStep == 3)
                ForgotPasswordResetStep(
                  strings: strings,
                  isDark: isDark,
                  isLoading: _isLoading,
                  passwordController: _passwordController,
                  confirmPasswordController: _confirmPasswordController,
                  obscurePassword: _obscurePassword,
                  obscureConfirmPassword: _obscureConfirmPassword,
                  passwordError: _passwordError,
                  confirmPasswordError: _confirmPasswordError,
                  onPasswordChanged: () {
                    setState(() {
                      if (_passwordError != null) _passwordError = null;
                    });
                  },
                  onConfirmPasswordChanged: () {
                    setState(() {
                      if (_confirmPasswordError != null) {
                        _confirmPasswordError = null;
                      }
                    });
                  },
                  onToggleObscurePassword: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  onToggleObscureConfirmPassword: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                  onSubmit: () => _handleResetPassword(strings),
                ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
