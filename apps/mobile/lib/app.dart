import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/api_client.dart';
import 'data/call_controller.dart';
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

  late final CallController _callController = CallController(apiClient: _apiClient);

  AppLanguage _language = AppLanguage.english;
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _restorePreferences();
  }

  // Language and theme survive restarts; best-effort so a storage failure
  // never blocks startup.
  Future<void> _restorePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final language = prefs.getString('pref_language');
      final theme = prefs.getString('pref_theme_mode');
      if (!mounted || (language == null && theme == null)) return;
      setState(() {
        if (language == 'am') _language = AppLanguage.amharic;
        if (language == 'en') _language = AppLanguage.english;
        _themeMode = switch (theme) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => _themeMode,
        };
      });
    } catch (_) {}
  }

  Future<void> _persistPreference(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (_) {}
  }

  @override
  void dispose() {
    _callController.dispose();
    super.dispose();
  }

  void _setLanguage(AppLanguage language) {
    setState(() {
      _language = language;
    });
    _persistPreference(
        'pref_language', language == AppLanguage.amharic ? 'am' : 'en');
  }

  void _setThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
    _persistPreference(
        'pref_theme_mode',
        switch (mode) {
          ThemeMode.light => 'light',
          ThemeMode.dark => 'dark',
          ThemeMode.system => 'system',
        });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      builder: (context, child) =>
          CallScope(controller: _callController, child: child ?? const SizedBox.shrink()),
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
        callController: _callController,
      ),
    );
  }
}
