import 'package:flutter/material.dart';

import '../../data/api_client.dart';
import '../../data/app_models.dart';
import '../../i18n/app_i18n.dart';

class YouthHubScreen extends StatefulWidget {
  const YouthHubScreen({super.key, required this.language, required this.apiClient, required this.session});

  final AppLanguage language;
  final ApiClient apiClient;
  final AuthResult? session;

  @override
  State<YouthHubScreen> createState() => _YouthHubScreenState();
}

class _YouthHubScreenState extends State<YouthHubScreen> {
  late Future<List<ChurchItem>> _churchesFuture;
  late Future<List<ChurchAnnouncementItem>> _announcementsFuture;
  late Future<List<PrayerJournalItem>> _journalFuture;
  Future<List<BibleSearchResultItem>>? _searchFuture;
  final TextEditingController _announcementTitleController = TextEditingController();
  final TextEditingController _announcementBodyController = TextEditingController();
  final TextEditingController _journalTitleController = TextEditingController();
  final TextEditingController _journalBodyController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final Map<String, TextEditingController> _answerControllers = {};
  String _selectedChurchId = '';
  String _announcementPriority = 'normal';
  String _status = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _churchesFuture = widget.apiClient.fetchChurches();
    _announcementsFuture = widget.apiClient.fetchChurchAnnouncements();
    _journalFuture = _loadJournal();
    _searchFuture = null;
  }

  @override
  void dispose() {
    _announcementTitleController.dispose();
    _announcementBodyController.dispose();
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
    final churchesFuture = widget.apiClient.fetchChurches();
    final announcementsFuture = widget.apiClient.fetchChurchAnnouncements();
    final journalFuture = _loadJournal();
    setState(() {
      _churchesFuture = churchesFuture;
      _announcementsFuture = announcementsFuture;
      _journalFuture = journalFuture;
    });
    await Future.wait([churchesFuture, announcementsFuture, journalFuture]);
  }

  TextEditingController _answerControllerFor(String id) {
    return _answerControllers.putIfAbsent(id, () => TextEditingController());
  }

  Future<void> _createAnnouncement() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(() => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    if (_selectedChurchId.isEmpty || _announcementTitleController.text.trim().isEmpty || _announcementBodyController.text.trim().isEmpty) {
      setState(() => _status = AppStrings.of(widget.language, 'no_search_results'));
      return;
    }
    setState(() {
      _busy = true;
      _status = AppStrings.of(widget.language, 'working');
    });
    try {
      await widget.apiClient.createChurchAnnouncement(
        token: token,
        churchId: _selectedChurchId,
        title: _announcementTitleController.text.trim(),
        body: _announcementBodyController.text.trim(),
        priority: _announcementPriority,
      );
      _announcementTitleController.clear();
      _announcementBodyController.clear();
      await _refreshAll();
      if (!mounted) return;
      setState(() => _status = AppStrings.of(widget.language, 'success'));
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

  Future<void> _createJournalEntry() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(() => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    if (_journalTitleController.text.trim().isEmpty || _journalBodyController.text.trim().isEmpty) {
      setState(() => _status = AppStrings.of(widget.language, 'no_search_results'));
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
      setState(() => _status = AppStrings.of(widget.language, 'no_search_results'));
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
    setState(() {
      _searchFuture = widget.apiClient.searchBible(query,
          token: widget.session?.token,
          version: widget.language == AppLanguage.english ? 'kjv' : 'amh');
    });
    await _searchFuture;
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
              title: t(language, 'church_announcements'),
              children: [
                FutureBuilder<List<ChurchItem>>(
                  future: _churchesFuture,
                  builder: (context, snapshot) {
                    final churches = snapshot.data ?? const <ChurchItem>[];
                    if (churches.isNotEmpty && _selectedChurchId.isEmpty) {
                      _selectedChurchId = churches.first.id;
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _selectedChurchId.isEmpty && churches.isNotEmpty ? churches.first.id : _selectedChurchId.isEmpty ? null : _selectedChurchId,
                          decoration: InputDecoration(labelText: t(language, 'select_church')),
                          items: [
                            for (final church in churches)
                              DropdownMenuItem(value: church.id, child: Text('${church.name} • ${church.city}', maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: _busy ? null : (value) => setState(() => _selectedChurchId = value ?? ''),
                        ),
                        const SizedBox(height: 12),
                        TextField(controller: _announcementTitleController, decoration: InputDecoration(labelText: t(language, 'announcement_title'))),
                        const SizedBox(height: 12),
                        TextField(controller: _announcementBodyController, decoration: InputDecoration(labelText: t(language, 'announcement_body')), maxLines: 3),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final priority in const ['low', 'normal', 'high'])
                              ChoiceChip(
                                label: Text(priority == 'low' ? t(language, 'low') : priority == 'high' ? t(language, 'high') : t(language, 'normal')),
                                selected: _announcementPriority == priority,
                                onSelected: _busy ? null : (_) => setState(() => _announcementPriority = priority),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _busy ? null : _createAnnouncement, child: Text(t(language, 'create_announcement'))),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                FutureBuilder<List<ChurchAnnouncementItem>>(
                  future: _announcementsFuture,
                  builder: (context, snapshot) {
                    final items = snapshot.data ?? const <ChurchAnnouncementItem>[];
                    if (snapshot.connectionState == ConnectionState.waiting && items.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 24),
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
              title: t(language, 'prayer_journal'),
              children: [
                TextField(controller: _journalTitleController, decoration: InputDecoration(labelText: t(language, 'journal_title'))),
                const SizedBox(height: 12),
                TextField(controller: _journalBodyController, decoration: InputDecoration(labelText: t(language, 'journal_body')), maxLines: 3),
                const SizedBox(height: 12),
                FilledButton(onPressed: _busy ? null : _createJournalEntry, child: Text(t(language, 'add_note'))),
                const SizedBox(height: 16),
                FutureBuilder<List<PrayerJournalItem>>(
                  future: _journalFuture,
                  builder: (context, snapshot) {
                    final items = snapshot.data ?? const <PrayerJournalItem>[];
                    if (snapshot.connectionState == ConnectionState.waiting && items.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (items.isEmpty) {
                      return Text(t(language, 'no_prayer_journal'));
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
                TextField(controller: _searchController, decoration: InputDecoration(labelText: t(language, 'bible_search_hint')), onSubmitted: (_) => _searchBible()),
                const SizedBox(height: 12),
                FilledButton(onPressed: _searchBible, child: Text(t(language, 'search_bible'))),
                const SizedBox(height: 16),
                FutureBuilder<List<BibleSearchResultItem>>(
                  future: _searchFuture,
                  builder: (context, snapshot) {
                    final items = snapshot.data ?? const <BibleSearchResultItem>[];
                    if (_searchFuture == null) {
                      return Text(t(language, 'bible_search_hint'));
                    }
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
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
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
              Chip(label: Text(item.priority, maxLines: 1, overflow: TextOverflow.ellipsis), side: BorderSide(color: color.withValues(alpha: 0.3))),
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
          Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall),
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
    return ListTile(
      leading: Icon(icon),
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(item.subtitle, maxLines: 3, overflow: TextOverflow.ellipsis),
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
