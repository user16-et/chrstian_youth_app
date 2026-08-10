import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/api_client.dart';
import 'data/call_controller.dart';
import 'data/session_store.dart';
import 'data/theme_controller.dart';
import 'features/home/home_shell.dart';
import 'features/onboarding/onboarding_flow.dart';
import 'i18n/app_i18n.dart';
import 'theme/app_theme.dart';

/// What the app shows at launch: promo slides on the very first open, then a
/// quick language + theme choice, then a sign-in step (skippable), then the
/// home shell. Returning users skip straight to home.
enum _LaunchStage { loading, onboarding, preferences, auth, home }

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
  final ThemeController _theme = ThemeController.instance;
  _LaunchStage _stage = _LaunchStage.loading;

  @override
  void initState() {
    super.initState();
    // The theme can be changed from anywhere (settings, the Bible reader's
    // day/night shortcut); rebuild + persist whenever it does.
    _theme.mode.addListener(_onThemeChanged);
    _restorePreferences();
  }

  void _onThemeChanged() {
    if (!mounted) return;
    setState(() {});
    _persistPreference(
        'pref_theme_mode',
        switch (_theme.mode.value) {
          ThemeMode.light => 'light',
          ThemeMode.dark => 'dark',
          ThemeMode.system => 'system',
        });
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
      _theme.mode.value = switch (theme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => _theme.mode.value,
      };
      setState(() {
        if (language == 'am') _language = AppLanguage.amharic;
        if (language == 'en') _language = AppLanguage.english;
        _stage = stage;
      });
    } catch (_) {
      // Storage unavailable (some web/release contexts where shared_preferences
      // has no plugin): we can't confirm the intro was already seen, so show it
      // rather than silently skipping it. Better to show the intro an extra time
      // than to have it be absent on first launch.
      if (mounted) setState(() => _stage = _LaunchStage.onboarding);
    }
  }

  // After the intro slides, let the user pick language + theme before anything
  // else. The flag is set here so the intro isn't shown again on next launch.
  Future<void> _finishOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_seen_v1', true);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _stage = _LaunchStage.preferences);
  }

  // Language + theme already applied (and persisted) as the user tapped; here we
  // just move on. Straight to home when a session is already stored; otherwise
  // offer sign-in / sign-up first.
  Future<void> _finishPreferences() async {
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
    _theme.mode.removeListener(_onThemeChanged);
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

  // Persistence + rebuild happen in _onThemeChanged when the controller fires.
  void _setThemeMode(ThemeMode mode) => _theme.mode.value = mode;

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
      themeMode: _theme.mode.value,
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
        _LaunchStage.preferences => LanguageThemeScreen(
            language: _language,
            themeMode: _theme.mode.value,
            onLanguageChanged: _setLanguage,
            onThemeModeChanged: _setThemeMode,
            onDone: _finishPreferences,
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
            themeMode: _theme.mode.value,
            onThemeModeChanged: _setThemeMode,
            apiClient: _apiClient,
            callController: _callController,
          ),
      },
    );
  }
}
