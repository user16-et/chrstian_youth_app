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
  Map<String, dynamic> _filters = {};
  Offset _drag = Offset.zero;
  Offset _flyFrom = Offset.zero;
  Offset _flyTo = Offset.zero;
  VoidCallback? _onFlyDone;
  final List<({Map<String, dynamic> card, bool liked})> _history = [];

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

  int _compatOf(Map<String, dynamic> c) {
    final comp = (c['compatibility'] as Map?)?.cast<String, dynamic>();
    final v = comp?['overall'];
    return v is num ? v.toInt() : 0;
  }

  Future<void> _load() async {
    try {
      final cards = await widget.apiClient.discoverRelationships(widget.token, _filters);
      // Surface the most compatible people first — the "top picks" lead.
      final sorted = [...cards]..sort((a, b) => _compatOf(b).compareTo(_compatOf(a)));
      if (mounted) setState(() { _cards = sorted; _loading = false; });
    } catch (error) {
      if (mounted) setState(() { _status = friendlyRelationshipError(error, lang); _loading = false; });
    }
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DiscoveryFilterSheet(language: lang, initial: _filters),
    );
    if (result != null && mounted) {
      setState(() { _filters = result; _loading = true; _cards = const []; _history.clear(); _status = ''; });
      await _load();
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

  void _flingSuper() {
    if (_cards.isEmpty) return;
    final height = MediaQuery.sizeOf(context).height + 200;
    _animateTo(Offset(_drag.dx, -height), onDone: () => _commit(true, superLike: true));
  }

  void _commit(bool like, {bool superLike = false}) {
    if (_cards.isEmpty) return;
    final card = _cards.first;
    setState(() {
      _history.add((card: card, liked: like));
      _cards = _cards.sublist(1);
      _drag = Offset.zero;
    });
    if (like) {
      _like(card, superLike: superLike);
    } else {
      _pass(card);
    }
  }

  Future<void> _pass(Map<String, dynamic> card) async {
    final userId = card['userId']?.toString() ?? '';
    if (userId.isEmpty) return;
    try {
      await widget.apiClient.passRelationshipProfile(widget.token, userId);
    } catch (_) {
      // A failed pass shouldn't block swiping; they may simply reappear later.
    }
  }

  Future<void> _like(Map<String, dynamic> card, {bool superLike = false}) async {
    final userId = card['userId']?.toString() ?? '';
    if (userId.isEmpty) return;
    try {
      final res = await widget.apiClient.expressRelationshipInterest(
          widget.token,
          userId,
          superLike
              ? _tr(lang, 'You caught my eye — I would love a prayerful introduction.',
                  'ልቤን ማርከዋል — በጸሎት መተዋወቅ እወዳለሁ።')
              : _tr(lang, 'I would value a respectful, prayerful introduction.', 'በአክብሮት እና በጸሎት መተዋወቅ እፈልጋለሁ።'),
          superLike: superLike);
      if (res is Map && res['matched'] == true && mounted) _showMatch(card);
    } catch (_) {
      // A failed like shouldn't block swiping.
    }
  }

  Future<void> _rewind() async {
    if (_history.isEmpty || !_anim.isDismissed) return;
    final last = _history.removeLast();
    setState(() { _cards = [last.card, ..._cards]; _drag = Offset.zero; });
    final userId = last.card['userId']?.toString() ?? '';
    if (userId.isEmpty) return;
    try {
      // Undo the recorded action: retract a pending like, or clear a pass so
      // they return to discovery. A match already made stays.
      if (last.liked) {
        await widget.apiClient.withdrawRelationshipInterest(widget.token, userId);
      } else {
        await widget.apiClient.withdrawRelationshipPass(widget.token, userId);
      }
    } catch (_) {
      // Best effort — the card is already back on the deck.
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
    if (_drag.dy < -140 && _drag.dy.abs() > _drag.dx.abs()) {
      _flingSuper();
    } else if (_drag.dx.abs() > 110) {
      _fling(_drag.dx > 0);
    } else {
      _animateTo(Offset.zero);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tr(lang, 'Discover', 'ያግኙ')),
        actions: [
          IconButton(
            tooltip: _tr(lang, 'Filters', 'ማጣሪያዎች'),
            onPressed: _openFilters,
            icon: Badge(
              isLabelVisible: _filters.isNotEmpty,
              smallSize: 8,
              child: const Icon(Icons.tune_rounded),
            ),
          ),
        ],
      ),
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
            Text(
                _status.isNotEmpty
                    ? _status
                    : _filters.isNotEmpty
                        ? _tr(lang, 'No one matches these filters. Try widening them.', 'በእነዚህ ማጣሪያዎች የለም። ማጣሪያዎችን ያስፉ።')
                        : _tr(lang, "You're all caught up. Check back soon.", 'ለአሁን ጨርሰዋል። በኋላ ይመለሱ።'),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (_filters.isNotEmpty) ...[
                OutlinedButton(
                    onPressed: () { setState(() { _filters = {}; _loading = true; }); _load(); },
                    child: Text(_tr(lang, 'Clear filters', 'ማጣሪያ አጽዳ'))),
                const SizedBox(width: 10),
              ],
              OutlinedButton(onPressed: () { setState(() => _loading = true); _load(); }, child: Text(_tr(lang, 'Refresh', 'አድስ'))),
            ]),
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
          // Daily "top pick" ribbon for standout compatibility.
          if (!behind && (compat['overall'] is num) && (compat['overall'] as num) >= 90)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFFFC107), Color(0xFFFF7043)]),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: .25),
                        blurRadius: 8)
                  ],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.star_rounded, color: Colors.white, size: 15),
                  const SizedBox(width: 4),
                  Text(_tr(lang, 'Top pick', 'ምርጥ'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12)),
                ]),
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
          if (!behind && _drag.dy < -40 && _drag.dy.abs() > swipe.abs())
            _superStamp((-_drag.dy / 160).clamp(0, 1).toDouble())
          else if (!behind && swipe > 20)
            _stamp('LIKE', Colors.green, Alignment.topLeft, (swipe / 120).clamp(0, 1))
          else if (!behind && swipe < -20)
            _stamp('NOPE', Colors.red, Alignment.topRight, (-swipe / 120).clamp(0, 1)),
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

  Widget _superStamp(double opacity) => Center(
        child: Opacity(
          opacity: opacity,
          child: Transform.rotate(
            angle: -0.2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFF29B6F6), width: 4), borderRadius: BorderRadius.circular(12)),
              child: const Text('SUPER\nLIKE',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF29B6F6), fontSize: 30, fontWeight: FontWeight.w900, height: 1)),
            ),
          ),
        ),
      );

  Widget _controls(BuildContext context) {
    const superBlue = Color(0xFF29B6F6);
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _fab(Icons.replay_rounded, Colors.amber.shade700, 48, _history.isEmpty ? null : _rewind, requiresCards: false),
      const SizedBox(width: 14),
      _fab(Icons.close_rounded, Colors.red, 60, () => _fling(false)),
      const SizedBox(width: 14),
      _fab(Icons.star_rounded, superBlue, 52, _flingSuper),
      const SizedBox(width: 14),
      _fab(Icons.favorite_rounded, Colors.green, 60, () => _fling(true)),
      const SizedBox(width: 14),
      _fab(Icons.info_outline_rounded, Theme.of(context).colorScheme.primary, 48, () async {
        if (_cards.isEmpty) return;
        await showRelationshipProfileSheet(context,
            apiClient: widget.apiClient, token: widget.token, userId: '${_cards.first['userId']}', language: lang);
      }),
    ]);
  }

  Widget _fab(IconData icon, Color color, double size, VoidCallback? onTap, {bool requiresCards = true}) {
    final active = onTap != null && (!requiresCards || _cards.isNotEmpty);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: active ? onTap : null,
        child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: active ? color : Theme.of(context).colorScheme.outlineVariant, size: size * 0.5)),
      ),
    );
  }
}

/// Bottom sheet for filtering the discovery deck. Returns a filter map on Apply
/// (only set fields are included), or null on dismiss.
class _DiscoveryFilterSheet extends StatefulWidget {
  const _DiscoveryFilterSheet({required this.language, required this.initial});

  final AppLanguage language;
  final Map<String, dynamic> initial;

  @override
  State<_DiscoveryFilterSheet> createState() => _DiscoveryFilterSheetState();
}

class _DiscoveryFilterSheetState extends State<_DiscoveryFilterSheet> {
  static const double _minAgeBound = 18;
  static const double _maxAgeBound = 70;

  late RangeValues _age;
  late String _gender;
  late final TextEditingController _city;
  late final TextEditingController _denomination;

  AppLanguage get lang => widget.language;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    final lo = (i['minAge'] is num) ? (i['minAge'] as num).toDouble() : _minAgeBound;
    final hi = (i['maxAge'] is num) ? (i['maxAge'] as num).toDouble() : _maxAgeBound;
    _age = RangeValues(lo.clamp(_minAgeBound, _maxAgeBound), hi.clamp(_minAgeBound, _maxAgeBound));
    _gender = '${i['gender'] ?? ''}';
    _city = TextEditingController(text: '${i['city'] ?? ''}');
    _denomination = TextEditingController(text: '${i['denomination'] ?? ''}');
  }

  @override
  void dispose() {
    _city.dispose();
    _denomination.dispose();
    super.dispose();
  }

  Map<String, dynamic> _build() {
    final filters = <String, dynamic>{};
    if (_age.start > _minAgeBound) filters['minAge'] = _age.start.round();
    if (_age.end < _maxAgeBound) filters['maxAge'] = _age.end.round();
    if (_gender.isNotEmpty) filters['gender'] = _gender;
    if (_city.text.trim().isNotEmpty) filters['city'] = _city.text.trim();
    if (_denomination.text.trim().isNotEmpty) filters['denomination'] = _denomination.text.trim();
    return filters;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 4,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_tr(lang, 'Filter discovery', 'ማጣሪያ'), style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Row(children: [
          Text(_tr(lang, 'Age', 'ዕድሜ'), style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('${_age.start.round()} – ${_age.end.round()}${_age.end >= _maxAgeBound ? '+' : ''}'),
        ]),
        RangeSlider(
          values: _age,
          min: _minAgeBound,
          max: _maxAgeBound,
          divisions: (_maxAgeBound - _minAgeBound).round(),
          labels: RangeLabels('${_age.start.round()}', '${_age.end.round()}'),
          onChanged: (v) => setState(() => _age = RangeValues(
              v.start, v.end - v.start < 1 ? (v.start + 1).clamp(_minAgeBound, _maxAgeBound) : v.end)),
        ),
        const SizedBox(height: 8),
        Text(_tr(lang, 'Looking for', 'የምፈልገው'), style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          for (final option in [('', _tr(lang, 'Everyone', 'ሁሉም')), ('male', _tr(lang, 'Men', 'ወንዶች')), ('female', _tr(lang, 'Women', 'ሴቶች'))])
            ChoiceChip(
              label: Text(option.$2),
              selected: _gender == option.$1,
              onSelected: (_) => setState(() => _gender = option.$1),
            ),
        ]),
        const SizedBox(height: 16),
        TextField(
          controller: _city,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: _tr(lang, 'City', 'ከተማ'),
            prefixIcon: const Icon(Icons.place_outlined),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _denomination,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: _tr(lang, 'Denomination (optional)', 'ቤተ እምነት (አማራጭ)'),
            prefixIcon: const Icon(Icons.church_outlined),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        Row(children: [
          TextButton(
            onPressed: () => Navigator.pop(context, <String, dynamic>{}),
            child: Text(_tr(lang, 'Clear all', 'አጽዳ')),
          ),
          const Spacer(),
          FilledButton(
            onPressed: () => Navigator.pop(context, _build()),
            child: Text(_tr(lang, 'Apply', 'ተግብር')),
          ),
        ]),
      ]),
    );
  }
}
