import 'package:flutter/material.dart';

import '../../data/api_client.dart';
import '../../i18n/app_i18n.dart';
import 'relationship_social.dart';

bool _en(AppLanguage l) => l == AppLanguage.english;
String _tr(AppLanguage l, String en, String am) => _en(l) ? en : am;

/// Tinder-style swipe deck for courtship discovery. Swipe right / tap the heart
/// to express interest (a mutual like is a match); swipe left / tap X to pass.
class CourtshipSwipeScreen extends StatefulWidget {
  const CourtshipSwipeScreen({
    super.key,
    required this.apiClient,
    required this.token,
    required this.language,
  });

  final ApiClient apiClient;
  final String token;
  final AppLanguage language;

  @override
  State<CourtshipSwipeScreen> createState() => _CourtshipSwipeScreenState();
}

class _CourtshipSwipeScreenState extends State<CourtshipSwipeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
  List<Map<String, dynamic>> _cards = const [];
  bool _loading = true;
  String _status = '';
  Offset _drag = Offset.zero;
  Offset _flyFrom = Offset.zero;
  Offset _flyTo = Offset.zero;
  VoidCallback? _onFlyDone;

  AppLanguage get lang => widget.language;

  @override
  void initState() {
    super.initState();
    _anim.addListener(() => setState(() => _drag = Offset.lerp(_flyFrom, _flyTo, _anim.value)!));
    _anim.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        final done = _onFlyDone;
        _onFlyDone = null;
        done?.call();
      }
    });
    _load();
  }

  Future<void> _load() async {
    try {
      final cards = await widget.apiClient.discoverRelationships(widget.token, {});
      if (mounted) setState(() { _cards = cards; _loading = false; });
    } catch (error) {
      if (mounted) setState(() { _status = error.toString().replaceFirst('HttpException: ', ''); _loading = false; });
    }
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  void _animateTo(Offset to, {VoidCallback? onDone}) {
    _flyFrom = _drag;
    _flyTo = to;
    _onFlyDone = onDone;
    _anim.forward(from: 0);
  }

  void _fling(bool like) {
    if (_cards.isEmpty) return;
    final width = MediaQuery.sizeOf(context).width + 200;
    _animateTo(Offset(like ? width : -width, _drag.dy), onDone: () => _commit(like));
  }

  void _commit(bool like) {
    if (_cards.isEmpty) return;
    final card = _cards.first;
    setState(() { _cards = _cards.sublist(1); _drag = Offset.zero; });
    if (like) _like(card);
  }

  Future<void> _like(Map<String, dynamic> card) async {
    final userId = card['userId']?.toString() ?? '';
    if (userId.isEmpty) return;
    try {
      final res = await widget.apiClient.expressRelationshipInterest(widget.token, userId,
          _tr(lang, 'I would value a respectful, prayerful introduction.', 'በአክብሮት እና በጸሎት መተዋወቅ እፈልጋለሁ።'));
      if (res is Map && res['matched'] == true && mounted) _showMatch(card);
    } catch (_) {
      // A failed like shouldn't block swiping.
    }
  }

  void _showMatch(Map<String, dynamic> card) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.favorite_rounded, color: Theme.of(context).colorScheme.primary, size: 44),
        title: Text(_tr(lang, "It's a match! 🎉", 'ተገጣጠማችሁ! 🎉')),
        content: Text(_tr(lang, 'You and ${card['fullName'] ?? ''} liked each other.',
            'እርስዎ እና ${card['fullName'] ?? ''} ተፋቅራችኋል።')),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: Text(_tr(lang, 'Keep swiping', 'ቀጥል')))],
      ),
    );
  }

  void _onPanEnd(DragEndDetails _) {
    if (_drag.dx.abs() > 110) {
      _fling(_drag.dx > 0);
    } else {
      _animateTo(Offset.zero);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_tr(lang, 'Discover', 'ያግኙ'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _cards.isEmpty
              ? _empty(context)
              : Column(children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Stack(alignment: Alignment.center, children: [
                        if (_cards.length > 1) _card(context, _cards[1], behind: true),
                        GestureDetector(
                          onPanUpdate: (d) => setState(() => _drag += d.delta),
                          onPanEnd: _onPanEnd,
                          child: Transform.translate(
                            offset: _drag,
                            child: Transform.rotate(angle: _drag.dx / 1400, child: _card(context, _cards.first)),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  _controls(context),
                  const SizedBox(height: 12),
                ]),
    );
  }

  Widget _empty(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.favorite_border_rounded, size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 14),
            Text(_status.isNotEmpty ? _status : _tr(lang, "You're all caught up. Check back soon.", 'ለአሁን ጨርሰዋል። በኋላ ይመለሱ።'),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: () { setState(() => _loading = true); _load(); }, child: Text(_tr(lang, 'Refresh', 'አድስ'))),
          ]),
        ),
      );

  Widget _card(BuildContext context, Map<String, dynamic> item, {bool behind = false}) {
    final colors = Theme.of(context).colorScheme;
    final photo = item['coverPhoto']?.toString() ?? '';
    final compat = (item['compatibility'] as Map?)?.cast<String, dynamic>() ?? const {};
    final age = item['age'];
    final title = '${item['fullName'] ?? ''}${age != null ? ', $age' : ''}';
    final swipe = behind ? 0.0 : _drag.dx;
    return Transform.scale(
      scale: behind ? 0.94 : 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: colors.surfaceContainerHighest,
          boxShadow: behind ? null : [BoxShadow(color: colors.shadow.withValues(alpha: .2), blurRadius: 24, offset: const Offset(0, 12))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(fit: StackFit.expand, children: [
          if (photo.isNotEmpty)
            Image.network(photo, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _photoFallback(colors))
          else
            _photoFallback(colors),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center, end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black87],
              ),
            ),
          ),
          Positioned(
            left: 18, right: 18, bottom: 18,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(
                  child: Text(title,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                ),
                if (item['verified'] == true) const Icon(Icons.verified_rounded, color: Colors.white, size: 22),
              ]),
              const SizedBox(height: 4),
              Text([item['churchName'], item['city']].where((e) => (e ?? '').toString().isNotEmpty).join(' • '),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 15)),
              if (compat['overall'] != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(999)),
                  child: Text('${compat['overall']}% ${_tr(lang, 'match', 'ተስማሚነት')}',
                      style: TextStyle(color: colors.onPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ],
            ]),
          ),
          if (!behind && swipe > 20) _stamp('LIKE', Colors.green, Alignment.topLeft, (swipe / 120).clamp(0, 1)),
          if (!behind && swipe < -20) _stamp('NOPE', Colors.red, Alignment.topRight, (-swipe / 120).clamp(0, 1)),
        ]),
      ),
    );
  }

  Widget _photoFallback(ColorScheme colors) =>
      Container(color: colors.surfaceContainerHighest, child: Icon(Icons.person_rounded, size: 120, color: colors.onSurfaceVariant));

  Widget _stamp(String text, Color color, Alignment alignment, double opacity) => Positioned(
        top: 24,
        left: alignment == Alignment.topLeft ? 24 : null,
        right: alignment == Alignment.topRight ? 24 : null,
        child: Opacity(
          opacity: opacity.toDouble(),
          child: Transform.rotate(
            angle: alignment == Alignment.topLeft ? -0.4 : 0.4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(border: Border.all(color: color, width: 4), borderRadius: BorderRadius.circular(10)),
              child: Text(text, style: TextStyle(color: color, fontSize: 30, fontWeight: FontWeight.w900)),
            ),
          ),
        ),
      );

  Widget _controls(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _fab(Icons.close_rounded, Colors.red, 64, () => _fling(false)),
      const SizedBox(width: 22),
      _fab(Icons.info_outline_rounded, Theme.of(context).colorScheme.primary, 52, () async {
        if (_cards.isEmpty) return;
        await showRelationshipProfileSheet(context,
            apiClient: widget.apiClient, token: widget.token, userId: '${_cards.first['userId']}', language: lang);
      }),
      const SizedBox(width: 22),
      _fab(Icons.favorite_rounded, Colors.green, 64, () => _fling(true)),
    ]);
  }

  Widget _fab(IconData icon, Color color, double size, VoidCallback onTap) => Material(
        color: Theme.of(context).colorScheme.surface,
        shape: const CircleBorder(),
        elevation: 3,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _cards.isEmpty ? null : onTap,
          child: SizedBox(width: size, height: size, child: Icon(icon, color: color, size: size * 0.5)),
        ),
      );
}
