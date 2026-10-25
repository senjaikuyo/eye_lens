import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_strings.dart';
import '../../core/password_validator.dart';
import '../../services/auth/auth_service.dart';
import '../../widgets/custom_auth_field.dart';
import '../../widgets/eyelash_icon.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final AuthService _authService = AuthService();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _validate(AppStrings strings) {
    bool isValid = true;
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (name.isEmpty) {
      setState(() {
        _nameError = strings.nameRequired;
      });
      isValid = false;
    } else {
      setState(() {
        _nameError = null;
      });
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (email.isEmpty || !emailRegex.hasMatch(email)) {
      setState(() {
        _emailError = strings.emailInvalid;
      });
      isValid = false;
    } else {
      setState(() {
        _emailError = null;
      });
    }

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

    return isValid;
  }

  Future<void> _onRegisterPressed(AppStrings strings) async {
    if (!_validate(strings) || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        passwordConfirmation: _confirmPasswordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(strings.registerSuccess),
          backgroundColor: AppColors.black,
          duration: const Duration(seconds: 2),
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

  void _onLoginTap() {
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
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 50),
              Center(
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 140,
                  color: isDark ? Colors.white : null,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 48),
              CustomAuthField(
                label: strings.name,
                controller: _nameController,
                keyboardType: TextInputType.name,
                errorText: _nameError,
                onChanged: (_) {
                  if (_nameError != null) {
                    setState(() {
                      _nameError = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 18),
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
              const SizedBox(height: 18),
              CustomAuthField(
                label: strings.password,
                controller: _passwordController,
                obscureText: _obscurePassword,
                errorText: _passwordError,
                onChanged: (_) {
                  if (_passwordError != null) {
                    setState(() {
                      _passwordError = null;
                    });
                  }
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
              const SizedBox(height: 18),
              CustomAuthField(
                label: strings.confirmPassword,
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                errorText: _confirmPasswordError,
                onChanged: (_) {
                  if (_confirmPasswordError != null) {
                    setState(() {
                      _confirmPasswordError = null;
                    });
                  }
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
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _onLoginTap,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      strings.alreadyHaveAccount,
                      style: const TextStyle(
                        color: AppColors.linkBlue,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 36),
              Center(
                child: Material(
                  color: isDark ? const Color(0xFF1E1E1E) : AppColors.white,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: _isLoading ? null : () => _onRegisterPressed(strings),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 140,
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: isDark ? Colors.white : AppColors.black,
                                ),
                              )
                            : Text(
                                strings.register,
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
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
