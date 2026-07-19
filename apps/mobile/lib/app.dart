import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/api_client.dart';
import 'data/call_controller.dart';
import 'data/session_store.dart';
import 'features/home/home_shell.dart';
import 'features/onboarding/onboarding_flow.dart';
import 'i18n/app_i18n.dart';
import 'theme/app_theme.dart';

/// What the app shows at launch: promo slides on the very first open, then a
/// sign-in step (skippable), then the home shell. Returning users skip
/// straight to home.
enum _LaunchStage { loading, onboarding, auth, home }

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
  _LaunchStage _stage = _LaunchStage.loading;

  @override
  void initState() {
    super.initState();
    _restorePreferences();
  }

  // Language, theme and launch stage survive restarts; best-effort so a
  // storage failure never blocks startup.
  Future<void> _restorePreferences() async {
    var stage = _LaunchStage.home;
    try {
      final prefs = await SharedPreferences.getInstance();
      final language = prefs.getString('pref_language');
      final theme = prefs.getString('pref_theme_mode');
      if (prefs.getBool('onboarding_seen_v1') != true) {
        stage = _LaunchStage.onboarding;
      }
      if (!mounted) return;
      setState(() {
        if (language == 'am') _language = AppLanguage.amharic;
        if (language == 'en') _language = AppLanguage.english;
        _themeMode = switch (theme) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => _themeMode,
        };
        _stage = stage;
      });
    } catch (_) {
      // Storage unavailable (some web contexts): land on home rather than
      // trapping the user in onboarding on every launch.
      if (mounted) setState(() => _stage = stage);
    }
  }

  Future<void> _finishOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_seen_v1', true);
    } catch (_) {}
    // Straight to home when a session is already stored; otherwise offer
    // sign-in / sign-up first.
    final stored = await SessionStore().load();
    if (!mounted) return;
    setState(
        () => _stage = stored == null ? _LaunchStage.auth : _LaunchStage.home);
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
      home: switch (_stage) {
        _LaunchStage.loading => const Scaffold(
            backgroundColor: Color(0xFF06342C),
            body: Center(
                child: Icon(Icons.church_rounded,
                    size: 72, color: Colors.white70)),
          ),
        _LaunchStage.onboarding => OnboardingScreen(
            language: _language,
            onDone: _finishOnboarding,
          ),
        _LaunchStage.auth => AuthWelcomeScreen(
            language: _language,
            apiClient: _apiClient,
            onAuthed: (session) async {
              await SessionStore().save(session);
              if (mounted) setState(() => _stage = _LaunchStage.home);
            },
            onSkip: () => setState(() => _stage = _LaunchStage.home),
          ),
        _LaunchStage.home => HomeShell(
            language: _language,
            onLanguageChanged: _setLanguage,
            themeMode: _themeMode,
            onThemeModeChanged: _setThemeMode,
            apiClient: _apiClient,
            callController: _callController,
          ),
      },
    );
  }
}
