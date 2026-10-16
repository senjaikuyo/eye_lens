import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_strings.dart';
import '../auth/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  void _onNextPressed(int totalPages) {
    if (_currentPage < totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final strings = AppStrings.of(context);

    final items = [
      OnboardingItem(
        title: strings.onbTitle1,
        subtitle: strings.onbSub1,
        buttonText: strings.next,
      ),
      OnboardingItem(
        title: strings.onbTitle2,
        subtitle: strings.onbSub2,
        buttonText: strings.next,
      ),
      OnboardingItem(
        title: strings.onbTitle3,
        subtitle: strings.onbSub3,
        buttonText: strings.start,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          // White background base
          Container(color: AppColors.white),

          // Diagonal black split (shared across pages for smooth visual continuity)
          Positioned.fill(
            child: ClipPath(
              clipper: const DiagonalSplitClipper(),
              child: Container(color: AppColors.black),
            ),
          ),

          // PageView for page-specific content
          PageView.builder(
            controller: _pageController,
            itemCount: items.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              return _buildPageContent(index, size, topPadding, items);
            },
          ),

          // Bottom-right controls (Button + Indicator centered underneath)
          Positioned(
            right: 22,
            bottom: bottomPadding + 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Next / Start Button
                Material(
                  color: AppColors.buttonGrey,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: () => _onNextPressed(items.length),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 100,
                      height: 42,
                      alignment: Alignment.center,
                      child: Text(
                        items[_currentPage].buttonText,
                        style: const TextStyle(
                          color: AppColors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Indicator dots centered under button
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    items.length,
                    (dotIndex) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      width: _currentPage == dotIndex ? 18 : 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageContent(
    int index,
    Size size,
    double topPadding,
    List<OnboardingItem> items,
  ) {
    return Stack(
      children: [
        // Top graphic area (inside upper white section)
        _buildTopGraphic(index, size, topPadding),

        // Bottom text area (right-anchored in the black section, matching Figma center ~64%)
        Positioned(
          right: 16,
          width: size.width * 0.66,
          top: size.height * 0.52,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                items[index].title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textOnDark,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                items[index].subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textOnDark,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopGraphic(int index, Size size, double topPadding) {
    if (index == 0) {
      // Slide 1: Primary EyeLens stacked logo (proportional, positioned cleanly in the white triangle)
      return Positioned(
        top: topPadding + 28,
        left: size.width * 0.10,
        child: Image.asset(
          'assets/images/logo.png',
          width: size.width * 0.42,
          fit: BoxFit.contain,
        ),
      );
    } else if (index == 1) {
      // Slide 2: Top-left horizontal logo + centered magnifying glass
      return Stack(
        children: [
          // Top-left logo (sharply rendered, perfectly readable)
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
          // Magnifying glass illustration
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
    } else {
      // Slide 3: Top-left horizontal logo (identical to slide 2) + bold "Pharmacy" text
      return Stack(
        children: [
          // Top-left logo (identical to slide 2 for consistency)
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
          // "Pharmacy" prominent text
          Positioned(
            top: topPadding + size.height * 0.10,
            left: size.width * 0.14,
            child: const Text(
              '“Pharmacy”',
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
}

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
