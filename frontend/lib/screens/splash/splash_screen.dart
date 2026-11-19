import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../home/home_screen.dart';
import '../onboarding/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _scaleAnimation = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();

    _timer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        // Sesi tersimpan (termasuk saat offline) langsung membuka Home.
        // Pengguna tanpa sesi tetap melihat onboarding/login.
        final destination = _hasStoredSession()
            ? const HomeScreen()
            : const OnboardingScreen();
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                destination,
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    });
  }

  bool _hasStoredSession() {
    try {
      return Provider.of<AuthProvider>(context, listen: false).isAuthenticated;
    } catch (_) {
      // Provider tidak tersedia (mis. widget test terisolasi).
      return false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.black : AppColors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(scale: _scaleAnimation, child: child),
            );
          },
          child: Image.asset(
            'assets/images/logo.png',
            width: 140,
            color: isDark ? Colors.white : null,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
