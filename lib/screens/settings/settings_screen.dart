import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_strings.dart';
import '../../providers/language_provider.dart';
import '../../providers/theme_provider.dart';
import '../auth/login_screen.dart';
import 'change_password_screen.dart';
import 'faq_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoPlayAudio = false;

  void _showLogoutDialog(BuildContext context, AppStrings strings, bool isDark) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
            onPressed: () => Navigator.of(dialogContext).pop(),
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
              Navigator.of(dialogContext).pop();
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

  Widget _buildListTile({
    required Widget icon,
    required Widget child,
    VoidCallback? onTap,
    Widget? trailing,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: Row(
            children: [
              icon,
              const SizedBox(width: 16),
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

    final dividerColor = isHighContrast
        ? (isDark ? Colors.white : Colors.black)
        : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEDEDED));
    final dividerThickness = isHighContrast ? 1.5 : 0.8;

    return Scaffold(
      backgroundColor: isDark ? AppColors.black : AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              // Header: Back Button + "Settings"
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
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
              ),

              const SizedBox(height: 24),

              // 1. Header Email Section (clean flat text)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.email,
                      style: TextStyle(
                        color: isDark ? const Color(0xFF888888) : const Color(0xFF888888),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'afifhamzah21@gmail.com',
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.black,
                        fontSize: 15,
                        fontWeight: isHighContrast ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),
              Divider(color: dividerColor, thickness: dividerThickness, height: 1),

              // 2. Change Password
              _buildListTile(
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
                    fontWeight: isHighContrast ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? const Color(0xFF777777) : Colors.black,
                  size: 26,
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ChangePasswordScreen(),
                    ),
                  );
                },
              ),

              Divider(color: dividerColor, thickness: dividerThickness, height: 1),

              // 3. Auto-Play Audio (with graphic_eq waveform icon from new UI)
              _buildListTile(
                icon: Icon(
                  Icons.graphic_eq_rounded,
                  color: isDark ? Colors.white : Colors.black,
                  size: 24,
                ),
                child: Text(
                  strings.autoPlayAudio,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.black,
                    fontSize: 15,
                    fontWeight: isHighContrast ? FontWeight.w700 : FontWeight.w500,
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

              Divider(color: dividerColor, thickness: dividerThickness, height: 1),

              // 4. Language App Selector (with translate icon from new UI)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.translate_rounded,
                      color: isDark ? Colors.white : Colors.black,
                      size: 24,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.languageApp,
                            style: TextStyle(
                              color: isDark ? Colors.white : AppColors.black,
                              fontSize: 15,
                              fontWeight: isHighContrast ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              // Indonesian Radio Pill
                              Expanded(
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () {
                                      context.read<LanguageProvider>().setLanguage('Indonesian');
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isHighContrast
                                              ? (isDark ? Colors.white : Colors.black)
                                              : (isDark ? const Color(0xFF555555) : Colors.black),
                                          width: isHighContrast ? 1.8 : 1.0,
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
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
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
                              ),
                              const SizedBox(width: 8),

                              // English Radio Pill
                              Expanded(
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () {
                                      context.read<LanguageProvider>().setLanguage('English');
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isHighContrast
                                              ? (isDark ? Colors.white : Colors.black)
                                              : (isDark ? const Color(0xFF555555) : Colors.black),
                                          width: isHighContrast ? 1.8 : 1.0,
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
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
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
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Divider(color: dividerColor, thickness: dividerThickness, height: 1),

              // 5. FAQ
              _buildListTile(
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
                    fontWeight: isHighContrast ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? const Color(0xFF777777) : Colors.black,
                  size: 26,
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const FaqScreen(),
                    ),
                  );
                },
              ),

              Divider(color: dividerColor, thickness: dividerThickness, height: 1),

              // 6. About
              _buildListTile(
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
                    fontWeight: isHighContrast ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? const Color(0xFF777777) : Colors.black,
                  size: 26,
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

              Divider(color: dividerColor, thickness: dividerThickness, height: 1),

              const SizedBox(height: 18),

              // 7. LOGOUT ROW with soft pink container (matching new UI setting.png)
              Material(
                color: isDark ? const Color(0xFF2A1517) : const Color(0xFFFFF1F2),
                child: InkWell(
                  onTap: () => _showLogoutDialog(context, strings, isDark),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.logout_rounded,
                          color: Color(0xFFEF4444),
                          size: 24,
                        ),
                        const SizedBox(width: 16),
                        Text(
                          strings.logOut,
                          style: const TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }
}
