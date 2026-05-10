import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/constants/app_colors.dart';
import 'core/localization/app_language.dart';
import 'game/ui/screens/home_screen.dart';
import 'services/local/settings_repository.dart';

class BorderWarsLiteApp extends StatefulWidget {
  const BorderWarsLiteApp({super.key});

  @override
  State<BorderWarsLiteApp> createState() => _BorderWarsLiteAppState();
}

class _BorderWarsLiteAppState extends State<BorderWarsLiteApp> {
  final SettingsRepository _settingsRepository = const SettingsRepository();

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final settings = await _settingsRepository.loadSettings();
    AppLanguageController.setLanguageCode(settings.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLanguageController.languageCode,
      builder: (context, languageCode, _) {
        return MaterialApp(
          title: 'Border Wars Lite',
          debugShowCheckedModeBanner: false,
          locale: Locale(AppLanguageController.normalize(languageCode)),
          supportedLocales: const <Locale>[
            Locale('tr'),
            Locale('en'),
            Locale('de'),
          ],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.humanBlue,
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: AppColors.premiumBackground,
            useMaterial3: true,
            fontFamily: 'Roboto',
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              foregroundColor: AppColors.premiumText,
              elevation: 0,
              centerTitle: true,
            ),
          ),
          home: const HomeScreen(),
        );
      },
    );
  }
}
