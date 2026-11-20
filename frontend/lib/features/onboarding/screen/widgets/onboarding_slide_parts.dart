import 'package:flutter/material.dart';

import 'package:eye_lens/app/theme/app_colors.dart';

class OnboardingItem {
  final String title;
  final String subtitle;
  final String buttonText;

  const OnboardingItem({
    required this.title,
    required this.subtitle,
    required this.buttonText,
  });
}

class DiagonalSplitClipper extends CustomClipper<Path> {
  const DiagonalSplitClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, size.height * 0.607);
    path.lineTo(size.width, size.height * 0.122);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class OnboardingTopGraphic extends StatelessWidget {
  final int index;
  final Size size;
  final double topPadding;

  const OnboardingTopGraphic({
    super.key,
    required this.index,
    required this.size,
    required this.topPadding,
  });

  @override
  Widget build(BuildContext context) {
    if (index == 0) {
      return Stack(
        children: [
          Positioned(
            top: topPadding + 28,
            left: size.width * 0.10,
            child: Image.asset(
              'assets/images/logo.png',
              width: size.width * 0.42,
              fit: BoxFit.contain,
            ),
          ),
        ],
      );
    }
    if (index == 1) {
      return Stack(
        children: [
          Positioned(
            top: topPadding + 14,
            left: 20,
            child: Image.asset(
              'assets/images/logo_horizontal.png',
              width: 105,
              height: 32,
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            top: topPadding + size.height * 0.13,
            left: size.width * 0.35,
            child: Image.asset(
              'assets/images/icon_magnifier.png',
              width: size.width * 0.22,
              fit: BoxFit.contain,
            ),
          ),
        ],
      );
    }
    return Stack(
      children: [
        Positioned(
          top: topPadding + 14,
          left: 20,
          child: Image.asset(
            'assets/images/logo_horizontal.png',
            width: 105,
            height: 32,
            fit: BoxFit.contain,
          ),
        ),
        Positioned(
          top: topPadding + size.height * 0.10,
          left: size.width * 0.14,
          child: const Text(
            '\u201cPharmacy\u201d',
            style: TextStyle(
              color: AppColors.black,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ],
    );
  }
}
