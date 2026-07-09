import 'package:flutter/material.dart';

import '../../data/api_client.dart';
import '../../i18n/app_i18n.dart';
import 'relationship_social.dart';

bool _en(AppLanguage l) => l == AppLanguage.english;
String _tr(AppLanguage l, String en, String am) => _en(l) ? en : am;

/// A grid of people who have liked you (super-likes first). Like back to match,
/// or pass to clear. Tapping a card opens the full profile.
class LikesYouScreen extends StatefulWidget {
  const LikesYouScreen({
    super.key,
    required this.apiClient,
    required this.token,
    required this.language,
  });

  final ApiClient apiClient;
  final String token;
  final AppLanguage language;

  @override
  State<LikesYouScreen> createState() => _LikesYouScreenState();
}

class _LikesYouScreenState extends State<LikesYouScreen> {
  List<Map<String, dynamic>> _likes = const [];
  bool _loading = true;
  String _status = '';
  final Set<String> _busy = {};

  AppLanguage get lang => widget.language;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await widget.apiClient.fetchRelationshipLikes(widget.token);
      if (mounted) setState(() { _likes = rows; _loading = false; _status = ''; });
    } catch (error) {
      if (mounted) setState(() { _status = friendlyRelationshipError(error, lang); _loading = false; });
    }
  }

  Future<void> _likeBack(Map<String, dynamic> like) async {
    final userId = '${like['otherId'] ?? ''}';
    final id = '${like['id'] ?? ''}';
    if (userId.isEmpty || _busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      final res = await widget.apiClient.expressRelationshipInterest(widget.token, userId,
          _tr(lang, 'I would value a respectful, prayerful introduction.', 'በአክብሮት እና በጸሎት መተዋወቅ እፈልጋለሁ።'));
      if (mounted) setState(() => _likes = _likes.where((l) => '${l['id']}' != id).toList());
      if (res is Map && res['matched'] == true && mounted) _showMatch(like);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error.toString().replaceFirst('HttpException: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _pass(Map<String, dynamic> like) async {
    final id = '${like['id'] ?? ''}';
    if (id.isEmpty || _busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      await widget.apiClient.rejectRelationshipInterest(widget.token, id);
      if (mounted) setState(() => _likes = _likes.where((l) => '${l['id']}' != id).toList());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error.toString().replaceFirst('HttpException: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  void _showMatch(Map<String, dynamic> like) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.favorite_rounded, color: Theme.of(context).colorScheme.primary, size: 44),
        title: Text(_tr(lang, "It's a match! 🎉", 'ተገጣጠማችሁ! 🎉')),
        content: Text(_tr(lang, 'You and ${like['otherName'] ?? ''} liked each other.',
            'እርስዎ እና ${like['otherName'] ?? ''} ተፋቅራችኋል።')),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: Text(_tr(lang, 'Nice', 'መልካም')))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final superCount = _likes.where((l) => l['super'] == true).length;
    return Scaffold(
      appBar: AppBar(title: Text(_tr(lang, 'Likes you', 'የወደዱዎት'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _likes.isEmpty
              ? _empty(context)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(slivers: [
                    if (superCount > 0)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                          child: Row(children: [
                            const Icon(Icons.star_rounded, color: Color(0xFF29B6F6), size: 20),
                            const SizedBox(width: 6),
                            Text(_tr(lang, '$superCount super-liked you', '$superCount ሱፐር ወደዱዎት'),
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ),
                    SliverPadding(
                      padding: const EdgeInsets.all(12),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2, childAspectRatio: 0.72, crossAxisSpacing: 12, mainAxisSpacing: 12),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => _card(context, _likes[i]),
                          childCount: _likes.length,
                        ),
                      ),
                    ),
                  ]),
                ),
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
                    : _tr(lang, 'No likes yet. Keep an active, prayerful profile — they will come.',
                        'ገና ወዳጅ የለም። መገለጫዎን ንቁ ያድርጉ — ይመጣሉ።'),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: () { setState(() => _loading = true); _load(); }, child: Text(_tr(lang, 'Refresh', 'አድስ'))),
          ]),
        ),
      );

  Widget _card(BuildContext context, Map<String, dynamic> like) {
    final colors = Theme.of(context).colorScheme;
    final photo = '${like['otherPhoto'] ?? ''}';
    final age = like['otherAge'];
    final name = '${like['otherName'] ?? ''}';
    final title = '$name${age != null ? ', $age' : ''}';
    final isSuper = like['super'] == true;
    final id = '${like['id'] ?? ''}';
    final busy = _busy.contains(id);
    return GestureDetector(
      onTap: () => showRelationshipProfileSheet(context,
          apiClient: widget.apiClient, token: widget.token, userId: '${like['otherId']}', language: lang),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: colors.surfaceContainerHighest,
          border: isSuper ? Border.all(color: const Color(0xFF29B6F6), width: 2) : null,
        ),
        child: Stack(fit: StackFit.expand, children: [
          if (photo.isNotEmpty)
            Image.network(photo, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallback(colors))
          else
            _fallback(colors),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center, end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black87],
              ),
            ),
          ),
          if (isSuper)
            const Positioned(
              top: 10, left: 10,
              child: CircleAvatar(radius: 14, backgroundColor: Color(0xFF29B6F6), child: Icon(Icons.star_rounded, color: Colors.white, size: 18)),
            ),
          Positioned(
            left: 10, right: 10, bottom: 8,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(
                  child: Text(title,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                ),
                if (like['otherVerified'] == true) const Icon(Icons.verified_rounded, color: Colors.white, size: 16),
              ]),
              if ('${like['otherCity'] ?? ''}'.isNotEmpty)
                Text('${like['otherCity']}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _actionButton(Icons.close_rounded, Colors.white, Colors.black45, busy ? null : () => _pass(like))),
                const SizedBox(width: 8),
                Expanded(child: _actionButton(Icons.favorite_rounded, Colors.white, Colors.green, busy ? null : () => _likeBack(like))),
              ]),
            ]),
          ),
          if (busy) const Positioned.fill(child: ColoredBox(color: Colors.black26, child: Center(child: CircularProgressIndicator()))),
        ]),
      ),
    );
  }

  Widget _actionButton(IconData icon, Color fg, Color bg, VoidCallback? onTap) => Material(
        color: bg,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Icon(icon, color: fg, size: 20)),
        ),
      );

  Widget _fallback(ColorScheme colors) =>
      Container(color: colors.surfaceContainerHighest, child: Icon(Icons.person_rounded, size: 64, color: colors.onSurfaceVariant));
}
