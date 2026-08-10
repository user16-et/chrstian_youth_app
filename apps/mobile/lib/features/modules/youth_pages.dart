import 'package:flutter/material.dart';

import '../../data/api_client.dart';
import '../../data/app_models.dart';
import '../../data/bible_version_pref.dart';
import '../../data/date_format.dart';
import '../../i18n/app_i18n.dart';
import 'discover_pages.dart';
import 'module_pages.dart';

/// The youth home inside the Events pillar: upcoming gatherings, church
/// announcements, volunteer opportunities, a personal prayer journal and
/// quick Bible search — read-first, with the journal as the youth's own space.
class YouthHubScreen extends StatefulWidget {
  const YouthHubScreen({super.key, required this.language, required this.apiClient, required this.session});

  final AppLanguage language;
  final ApiClient apiClient;
  final AuthResult? session;

  @override
  State<YouthHubScreen> createState() => _YouthHubScreenState();
}

class _YouthHubScreenState extends State<YouthHubScreen> {
  late Future<List<EventItem>> _eventsFuture;
  late Future<List<ChurchAnnouncementItem>> _announcementsFuture;
  late Future<List<OpportunityItem>> _opportunitiesFuture;
  late Future<List<PrayerJournalItem>> _journalFuture;
  Future<List<BibleSearchResultItem>>? _searchFuture;
  final TextEditingController _journalTitleController = TextEditingController();
  final TextEditingController _journalBodyController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final Map<String, TextEditingController> _answerControllers = {};
  String _status = '';
  bool _busy = false;

  bool get _en => widget.language == AppLanguage.english;
  String _t(String en, String am) => _en ? en : am;

  @override
  void initState() {
    super.initState();
    _eventsFuture = widget.apiClient.fetchEvents(token: widget.session?.token);
    _announcementsFuture = widget.apiClient.fetchChurchAnnouncements();
    _opportunitiesFuture = widget.apiClient.fetchOpportunities();
    _journalFuture = _loadJournal();
    _searchFuture = null;
  }

  @override
  void dispose() {
    _journalTitleController.dispose();
    _journalBodyController.dispose();
    _searchController.dispose();
    for (final controller in _answerControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<List<PrayerJournalItem>> _loadJournal() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      return const <PrayerJournalItem>[];
    }
    return widget.apiClient.fetchPrayerJournal(token);
  }

  Future<void> _refreshAll() async {
    final eventsFuture = widget.apiClient.fetchEvents(token: widget.session?.token);
    final announcementsFuture = widget.apiClient.fetchChurchAnnouncements();
    final opportunitiesFuture = widget.apiClient.fetchOpportunities();
    final journalFuture = _loadJournal();
    setState(() {
      _eventsFuture = eventsFuture;
      _announcementsFuture = announcementsFuture;
      _opportunitiesFuture = opportunitiesFuture;
      _journalFuture = journalFuture;
    });
    await Future.wait([eventsFuture, announcementsFuture, opportunitiesFuture, journalFuture]);
  }

  TextEditingController _answerControllerFor(String id) {
    return _answerControllers.putIfAbsent(id, () => TextEditingController());
  }

  Future<void> _createJournalEntry() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(() => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    if (_journalTitleController.text.trim().isEmpty || _journalBodyController.text.trim().isEmpty) {
      setState(() => _status = _t('Add a title and what you are praying for.', 'ርዕስ እና የሚጸልዩትን ያክሉ።'));
      return;
    }
    setState(() {
      _busy = true;
      _status = AppStrings.of(widget.language, 'working');
    });
    try {
      await widget.apiClient.createPrayerJournalEntry(
        token: token,
        title: _journalTitleController.text.trim(),
        body: _journalBodyController.text.trim(),
      );
      _journalTitleController.clear();
      _journalBodyController.clear();
      await _refreshAll();
      if (!mounted) return;
      setState(() => _status = AppStrings.of(widget.language, 'prayer_journal_saved'));
    } catch (error) {
      if (mounted) {
        setState(() => _status = error.toString().replaceFirst('HttpException: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _answerJournal(PrayerJournalItem item) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(() => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    final answer = _answerControllerFor(item.id).text.trim();
    if (answer.isEmpty) {
      setState(() => _status = _t('Write how God answered first.', 'እግዚአብሔር እንዴት እንደመለሰ መጀመሪያ ይጻፉ።'));
      return;
    }
    setState(() {
      _busy = true;
      _status = AppStrings.of(widget.language, 'working');
    });
    try {
      await widget.apiClient.answerPrayerJournalEntry(token: token, entryId: item.id, answer: answer);
      _answerControllerFor(item.id).clear();
      await _refreshAll();
      if (!mounted) return;
      setState(() => _status = AppStrings.of(widget.language, 'answer_saved'));
    } catch (error) {
      if (mounted) {
        setState(() => _status = error.toString().replaceFirst('HttpException: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _searchBible() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchFuture = Future.value(const <BibleSearchResultItem>[]);
      });
      return;
    }
    // Follow the last-selected Bible translation, not the app UI language.
    final version = await BibleVersionPref.load() ?? 'amh';
    if (!mounted) return;
    setState(() {
      _searchFuture = widget.apiClient.searchBible(query,
          token: widget.session?.token, version: version);
    });
    await _searchFuture;
  }

  void _openEvent(EventItem event) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EventDetailScreen(
        language: widget.language,
        apiClient: widget.apiClient,
        event: event,
        session: widget.session,
      ),
    ));
  }

  void _openOpportunities() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => OpportunitiesScreen(
        language: widget.language,
        apiClient: widget.apiClient,
        session: widget.session,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    final t = AppStrings.of;
    return Scaffold(
      appBar: AppBar(title: Text(t(language, 'youth_hub'), maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            _HubHeader(
              title: t(language, 'youth_hub'),
              subtitle: t(language, 'youth_hub_subtitle'),
              accent: const Color(0xFF6A1B9A),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: _t('Upcoming gatherings', 'መጪ ስብሰባዎች'),
              children: [_upcomingEvents()],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: t(language, 'church_announcements'),
              children: [
                FutureBuilder<List<ChurchAnnouncementItem>>(
                  future: _announcementsFuture,
                  builder: (context, snapshot) {
                    final items = snapshot.data ?? const <ChurchAnnouncementItem>[];
                    if (snapshot.connectionState == ConnectionState.waiting && items.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (items.isEmpty) {
                      return Text(t(language, 'no_church_announcements'));
                    }
                    return Column(
                      children: [
                        for (final item in items.take(6))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _AnnouncementCard(item: item, language: language),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: _t('Serve and grow', 'አገልግል እና እደግ'),
              trailing: TextButton(
                onPressed: _openOpportunities,
                child: Text(_t('See all', 'ሁሉንም')),
              ),
              children: [_opportunitiesTeaser()],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: t(language, 'prayer_journal'),
              children: [
                TextField(controller: _journalTitleController, decoration: InputDecoration(labelText: t(language, 'journal_title'))),
                const SizedBox(height: 12),
                TextField(controller: _journalBodyController, decoration: InputDecoration(labelText: t(language, 'journal_body')), maxLines: 3),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(onPressed: _busy ? null : _createJournalEntry, child: Text(t(language, 'add_note'))),
                ),
                const SizedBox(height: 16),
                FutureBuilder<List<PrayerJournalItem>>(
                  future: _journalFuture,
                  builder: (context, snapshot) {
                    final items = snapshot.data ?? const <PrayerJournalItem>[];
                    if (snapshot.connectionState == ConnectionState.waiting && items.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (items.isEmpty) {
                      return Text(widget.session == null
                          ? AppStrings.of(language, 'login_required')
                          : t(language, 'no_prayer_journal'));
                    }
                    return Column(
                      children: [
                        for (final item in items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _JournalCard(
                              item: item,
                              language: language,
                              controller: _answerControllerFor(item.id),
                              onAnswer: _busy ? null : () => _answerJournal(item),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: t(language, 'bible_search'),
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: t(language, 'bible_search_hint'),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search_rounded),
                      onPressed: _searchBible,
                    ),
                  ),
                  onSubmitted: (_) => _searchBible(),
                ),
                const SizedBox(height: 16),
                FutureBuilder<List<BibleSearchResultItem>>(
                  future: _searchFuture,
                  builder: (context, snapshot) {
                    if (_searchFuture == null) {
                      return Text(_t('Search for a verse, note or plan.', 'ጥቅስ፣ ማስታወሻ ወይም እቅድ ይፈልጉ።'));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final items = snapshot.data ?? const <BibleSearchResultItem>[];
                    if (items.isEmpty) {
                      return Text(t(language, 'no_search_results'));
                    }
                    return Column(
                      children: [
                        for (final item in items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _SearchResultCard(item: item, language: language),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
            if (_status.isNotEmpty) ...[
              const SizedBox(height: 16),
              _StatusBanner(message: _status),
            ],
          ],
        ),
      ),
    );
  }

  Widget _upcomingEvents() {
    return FutureBuilder<List<EventItem>>(
      future: _eventsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final now = DateTime.now().subtract(const Duration(hours: 6));
        final upcoming = (snapshot.data ?? const <EventItem>[])
            .where((event) {
              final starts = DateTime.tryParse(event.startsAt);
              return starts != null && starts.isAfter(now);
            })
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
        if (upcoming.isEmpty) {
          return Text(_t('No upcoming events yet — check back soon!', 'እስካሁን መጪ ዝግጅት የለም — በቅርቡ ይመለሱ!'));
        }
        // The rail height must grow with the user's text scale, or the card
        // content overflows on devices with larger accessibility fonts.
        final textScale =
            (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 1.6);
        return SizedBox(
          height: 148 * textScale,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: upcoming.length.clamp(0, 8),
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) => _EventRailCard(
              event: upcoming[i],
              en: _en,
              onTap: () => _openEvent(upcoming[i]),
            ),
          ),
        );
      },
    );
  }

  Widget _opportunitiesTeaser() {
    return FutureBuilder<List<OpportunityItem>>(
      future: _opportunitiesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final items = snapshot.data ?? const <OpportunityItem>[];
        if (items.isEmpty) {
          return Text(_t('No open opportunities right now.', 'አሁን ክፍት እድል የለም።'));
        }
        return Column(
          children: [
            for (final item in items.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _OpportunityCard(item: item, en: _en, onTap: _openOpportunities),
              ),
          ],
        );
      },
    );
  }
}

class _EventRailCard extends StatelessWidget {
  const _EventRailCard({required this.event, required this.en, required this.onTap});

  final EventItem event;
  final bool en;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 236,
      child: Material(
        color: colors.surfaceContainerHighest.withValues(alpha: .4),
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    friendlyDateTime(event.startsAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: colors.onPrimaryContainer),
                  ),
                ),
                const SizedBox(height: 10),
                Text(event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const Spacer(),
                Row(children: [
                  Icon(Icons.place_rounded, size: 14, color: colors.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(event.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: colors.onSurfaceVariant)),
                  ),
                  Icon(Icons.arrow_forward_rounded, size: 16, color: colors.primary),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OpportunityCard extends StatelessWidget {
  const _OpportunityCard({required this.item, required this.en, required this.onTap});

  final OpportunityItem item;
  final bool en;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final deadline = item.deadline.isEmpty ? '' : friendlyDate(item.deadline);
    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: .4),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: colors.tertiaryContainer,
                  borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.volunteer_activism_rounded,
                  color: colors.onTertiaryContainer, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  [
                    item.organization,
                    if (deadline.isNotEmpty) (en ? 'by $deadline' : 'እስከ $deadline'),
                  ].where((s) => s.isNotEmpty).join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: colors.onSurfaceVariant),
                ),
              ]),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: colors.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }
}

class _HubHeader extends StatelessWidget {
  const _HubHeader({required this.title, required this.subtitle, required this.accent});

  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [accent, accent.withValues(alpha: 0.7)]),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(subtitle, maxLines: 4, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9))),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children, this.trailing});

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
              ),
              if (trailing != null) trailing!,
            ]),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.item, required this.language});

  final ChurchAnnouncementItem item;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final color = switch (item.priority) {
      'high' => const Color(0xFFD32F2F),
      'low' => const Color(0xFF2E7D32),
      _ => const Color(0xFF455A64),
    };
    final t = AppStrings.of;
    final priorityLabel = switch (item.priority) {
      'high' => t(language, 'high'),
      'low' => t(language, 'low'),
      _ => t(language, 'normal'),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall)),
              Chip(
                label: Text(priorityLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: BorderSide(color: color.withValues(alpha: 0.3)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('${item.churchName} • ${item.city}', maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Text(item.body, maxLines: 3, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _JournalCard extends StatelessWidget {
  const _JournalCard({required this.item, required this.language, required this.controller, required this.onAnswer});

  final PrayerJournalItem item;
  final AppLanguage language;
  final TextEditingController controller;
  final VoidCallback? onAnswer;

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: item.answered ? const Color(0xFF2E7D32).withValues(alpha: 0.08) : const Color(0xFF6A1B9A).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(item.answered ? Icons.check_circle_rounded : Icons.favorite_rounded,
                size: 17,
                color: item.answered ? const Color(0xFF2E7D32) : const Color(0xFF6A1B9A)),
            const SizedBox(width: 7),
            Expanded(
              child: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall),
            ),
          ]),
          const SizedBox(height: 6),
          Text(item.body, maxLines: 3, overflow: TextOverflow.ellipsis),
          if (item.answer != null && item.answer!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('${t(language, 'answered_prayer')}: ${item.answer}', maxLines: 4, overflow: TextOverflow.ellipsis),
          ] else ...[
            const SizedBox(height: 10),
            TextField(controller: controller, decoration: InputDecoration(labelText: t(language, 'prayer_answer')), maxLines: 2),
            const SizedBox(height: 10),
            FilledButton.tonal(onPressed: onAnswer, child: Text(t(language, 'answer_prayer'))),
          ],
        ],
      ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({required this.item, required this.language});

  final BibleSearchResultItem item;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final icon = switch (item.kind) {
      'plan' => Icons.event_note_rounded,
      'note' => Icons.note_alt_rounded,
      'bookmark' => Icons.bookmark_rounded,
      'highlight' => Icons.highlight_rounded,
      _ => Icons.auto_stories_rounded,
    };
    final en = language == AppLanguage.english;
    final reference = !en && item.bookAm != null && item.chapter != null
        ? '${item.bookAm} ${item.chapter}:${item.verse}'
        : item.reference;
    return ListTile(
      leading: Icon(icon),
      title: Text(reference, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(item.verseText, maxLines: 3, overflow: TextOverflow.ellipsis),
      tileColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(message, maxLines: 3, overflow: TextOverflow.ellipsis),
    );
  }
}
