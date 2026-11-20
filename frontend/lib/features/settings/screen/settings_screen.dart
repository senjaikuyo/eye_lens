import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:eye_lens/app/theme/app_colors.dart';
import 'package:eye_lens/core/constants/app_strings.dart';
import 'package:eye_lens/core/services/language_provider.dart';
import 'package:eye_lens/features/settings/logic/settings_provider.dart';
import 'package:eye_lens/core/services/display_preferences_provider.dart';
import 'package:eye_lens/features/settings/screen/change_password_screen.dart';
import 'package:eye_lens/features/settings/screen/faq_screen.dart';
import 'package:eye_lens/features/settings/screen/widgets/language_selector_tile.dart';
import 'package:eye_lens/features/settings/screen/widgets/logout_dialog.dart';
import 'package:eye_lens/features/settings/screen/widgets/settings_email_tile.dart';
import 'package:eye_lens/features/settings/screen/widgets/settings_nav_tile.dart';
import 'package:eye_lens/features/settings/screen/widgets/settings_logout_tile.dart';
import 'package:eye_lens/features/settings/screen/widgets/theme_selector_tile.dart';
import 'package:eye_lens/core/services/auth_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Segarkan data profil dari GET /api/me bila online. Saat offline,
    // data sesi lokal tetap ditampilkan.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        context.read<AuthProvider>().validateSession();
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<DisplayPreferencesProvider>();
    final isDark = themeProvider.isDark(context);
    final isHighContrast = themeProvider.isHighContrast;
    final strings = AppStrings.of(context);
    final languageProvider = context.watch<LanguageProvider>();
    final selectedLanguage = languageProvider.language;
    final settingsProvider = context.watch<SettingsProvider>();
    final autoPlayAudio = settingsProvider.autoPlayAudio;

    String email = '-';
    try {
      email = context.watch<AuthProvider>().email ?? '-';
    } catch (_) {
      // Provider tidak tersedia (mis. widget test terisolasi).
    }

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
              SettingsEmailTile(
                emailLabel: strings.email,
                email: email,
                isDark: isDark,
                isHighContrast: isHighContrast,
              ),

              const SizedBox(height: 14),
              Divider(
                color: dividerColor,
                thickness: dividerThickness,
                height: 1,
              ),

              // 2. Change Password
              SettingsNavTile(
                iconData: Icons.lock_outline_rounded,
                label: strings.changePassword,
                isDark: isDark,
                isHighContrast: isHighContrast,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ChangePasswordScreen(),
                    ),
                  );
                },
              ),

              Divider(
                color: dividerColor,
                thickness: dividerThickness,
                height: 1,
              ),

              SettingsAutoPlayTile(
                value: autoPlayAudio,
                isDark: isDark,
                isHighContrast: isHighContrast,
                title: strings.autoPlayAudio,
                subtitle: strings.autoPlayAudioSubtitle,
                semanticsLabel: strings.autoPlayAudioSemantics(autoPlayAudio),
                onChanged: (val) {
                  context.read<SettingsProvider>().setAutoPlayAudio(val);
                },
              ),

              // 4. Theme Selector
              ThemeSelectorTile(
                isDark: isDark,
                isHighContrast: isHighContrast,
                strings: strings,
                selectedThemeMode: themeProvider.themeMode,
                onThemeSelected: (mode) {
                  themeProvider.setThemeMode(mode);
                },
              ),

              Divider(
                color: dividerColor,
                thickness: dividerThickness,
                height: 1,
              ),

              // 5. Language App Selector
              LanguageSelectorTile(
                isDark: isDark,
                isHighContrast: isHighContrast,
                strings: strings,
                selectedLanguage: selectedLanguage,
                onLanguageSelected: (lang) {
                  context.read<LanguageProvider>().setLanguage(lang);
                },
              ),

              Divider(
                color: dividerColor,
                thickness: dividerThickness,
                height: 1,
              ),

              // 6. FAQ
              SettingsNavTile(
                iconData: Icons.help_outline_rounded,
                label: strings.faq,
                isDark: isDark,
                isHighContrast: isHighContrast,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const FaqScreen()),
                  );
                },
              ),

              Divider(
                color: dividerColor,
                thickness: dividerThickness,
                height: 1,
              ),

              // 7. About
              SettingsNavTile(
                iconData: Icons.info_outline_rounded,
                label: strings.about,
                isDark: isDark,
                isHighContrast: isHighContrast,
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'Eye Lens',
                    applicationVersion: '1.0.0',
                    applicationLegalese: '© 2026 EyeLens Inc.',
                  );
                },
              ),

              Divider(
                color: dividerColor,
                thickness: dividerThickness,
                height: 1,
              ),

              // 8. Logout Row
              SettingsLogoutTile(
                isDark: isDark,
                label: strings.logOut,
                onTap: () => LogoutDialog.show(
                  context,
                  strings: strings,
                  isDark: isDark,
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
