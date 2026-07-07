import 'package:flutter/material.dart';

class AppTheme {
  static const forest = Color(0xFF0B3328);
  static const evergreen = Color(0xFF16624A);
  static const mint = Color(0xFFBDE8D3);
  static const parchment = Color(0xFFF3EFE5);
  static const cream = Color(0xFFFFFCF5);
  static const coral = Color(0xFFF0674A);
  static const gold = Color(0xFFF2B84B);
  static const sky = Color(0xFF5C9CE6);
  static const ink = Color(0xFF14251E);
  static const muted = Color(0xFF68756F);
  static const night = Color(0xFF0D1117);
  static const nightSurface = Color(0xFF151B23);
  static const neonMint = Color(0xFF62F3C6);
  static const electricBlue = Color(0xFF7AB8FF);

  static const List<String> fontFallbacks = [
    'NotoSansEthiopic',
    'Noto Sans Ethiopic',
    'Noto Serif Ethiopic',
    'Abyssinica SIL',
    'Nyala',
    'Noto Sans',
    'sans-serif',
  ];

  static ThemeData light({bool useEthiopic = false}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: evergreen,
      brightness: Brightness.light,
      surface: cream,
    ).copyWith(
      primary: forest,
      onPrimary: Colors.white,
      secondary: coral,
      onSecondary: Colors.white,
      tertiary: gold,
      onTertiary: ink,
      primaryContainer: const Color(0xFFD9F0E4),
      onPrimaryContainer: ink,
      secondaryContainer: const Color(0xFFFFDED5),
      onSecondaryContainer: ink,
      tertiaryContainer: const Color(0xFFFFEDC5),
      onTertiaryContainer: ink,
      surface: cream,
      onSurface: ink,
      surfaceContainerHighest: const Color(0xFFE9F1EA),
      outline: const Color(0xFF9DAEA5),
    );
    return _build(
      scheme: scheme,
      scaffold: const Color(0xFFF1F4EA),
      card: Colors.white.withValues(alpha: .96),
      textMuted: muted,
      useEthiopic: useEthiopic,
      dark: false,
    );
  }

  static ThemeData dark({bool useEthiopic = false}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: neonMint,
      brightness: Brightness.dark,
      surface: nightSurface,
    ).copyWith(
      primary: neonMint,
      onPrimary: night,
      secondary: coral,
      onSecondary: Colors.white,
      tertiary: gold,
      onTertiary: night,
      primaryContainer: const Color(0xFF173C34),
      onPrimaryContainer: const Color(0xFFE6FFF4),
      secondaryContainer: const Color(0xFF4A241E),
      onSecondaryContainer: const Color(0xFFFFE5DE),
      tertiaryContainer: const Color(0xFF463512),
      onTertiaryContainer: const Color(0xFFFFF0C4),
      surface: nightSurface,
      onSurface: const Color(0xFFEAF2EF),
      surfaceContainerHighest: const Color(0xFF212A33),
      outline: const Color(0xFF61706A),
    );
    return _build(
      scheme: scheme,
      scaffold: night,
      card: const Color(0xFF18212A).withValues(alpha: .96),
      textMuted: const Color(0xFFB6C4BE),
      useEthiopic: useEthiopic,
      dark: true,
    );
  }

  static ThemeData _build({
    required ColorScheme scheme,
    required Color scaffold,
    required Color card,
    required Color textMuted,
    required bool useEthiopic,
    required bool dark,
  }) {
    final baseTextTheme = TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'Georgia',
        fontFamilyFallback: fontFallbacks,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
        height: 1,
        color: scheme.onSurface,
      ),
      displayMedium: TextStyle(
        fontFamily: 'Georgia',
        fontFamilyFallback: fontFallbacks,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
        height: 1.06,
        color: scheme.onSurface,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Georgia',
        fontFamilyFallback: fontFallbacks,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
        color: scheme.onSurface,
      ),
      headlineSmall: TextStyle(
        fontFamily: 'Georgia',
        fontFamilyFallback: fontFallbacks,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
        color: scheme.onSurface,
      ),
      titleLarge: TextStyle(
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
          color: scheme.onSurface,
          fontFamilyFallback: fontFallbacks),
      titleMedium: TextStyle(
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
          fontFamilyFallback: fontFallbacks),
      bodyLarge: TextStyle(
          height: 1.5,
          color: scheme.onSurface,
          fontFamilyFallback: fontFallbacks),
      bodyMedium: TextStyle(
          height: 1.45,
          color: scheme.onSurface,
          fontFamilyFallback: fontFallbacks),
      bodySmall: TextStyle(
          height: 1.4, color: textMuted, fontFamilyFallback: fontFallbacks),
      labelLarge: TextStyle(
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
          color: scheme.onSurface,
          fontFamilyFallback: fontFallbacks),
    );

    final localizedTextTheme = useEthiopic
        ? baseTextTheme.apply(fontFamily: 'NotoSansEthiopic').copyWith(
              displayLarge: baseTextTheme.displayLarge?.copyWith(
                  fontFamily: 'NotoSansEthiopic',
                  letterSpacing: 0,
                  height: 1.15),
              displayMedium: baseTextTheme.displayMedium?.copyWith(
                  fontFamily: 'NotoSansEthiopic',
                  letterSpacing: 0,
                  height: 1.15),
              headlineMedium: baseTextTheme.headlineMedium?.copyWith(
                  fontFamily: 'NotoSansEthiopic',
                  letterSpacing: 0,
                  height: 1.2),
              headlineSmall: baseTextTheme.headlineSmall?.copyWith(
                  fontFamily: 'NotoSansEthiopic',
                  letterSpacing: 0,
                  height: 1.2),
            )
        : baseTextTheme;

    final subtleBorder = BorderSide(
        color: dark ? const Color(0x445D756B) : const Color(0x2412372A));
    final inputFill = dark ? const Color(0xFF101820) : Colors.white;

    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      brightness: dark ? Brightness.dark : Brightness.light,
      useMaterial3: true,
      fontFamily: useEthiopic ? 'NotoSansEthiopic' : null,
      fontFamilyFallback: fontFallbacks,
      textTheme: localizedTextTheme,
      visualDensity: VisualDensity.standard,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      }),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        iconTheme: IconThemeData(color: scheme.onSurface),
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontFamily: useEthiopic ? 'NotoSansEthiopic' : 'Georgia',
          fontFamilyFallback: fontFallbacks,
          fontSize: 21,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: dark ? 1 : 0,
        color: card,
        margin: EdgeInsets.zero,
        shadowColor: dark ? Colors.black45 : forest.withValues(alpha: .12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: subtleBorder,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        elevation: 0,
        backgroundColor: card,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? scheme.primary
                  : textMuted,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontSize: 11,
              color: states.contains(WidgetState.selected)
                  ? scheme.primary
                  : textMuted,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w900
                  : FontWeight.w700,
              fontFamilyFallback: fontFallbacks,
            )),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: card,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.primary),
        unselectedIconTheme: IconThemeData(color: textMuted),
        selectedLabelTextStyle: TextStyle(
            color: scheme.primary,
            fontWeight: FontWeight.w900,
            fontFamilyFallback: fontFallbacks),
        unselectedLabelTextStyle: TextStyle(
            color: textMuted,
            fontWeight: FontWeight.w700,
            fontFamilyFallback: fontFallbacks),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        labelStyle: TextStyle(color: textMuted),
        hintStyle: TextStyle(color: textMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: subtleBorder,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.primary, width: 1.8),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
          elevation: dark ? 1 : 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(
              fontWeight: FontWeight.w900, fontFamilyFallback: fontFallbacks),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          side: BorderSide(color: scheme.outline),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(
              fontWeight: FontWeight.w800, fontFamilyFallback: fontFallbacks),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: inputFill,
        selectedColor: scheme.primaryContainer,
        side: subtleBorder,
        labelStyle: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.w800,
            fontFamilyFallback: fontFallbacks),
        secondaryLabelStyle: TextStyle(
            color: scheme.onPrimaryContainer,
            fontWeight: FontWeight.w900,
            fontFamilyFallback: fontFallbacks),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: textMuted,
        labelStyle: const TextStyle(
            fontWeight: FontWeight.w900, fontFamilyFallback: fontFallbacks),
        dividerColor: Colors.transparent,
        indicatorColor: scheme.secondary,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark ? const Color(0xFFEAF2EF) : ink,
        contentTextStyle: TextStyle(
            color: dark ? night : Colors.white,
            fontFamilyFallback: fontFallbacks),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        titleTextStyle: localizedTextTheme.titleLarge,
        contentTextStyle: localizedTextTheme.bodyMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        modalBackgroundColor: card,
        showDragHandle: true,
      ),
      dividerTheme:
          DividerThemeData(color: scheme.outline.withValues(alpha: .35)),
    );
  }
}
