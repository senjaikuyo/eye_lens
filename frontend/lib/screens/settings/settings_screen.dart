import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_strings.dart';
import '../../providers/language_provider.dart';
import '../../providers/theme_provider.dart';
import 'change_password_screen.dart';
import 'faq_screen.dart';
import 'widgets/language_selector_tile.dart';
import 'widgets/logout_dialog.dart';
import 'widgets/settings_list_tile.dart';
import 'widgets/theme_selector_tile.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoPlayAudio = false;

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

              // 1. Email Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.email,
                      style: const TextStyle(
                        color: Color(0xFF888888),
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
              SettingsListTile(
                icon: Icon(
                  Icons.lock_outline_rounded,
                  color: isDark ? Colors.white : Colors.black,
                  size: 24,
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
                child: Text(
                  strings.changePassword,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.black,
                    fontSize: 15,
                    fontWeight: isHighContrast ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),

              Divider(color: dividerColor, thickness: dividerThickness, height: 1),

              // 3. Auto-Play Audio
              SettingsListTile(
                icon: Icon(
                  Icons.graphic_eq_rounded,
                  color: isDark ? Colors.white : Colors.black,
                  size: 24,
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
                child: Text(
                  strings.autoPlayAudio,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.black,
                    fontSize: 15,
                    fontWeight: isHighContrast ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),

              Divider(color: dividerColor, thickness: dividerThickness, height: 1),

              // Theme Selector
              ThemeSelectorTile(
                isDark: isDark,
                isHighContrast: isHighContrast,
                strings: strings,
                selectedThemeMode: themeProvider.themeMode,
                onThemeSelected: (mode) {
                  themeProvider.setThemeMode(mode);
                },
              ),

              Divider(color: dividerColor, thickness: dividerThickness, height: 1),

              // 4. Language App Selector
              LanguageSelectorTile(
                isDark: isDark,
                isHighContrast: isHighContrast,
                strings: strings,
                selectedLanguage: selectedLanguage,
                onLanguageSelected: (lang) {
                  context.read<LanguageProvider>().setLanguage(lang);
                },
              ),

              Divider(color: dividerColor, thickness: dividerThickness, height: 1),

              // 5. FAQ
              SettingsListTile(
                icon: Icon(
                  Icons.help_outline_rounded,
                  color: isDark ? Colors.white : Colors.black,
                  size: 24,
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
                child: Text(
                  strings.faq,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.black,
                    fontSize: 15,
                    fontWeight: isHighContrast ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),

              Divider(color: dividerColor, thickness: dividerThickness, height: 1),

              // 6. About
              SettingsListTile(
                icon: Icon(
                  Icons.info_outline_rounded,
                  color: isDark ? Colors.white : Colors.black,
                  size: 24,
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
                child: Text(
                  strings.about,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.black,
                    fontSize: 15,
                    fontWeight: isHighContrast ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),

              Divider(color: dividerColor, thickness: dividerThickness, height: 1),

              const SizedBox(height: 18),

              // 7. Logout Row
              Material(
                color: isDark ? const Color(0xFF2A1517) : const Color(0xFFFFF1F2),
                child: InkWell(
                  onTap: () => LogoutDialog.show(context, strings: strings, isDark: isDark),
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
