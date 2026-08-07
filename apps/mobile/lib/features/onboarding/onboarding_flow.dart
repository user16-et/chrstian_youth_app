import 'package:flutter/material.dart';

import '../../data/api_client.dart';
import '../../data/app_models.dart';
import '../../i18n/app_i18n.dart';
import '../home/account_portal.dart';

/// First-launch promotional slides with a skip option. Purely illustrative —
/// gradient art + icons, no bundled image assets, so it works offline and
/// keeps the APK small.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.language,
    required this.onDone,
  });

  final AppLanguage language;
  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  bool get _en => widget.language == AppLanguage.english;
  String _t(String en, String am) => _en ? en : am;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_Slide> get _slides => [
        _Slide(
          icon: Icons.church_rounded,
          colors: const [Color(0xFF06342C), Color(0xFF0E7C6B)],
          title: _t('Your whole faith life.\nOne app.', 'ሙሉ የእምነት ሕይወትዎ።\nበአንድ መተግበሪያ።'),
          body: _t(
              'Church, Bible, ministries, events and community — built for Ethiopian Christian youth.',
              'ቤተ ክርስቲያን፣ መጽሐፍ ቅዱስ፣ አገልግሎቶች፣ ዝግጅቶች እና ማህበረሰብ — ለኢትዮጵያ ክርስቲያን ወጣቶች የተሰራ።'),
        ),
        _Slide(
          icon: Icons.menu_book_rounded,
          colors: const [Color(0xFF16324F), Color(0xFF3C6997)],
          title: _t('The Word, always with you', 'ቃሉ ሁልጊዜ ከእርስዎ ጋር'),
          body: _t(
              'Read in Amharic and English, download for offline, keep notes, streaks and reading plans.',
              'በአማርኛና በእንግሊዝኛ ያንብቡ፣ ከመስመር ውጭ ያውርዱ፣ ማስታወሻዎችን፣ ተከታታይነትን እና የንባብ እቅዶችን ይያዙ።'),
        ),
        _Slide(
          icon: Icons.diversity_3_rounded,
          colors: const [Color(0xFF7A3B2E), Color(0xFFB85C38)],
          title: _t('Grow together', 'አብረን እናድግ'),
          body: _t(
              'Stories, groups, prayer chains, mentors and events — a living community around you.',
              'ታሪኮች፣ ቡድኖች፣ የጸሎት ሰንሰለቶች፣ አማካሪዎች እና ዝግጅቶች — በዙሪያዎ ያለ ሕያው ማህበረሰብ።'),
        ),
        _Slide(
          icon: Icons.favorite_rounded,
          colors: const [Color(0xFF5C2A3D), Color(0xFF9E455C)],
          title: _t('Purposeful connections', 'ዓላማ ያለው ግንኙነት'),
          body: _t(
              'Godly courtship, marketplace, giving and serving — everything in one trusted place.',
              'እግዚአብሔርን የሚያከብር ጓደኝነት፣ ገበያ፣ ልገሳ እና አገልግሎት — ሁሉም በአንድ የታመነ ቦታ።'),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final slides = _slides;
    final last = _index == slides.length - 1;
    return Scaffold(
      body: Stack(children: [
        PageView.builder(
          controller: _controller,
          itemCount: slides.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (context, i) => _SlideView(slide: slides[i]),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: TextButton(
              onPressed: widget.onDone,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: Text(_t('Skip', 'ዝለል')),
            ),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 26),
              child: Row(children: [
                for (var i = 0; i < slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 6),
                    width: i == _index ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _index ? Colors.white : Colors.white54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: slides[_index].colors.first,
                  ),
                  onPressed: last
                      ? widget.onDone
                      : () => _controller.nextPage(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOut),
                  child: Text(last
                      ? _t('Get started', 'ጀምር')
                      : _t('Next', 'ቀጣይ')),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Slide {
  const _Slide({
    required this.icon,
    required this.colors,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final List<Color> colors;
  final String title;
  final String body;
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: slide.colors,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(30, 0, 30, 96),
      // Centers when there's room, scrolls on small screens / large fonts —
      // never overflows.
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 46),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(slide.icon, size: 64, color: Colors.white),
                ),
                const SizedBox(height: 34),
                Text(slide.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        height: 1.2,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                Text(slide.body,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 16, height: 1.45)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown once, right after the intro slides: pick language + theme before the
/// sign-in step. Selections apply (and persist) immediately as they're tapped,
/// so the screen itself previews the choice — Amharic labels and the chosen
/// light/dark theme update live.
class LanguageThemeScreen extends StatelessWidget {
  const LanguageThemeScreen({
    super.key,
    required this.language,
    required this.themeMode,
    required this.onLanguageChanged,
    required this.onThemeModeChanged,
    required this.onDone,
  });

  final AppLanguage language;
  final ThemeMode themeMode;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final VoidCallback onDone;

  bool get _en => language == AppLanguage.english;
  String _t(String en, String am) => _en ? en : am;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t('Make it yours', 'እንደፈለጉት ያድርጉት'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                _t('Choose your language and theme. You can change these any '
                    'time in settings.',
                    'ቋንቋዎን እና ገጽታዎን ይምረጡ። በማንኛውም ጊዜ ከቅንብሮች መቀየር ይችላሉ።'),
                style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
              ),
              const SizedBox(height: 26),
              Expanded(
                child: ListView(
                  children: [
                    _SectionLabel(text: _t('Language', 'ቋንቋ')),
                    const SizedBox(height: 10),
                    _ChoiceTile(
                      icon: Icons.translate_rounded,
                      title: 'English',
                      subtitle: _t('Use English', 'እንግሊዝኛ ይጠቀሙ'),
                      selected: language == AppLanguage.english,
                      onTap: () => onLanguageChanged(AppLanguage.english),
                    ),
                    const SizedBox(height: 10),
                    _ChoiceTile(
                      icon: Icons.translate_rounded,
                      title: 'አማርኛ',
                      subtitle: _t('Use Amharic', 'አማርኛ ይጠቀሙ'),
                      selected: language == AppLanguage.amharic,
                      onTap: () => onLanguageChanged(AppLanguage.amharic),
                    ),
                    const SizedBox(height: 28),
                    _SectionLabel(text: _t('Theme', 'ገጽታ')),
                    const SizedBox(height: 10),
                    _ChoiceTile(
                      icon: Icons.brightness_auto_rounded,
                      title: _t('System default', 'የስርዓት ነባሪ'),
                      subtitle: _t('Match your phone', 'ከስልክዎ ጋር ያዛምዱ'),
                      selected: themeMode == ThemeMode.system,
                      onTap: () => onThemeModeChanged(ThemeMode.system),
                    ),
                    const SizedBox(height: 10),
                    _ChoiceTile(
                      icon: Icons.light_mode_rounded,
                      title: _t('Light', 'ብርሃናማ'),
                      subtitle: _t('Bright background', 'ብሩህ ዳራ'),
                      selected: themeMode == ThemeMode.light,
                      onTap: () => onThemeModeChanged(ThemeMode.light),
                    ),
                    const SizedBox(height: 10),
                    _ChoiceTile(
                      icon: Icons.dark_mode_rounded,
                      title: _t('Dark', 'ጨለማ'),
                      subtitle: _t('Easy on the eyes', 'ለዓይን ምቹ'),
                      selected: themeMode == ThemeMode.dark,
                      onTap: () => onThemeModeChanged(ThemeMode.dark),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onDone,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(_t('Continue', 'ቀጥል')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: .8,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.primaryContainer : colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon,
                  color:
                      selected ? colors.onPrimaryContainer : colors.onSurfaceVariant),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? colors.onPrimaryContainer
                              : colors.onSurface,
                        )),
                    Text(subtitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: selected
                              ? colors.onPrimaryContainer.withValues(alpha: .8)
                              : colors.onSurfaceVariant,
                        )),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? colors.primary : colors.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pre-home authentication step: sign in or create an account (reusing the
/// full portal forms, OTP included), or continue exploring signed out.
class AuthWelcomeScreen extends StatelessWidget {
  const AuthWelcomeScreen({
    super.key,
    required this.language,
    required this.apiClient,
    required this.onAuthed,
    required this.onSkip,
  });

  final AppLanguage language;
  final ApiClient apiClient;
  final ValueChanged<AuthResult> onAuthed;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final en = language == AppLanguage.english;
    return Scaffold(
      appBar: AppBar(
        title: Text(en ? 'Welcome' : 'እንኳን ደህና መጡ'),
        actions: [
          TextButton(
            onPressed: onSkip,
            child: Text(en ? 'Explore first' : 'መጀመሪያ ይመልከቱ'),
          ),
        ],
      ),
      body: AccountPortal(
        language: language,
        apiClient: apiClient,
        session: null,
        onAuthChanged: (session) {
          if (session != null) onAuthed(session);
        },
        onDataChanged: () async {},
      ),
    );
  }
}
