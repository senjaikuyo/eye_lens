import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_strings.dart';
import '../../providers/language_provider.dart';
import '../../providers/theme_provider.dart';
import '../auth/login_screen.dart';
import '../history/history_screen.dart';
import 'appearance_screen.dart';
import 'change_password_screen.dart';
import 'faq_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoPlayAudio = false;

  void _showLogoutDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          strings.logOutConfirmTitle,
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          strings.logOutConfirmMessage,
          style: TextStyle(
            color: isDark ? const Color(0xFFCCCCCC) : const Color(0xFF555555),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              strings.cancel,
              style: TextStyle(
                color: isDark ? const Color(0xFFAAAAAA) : const Color(0xFF777777),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            child: Text(
              strings.logOut,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required Widget icon,
    required Widget child,
    VoidCallback? onTap,
    Widget? trailing,
    bool isDestructive = false,
  }) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark(context);
    final isHighContrast = themeProvider.isHighContrast;

    final borderColor = isDestructive
        ? const Color(0xFFEF4444)
        : (isHighContrast
            ? (isDark ? Colors.white : Colors.black)
            : (isDark ? const Color(0xFF333333) : const Color(0xFFDDE3EA)));

    final borderWidth = isHighContrast ? 2.0 : 1.0;

    return Material(
      color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF2F4F7),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor,
              width: borderWidth,
            ),
          ),
          child: Row(
            children: [
              icon,
              const SizedBox(width: 14),
              Expanded(child: child),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark(context);
    final isHighContrast = themeProvider.isHighContrast;
    final strings = AppStrings.of(context);
    final languageProvider = context.watch<LanguageProvider>();
    final selectedLanguage = languageProvider.language;

    return Scaffold(
      backgroundColor: isDark ? AppColors.black : AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              // Header: Back Button + "Settings"
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2A2A2A)
                          : const Color(0xFFD9D9D9),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: isDark ? Colors.white : Colors.black,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    strings.settings,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.black,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 1. Email Card
              _buildCard(
                icon: Icon(
                  Icons.mail_outline_rounded,
                  color: isDark ? Colors.white : Colors.black,
                  size: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.email,
                      style: TextStyle(
                        color: isDark ? const Color(0xFFAAAAAA) : AppColors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'afifhamzah21@gmail.com',
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.black,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 2. Change Password
              _buildCard(
                icon: Icon(
                  Icons.lock_outline_rounded,
                  color: isDark ? Colors.white : Colors.black,
                  size: 24,
                ),
                child: Text(
                  strings.changePassword,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? const Color(0xFF777777) : Colors.black,
                  size: 28,
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ChangePasswordScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),

              // 3. History
              _buildCard(
                icon: Icon(
                  Icons.calendar_month_outlined,
                  color: isDark ? Colors.white : Colors.black,
                  size: 24,
                ),
                child: Text(
                  strings.history,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? const Color(0xFF777777) : Colors.black,
                  size: 28,
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const HistoryScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),
              Divider(
                color: isDark ? const Color(0xFF333333) : const Color(0xFF222222),
                thickness: 0.8,
              ),
              const SizedBox(height: 16),

              // 4. Appearance
              _buildCard(
                icon: Text(
                  'Aa',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(
                  strings.appearance,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? const Color(0xFF777777) : Colors.black,
                  size: 28,
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AppearanceScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),
              Divider(
                color: isDark ? const Color(0xFF333333) : const Color(0xFF222222),
                thickness: 0.8,
              ),
              const SizedBox(height: 16),

              // 5. Auto-Play Audio Switch
              _buildCard(
                icon: Icon(
                  Icons.volume_up_outlined,
                  color: isDark ? Colors.white : Colors.black,
                  size: 24,
                ),
                child: Text(
                  strings.autoPlayAudio,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: Switch(
                  value: _autoPlayAudio,
                  activeThumbColor: isDark ? Colors.white : Colors.black,
                  onChanged: (val) {
                    setState(() {
                      _autoPlayAudio = val;
                    });
                  },
                ),
              ),

              const SizedBox(height: 12),

              // 6. Language App Selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF2F4F7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isHighContrast
                        ? (isDark ? Colors.white : Colors.black)
                        : (isDark ? const Color(0xFF333333) : const Color(0xFFDDE3EA)),
                    width: isHighContrast ? 2.0 : 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.language_rounded,
                          color: isDark ? Colors.white : Colors.black,
                          size: 24,
                        ),
                        const SizedBox(width: 14),
                        Text(
                          strings.languageApp,
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.black,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Indonesian Radio Pill
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              context.read<LanguageProvider>().setLanguage('Indonesian');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF555555) : Colors.black,
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    strings.indonesian,
                                    style: TextStyle(
                                      color: isDark ? Colors.white : Colors.black,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDark ? Colors.white : Colors.black,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: selectedLanguage == 'Indonesian'
                                        ? Center(
                                            child: Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: isDark ? Colors.white : Colors.black,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // English Radio Pill
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              context.read<LanguageProvider>().setLanguage('English');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF555555) : Colors.black,
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    strings.english,
                                    style: TextStyle(
                                      color: isDark ? Colors.white : Colors.black,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDark ? Colors.white : Colors.black,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: selectedLanguage == 'English'
                                        ? Center(
                                            child: Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: isDark ? Colors.white : Colors.black,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              Divider(
                color: isDark ? const Color(0xFF333333) : const Color(0xFF222222),
                thickness: 0.8,
              ),
              const SizedBox(height: 16),

              // 7. FAQ
              _buildCard(
                icon: Icon(
                  Icons.help_outline_rounded,
                  color: isDark ? Colors.white : Colors.black,
                  size: 24,
                ),
                child: Text(
                  strings.faq,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? const Color(0xFF777777) : Colors.black,
                  size: 28,
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const FaqScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),

              // 8. About
              _buildCard(
                icon: Icon(
                  Icons.info_outline_rounded,
                  color: isDark ? Colors.white : Colors.black,
                  size: 24,
                ),
                child: Text(
                  strings.about,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? const Color(0xFF777777) : Colors.black,
                  size: 28,
                ),
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'Eye Lens',
                    applicationVersion: '1.0.0',
                    applicationLegalese: '© 2026 EyeLens Inc.',
                  );
                },
              ),

              const SizedBox(height: 16),
              Divider(
                color: isDark ? const Color(0xFF333333) : const Color(0xFF222222),
                thickness: 0.8,
              ),
              const SizedBox(height: 16),

              // 9. LOG OUT BUTTON
              _buildCard(
                isDestructive: true,
                icon: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFEF4444),
                  size: 24,
                ),
                child: Text(
                  strings.logOut,
                  style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFEF4444),
                  size: 28,
                ),
                onTap: _showLogoutDialog,
              ),

              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }
}
