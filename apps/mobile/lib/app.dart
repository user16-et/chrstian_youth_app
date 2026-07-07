import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/api_client.dart';
import 'features/home/home_shell.dart';
import 'i18n/app_i18n.dart';
import 'theme/app_theme.dart';

class ChristianYouthSuperApp extends StatefulWidget {
  const ChristianYouthSuperApp({super.key});

  @override
  State<ChristianYouthSuperApp> createState() => _ChristianYouthSuperAppState();
}

class _ChristianYouthSuperAppState extends State<ChristianYouthSuperApp> {
  final ApiClient _apiClient = ApiClient(
    baseUrl: const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://127.0.0.1:3000',
    ),
  );

  AppLanguage _language = AppLanguage.english;
  ThemeMode _themeMode = ThemeMode.system;

  void _setLanguage(AppLanguage language) {
    setState(() {
      _language = language;
    });
  }

  void _setThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: _language.locale,
      supportedLocales: const [Locale('en'), Locale('am')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      theme: AppTheme.light(
        useEthiopic: _language == AppLanguage.amharic,
      ),
      darkTheme: AppTheme.dark(
        useEthiopic: _language == AppLanguage.amharic,
      ),
      themeMode: _themeMode,
      home: HomeShell(
        language: _language,
        onLanguageChanged: _setLanguage,
        themeMode: _themeMode,
        onThemeModeChanged: _setThemeMode,
        apiClient: _apiClient,
      ),
    );
  }
}
