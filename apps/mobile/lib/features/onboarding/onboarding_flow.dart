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
