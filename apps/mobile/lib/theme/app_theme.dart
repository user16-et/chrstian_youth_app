import 'package:flutter/material.dart';

/// Warm & Spiritual Modern design system.
///
/// Palette: deep teal primary, warm amber + terracotta accents on warm cream
/// grounds. Typography: Sora for headings (friendly, rounded), Plus Jakarta
/// Sans for body/UI, Noto Sans Ethiopic for Amharic. Soft shadows, generous
/// rounding, glowing accents in dark mode.
class AppTheme {
  // Core palette
  static const teal = Color(0xFF0E7C6B); // primary
  static const tealDeep = Color(0xFF06342C); // deep teal (on-container text)
  static const tealGlow = Color(0xFF43D6BC); // dark-mode primary
  static const amber = Color(0xFFF4A23B); // warm accent
  static const terracotta = Color(0xFFE8674C); // secondary accent
  static const creamBg = Color(0xFFFBF7EF); // light scaffold
  static const creamSurface = Color(0xFFFFFDF8); // light card
  static const warmInk = Color(0xFF1E2422); // light text
  static const warmMutedText = Color(0xFF7C7568); // muted text (warm grey)
  static const nightBg = Color(0xFF12181B); // dark scaffold
  static const nightSurface = Color(0xFF1B2429); // dark card

  // Legacy aliases kept so existing screens keep compiling — remapped to the
  // new palette so their accents harmonize with the redesign.
  static const forest = tealDeep;
  static const evergreen = teal;
  static const mint = Color(0xFFCFEDE6);
  static const parchment = Color(0xFFF1EADD);
  static const cream = creamSurface;
  static const coral = terracotta;
  static const gold = amber;
  static const sky = Color(0xFF5FA8C9);
  static const ink = warmInk;
  static const muted = warmMutedText;
  static const night = nightBg;
  static const neonMint = tealGlow;
  static const electricBlue = Color(0xFF7FC6F2);

  static const String _display = 'Sora';
  static const String _body = 'PlusJakartaSans';

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
      seedColor: teal,
      brightness: Brightness.light,
      surface: creamSurface,
    ).copyWith(
      primary: teal,
      onPrimary: Colors.white,
      secondary: terracotta,
      onSecondary: Colors.white,
      tertiary: amber,
      onTertiary: const Color(0xFF3A2A10),
      primaryContainer: mint,
      onPrimaryContainer: tealDeep,
      secondaryContainer: const Color(0xFFFBD9D0),
      onSecondaryContainer: const Color(0xFF5A1E12),
      tertiaryContainer: const Color(0xFFFCE7C4),
      onTertiaryContainer: const Color(0xFF4A3308),
      surface: creamSurface,
      onSurface: warmInk,
      onSurfaceVariant: warmMutedText,
      surfaceContainerHighest: const Color(0xFFF1EADD),
      outline: const Color(0xFFC3B9A8),
      outlineVariant: const Color(0xFFE3DACB),
      shadow: const Color(0xFF3A2E1A),
    );
    return _build(
      scheme: scheme,
      scaffold: creamBg,
      card: creamSurface,
      textMuted: warmMutedText,
      useEthiopic: useEthiopic,
      dark: false,
    );
  }

  static ThemeData dark({bool useEthiopic = false}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: tealGlow,
      brightness: Brightness.dark,
      surface: nightSurface,
    ).copyWith(
      primary: tealGlow,
      onPrimary: const Color(0xFF04231E),
      secondary: const Color(0xFFF2896F),
      onSecondary: const Color(0xFF3A140C),
      tertiary: amber,
      onTertiary: const Color(0xFF3A2A10),
      primaryContainer: const Color(0xFF11453B),
      onPrimaryContainer: const Color(0xFFBFF3E7),
      secondaryContainer: const Color(0xFF4A231A),
      onSecondaryContainer: const Color(0xFFFFDBD1),
      tertiaryContainer: const Color(0xFF463414),
      onTertiaryContainer: const Color(0xFFFCE7C4),
      surface: nightSurface,
      onSurface: const Color(0xFFE9EFEC),
      onSurfaceVariant: const Color(0xFFAFBAB5),
      surfaceContainerHighest: const Color(0xFF232E33),
      outline: const Color(0xFF56635E),
      outlineVariant: const Color(0xFF313C40),
      shadow: Colors.black,
    );
    return _build(
      scheme: scheme,
      scaffold: nightBg,
      card: nightSurface,
      textMuted: const Color(0xFFAFBAB5),
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
    TextStyle display(double? height, FontWeight weight) => TextStyle(
          fontFamily: _display,
          fontFamilyFallback: fontFallbacks,
          fontWeight: weight,
          letterSpacing: -0.3,
          height: height,
          color: scheme.onSurface,
        );
    TextStyle bodyStyle(double height, {Color? color, FontWeight? weight}) => TextStyle(
          fontFamily: _body,
          fontFamilyFallback: fontFallbacks,
          height: height,
          fontWeight: weight,
          color: color ?? scheme.onSurface,
        );

    final baseTextTheme = TextTheme(
      displayLarge: display(1.02, FontWeight.w800),
      displayMedium: display(1.05, FontWeight.w800),
      displaySmall: display(1.08, FontWeight.w700),
      headlineLarge: display(1.1, FontWeight.w800),
      headlineMedium: display(1.15, FontWeight.w700),
      headlineSmall: display(1.2, FontWeight.w700),
      titleLarge: TextStyle(
        fontFamily: _display,
        fontFamilyFallback: fontFallbacks,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: scheme.onSurface,
      ),
      titleMedium: bodyStyle(1.3, weight: FontWeight.w700),
      titleSmall: bodyStyle(1.3, weight: FontWeight.w600),
      bodyLarge: bodyStyle(1.5, weight: FontWeight.w400),
      bodyMedium: bodyStyle(1.45, weight: FontWeight.w400),
      bodySmall: bodyStyle(1.4, color: textMuted, weight: FontWeight.w400),
      labelLarge: bodyStyle(1.2, weight: FontWeight.w700),
      labelMedium: bodyStyle(1.2, weight: FontWeight.w600),
      labelSmall: bodyStyle(1.2, color: textMuted, weight: FontWeight.w600),
    );

    // In Amharic, render everything with the Ethiopic face and give headings a
    // little more line-height for the taller script.
    final textTheme = useEthiopic
        ? baseTextTheme.apply(fontFamily: 'NotoSansEthiopic').copyWith(
              displayLarge: baseTextTheme.displayLarge?.copyWith(fontFamily: 'NotoSansEthiopic', height: 1.2),
              displayMedium: baseTextTheme.displayMedium?.copyWith(fontFamily: 'NotoSansEthiopic', height: 1.22),
              headlineMedium: baseTextTheme.headlineMedium?.copyWith(fontFamily: 'NotoSansEthiopic', height: 1.28),
              headlineSmall: baseTextTheme.headlineSmall?.copyWith(fontFamily: 'NotoSansEthiopic', height: 1.28),
              titleLarge: baseTextTheme.titleLarge?.copyWith(fontFamily: 'NotoSansEthiopic', height: 1.3),
            )
        : baseTextTheme;

    final subtleBorder = BorderSide(
        color: dark ? const Color(0x33566360) : const Color(0x1F1E2422));
    final inputFill = dark ? const Color(0xFF141D21) : const Color(0xFFFFFFFF);
    final headingFont = useEthiopic ? 'NotoSansEthiopic' : _display;

    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      brightness: dark ? Brightness.dark : Brightness.light,
      useMaterial3: true,
      fontFamily: useEthiopic ? 'NotoSansEthiopic' : _body,
      fontFamilyFallback: fontFallbacks,
      textTheme: textTheme,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
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
          fontFamily: headingFont,
          fontFamilyFallback: fontFallbacks,
          fontSize: 21,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: dark ? 0 : 6,
        color: card,
        margin: EdgeInsets.zero,
        shadowColor: dark ? Colors.transparent : teal.withValues(alpha: .10),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: dark ? subtleBorder : BorderSide.none,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: card,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected) ? scheme.onPrimaryContainer : textMuted,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontFamily: _body,
              fontSize: 11.5,
              color: states.contains(WidgetState.selected) ? scheme.primary : textMuted,
              fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
              fontFamilyFallback: fontFallbacks,
            )),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: card,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: textMuted),
        selectedLabelTextStyle: TextStyle(
            color: scheme.primary, fontWeight: FontWeight.w800, fontFamily: _body, fontFamilyFallback: fontFallbacks),
        unselectedLabelTextStyle: TextStyle(
            color: textMuted, fontWeight: FontWeight.w600, fontFamily: _body, fontFamilyFallback: fontFallbacks),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        labelStyle: TextStyle(color: textMuted, fontFamily: _body),
        hintStyle: TextStyle(color: textMuted, fontFamily: _body),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: subtleBorder),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: scheme.primary, width: 1.8)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          elevation: dark ? 0 : 2,
          shadowColor: scheme.primary.withValues(alpha: .35),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontFamily: _body, fontWeight: FontWeight.w700, fontFamilyFallback: fontFallbacks),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontFamily: _body, fontWeight: FontWeight.w700, fontFamilyFallback: fontFallbacks),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(fontFamily: _body, fontWeight: FontWeight.w700, fontFamilyFallback: fontFallbacks),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: dark ? const Color(0xFF1F292E) : const Color(0xFFF3ECDF),
        selectedColor: scheme.primaryContainer,
        side: BorderSide.none,
        labelStyle: TextStyle(
            color: scheme.onSurface, fontFamily: _body, fontWeight: FontWeight.w700, fontFamilyFallback: fontFallbacks),
        secondaryLabelStyle: TextStyle(
            color: scheme.onPrimaryContainer, fontFamily: _body, fontWeight: FontWeight.w800, fontFamilyFallback: fontFallbacks),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: textMuted,
        labelStyle: const TextStyle(fontFamily: _body, fontWeight: FontWeight.w800, fontFamilyFallback: fontFallbacks),
        unselectedLabelStyle: const TextStyle(fontFamily: _body, fontWeight: FontWeight.w600, fontFamilyFallback: fontFallbacks),
        dividerColor: Colors.transparent,
        indicatorColor: scheme.secondary,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark ? const Color(0xFFE9EFEC) : warmInk,
        contentTextStyle: TextStyle(
            color: dark ? nightBg : Colors.white, fontFamily: _body, fontFamilyFallback: fontFallbacks),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        modalBackgroundColor: card,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
      listTileTheme: const ListTileThemeData(
        titleTextStyle: TextStyle(fontFamily: _body, fontWeight: FontWeight.w700, fontFamilyFallback: fontFallbacks),
        subtitleTextStyle: TextStyle(fontFamily: _body, fontFamilyFallback: fontFallbacks),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.secondary,
        foregroundColor: scheme.onSecondary,
        elevation: dark ? 0 : 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
