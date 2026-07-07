import 'package:flutter/material.dart';

import '../../data/api_client.dart';
import '../../data/app_models.dart';
import '../../i18n/app_i18n.dart';

class OpportunitiesScreen extends StatefulWidget {
  const OpportunitiesScreen({super.key, required this.language, required this.apiClient, required this.session});

  final AppLanguage language;
  final ApiClient apiClient;
  final AuthResult? session;

  @override
  State<OpportunitiesScreen> createState() => _OpportunitiesScreenState();
}

class _OpportunitiesScreenState extends State<OpportunitiesScreen> {
  late Future<List<OpportunityItem>> _opportunitiesFuture;
  late Future<List<OpportunityApplicationItem>> _applicationsFuture;
  final TextEditingController _queryController = TextEditingController();
  String _typeFilter = 'all';
  String _status = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _opportunitiesFuture = widget.apiClient.fetchOpportunities();
      _applicationsFuture = widget.session?.token == null
          ? Future.value(const <OpportunityApplicationItem>[])
          : widget.apiClient.fetchMyOpportunityApplications(widget.session!.token);
    });
    await Future.wait([_opportunitiesFuture, _applicationsFuture]);
  }

  Future<void> _apply(OpportunityItem opportunity) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(() => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }

    final noteController = TextEditingController(text: AppStrings.of(widget.language, 'opportunity_note_default'));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(opportunity.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        content: TextField(
          controller: noteController,
          maxLines: 4,
          decoration: InputDecoration(labelText: AppStrings.of(widget.language, 'application_note')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(AppStrings.of(widget.language, 'cancel'))),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(AppStrings.of(widget.language, 'apply_now'))),
        ],
      ),
    );
    if (confirmed != true) {
      noteController.dispose();
      return;
    }

    final note = noteController.text;
    noteController.dispose();

    try {
      await widget.apiClient.applyForOpportunity(
        token: token,
        opportunityId: opportunity.id,
        note: note,
      );
      await _refresh();
      if (!mounted) return;
      setState(() => _status = AppStrings.of(widget.language, 'application_sent'));
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = error.toString().replaceFirst('HttpException: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    final t = AppStrings.of;
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([_opportunitiesFuture, _applicationsFuture]),
      builder: (context, snapshot) {
        final opportunities = snapshot.data != null ? snapshot.data![0] as List<OpportunityItem> : const <OpportunityItem>[];
        final applications = snapshot.data != null ? snapshot.data![1] as List<OpportunityApplicationItem> : const <OpportunityApplicationItem>[];
        final query = _queryController.text.trim().toLowerCase();
        final filtered = opportunities.where((item) {
          final matchesQuery = query.isEmpty ||
              item.title.toLowerCase().contains(query) ||
              item.organization.toLowerCase().contains(query) ||
              item.description.toLowerCase().contains(query);
          final matchesType = _typeFilter == 'all' || item.type == _typeFilter;
          return matchesQuery && matchesType;
        }).toList();
        final appliedIds = applications.map((item) => item.opportunityId).toSet();

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _HubHeader(
              title: t(language, 'opportunities'),
              subtitle: t(language, 'opportunities_subtitle'),
              accent: const Color(0xFF2E7D32),
            ),
            const SizedBox(height: 16),
            _SearchField(
              controller: _queryController,
              labelText: t(language, 'search'),
              hintText: t(language, 'opportunity_search_hint'),
              onChanged: (_) => setState(() {}),
              onClear: () {
                _queryController.clear();
                setState(() {});
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final filter in const ['all', 'scholarship', 'internship', 'volunteer', 'mission'])
                  ChoiceChip(
                    label: Text(_labelForType(language, filter)),
                    selected: _typeFilter == filter,
                    onSelected: (_) => setState(() => _typeFilter = filter),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: t(language, 'application_history'),
              children: [
                if (applications.isEmpty)
                  Text(t(language, 'no_opportunity_applications'))
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final application in applications)
                        Chip(
                          label: Text('${application.organization} • ${application.status}', maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (filtered.isEmpty)
              _EmptyCard(message: t(language, 'no_search_results'))
            else
              for (final opportunity in filtered) ...[
                _OpportunityCard(
                  opportunity: opportunity,
                  language: language,
                  applied: appliedIds.contains(opportunity.id),
                  onApply: widget.session == null ? null : () => _apply(opportunity),
                ),
                const SizedBox(height: 12),
              ],
            if (_status.isNotEmpty) ...[
              const SizedBox(height: 8),
              _StatusBanner(message: _status),
            ],
          ],
        );
      },
    );
  }

  String _labelForType(AppLanguage language, String value) {
    final t = AppStrings.of;
    return switch (value) {
      'all' => t(language, 'all'),
      'scholarship' => t(language, 'scholarship'),
      'internship' => t(language, 'internship'),
      'volunteer' => t(language, 'volunteer'),
      'mission' => t(language, 'mission_trip'),
      _ => value,
    };
  }
}

class MediaHubScreen extends StatefulWidget {
  const MediaHubScreen({super.key, required this.language, required this.apiClient});

  final AppLanguage language;
  final ApiClient apiClient;

  @override
  State<MediaHubScreen> createState() => _MediaHubScreenState();
}

class _MediaHubScreenState extends State<MediaHubScreen> {
  late Future<List<MediaItem>> _mediaFuture;
  final TextEditingController _queryController = TextEditingController();
  String _typeFilter = 'all';

  @override
  void initState() {
    super.initState();
    _mediaFuture = widget.apiClient.fetchMediaItems();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    final t = AppStrings.of;
    return FutureBuilder<List<MediaItem>>(
      future: _mediaFuture,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <MediaItem>[];
        final query = _queryController.text.trim().toLowerCase();
        final filtered = items.where((item) {
          final matchesQuery = query.isEmpty ||
              item.title.toLowerCase().contains(query) ||
              item.channel.toLowerCase().contains(query) ||
              item.description.toLowerCase().contains(query);
          final matchesType = _typeFilter == 'all' || item.type == _typeFilter;
          return matchesQuery && matchesType;
        }).toList();
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _HubHeader(
              title: t(language, 'media_hub'),
              subtitle: t(language, 'media_hub_subtitle'),
              accent: const Color(0xFF0D47A1),
            ),
            const SizedBox(height: 16),
            _SearchField(
              controller: _queryController,
              labelText: t(language, 'search'),
              hintText: t(language, 'media_search_hint'),
              onChanged: (_) => setState(() {}),
              onClear: () {
                _queryController.clear();
                setState(() {});
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final filter in const ['all', 'sermon', 'podcast', 'worship', 'livestream'])
                  ChoiceChip(
                    label: Text(_labelForType(language, filter)),
                    selected: _typeFilter == filter,
                    onSelected: (_) => setState(() => _typeFilter = filter),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (filtered.isEmpty)
              _EmptyCard(message: t(language, 'no_search_results'))
            else
              for (final media in filtered) ...[
                _MediaCard(media: media, language: language),
                const SizedBox(height: 12),
              ],
          ],
        );
      },
    );
  }

  String _labelForType(AppLanguage language, String value) {
    final t = AppStrings.of;
    return switch (value) {
      'all' => t(language, 'all'),
      'sermon' => t(language, 'sermon'),
      'podcast' => t(language, 'podcast'),
      'worship' => t(language, 'worship'),
      'livestream' => t(language, 'livestream'),
      _ => value,
    };
  }
}

class TalentHubScreen extends StatefulWidget {
  const TalentHubScreen({super.key, required this.language, required this.apiClient, required this.session});

  final AppLanguage language;
  final ApiClient apiClient;
  final AuthResult? session;

  @override
  State<TalentHubScreen> createState() => _TalentHubScreenState();
}

class _TalentHubScreenState extends State<TalentHubScreen> {
  late Future<List<TalentProfileItem>> _profilesFuture;
  late Future<List<TalentCompetitionItem>> _competitionsFuture;
  late Future<TalentProfileItem?> _myProfileFuture;
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController(text: 'Singing');
  final TextEditingController _churchController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  String _status = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _categoryController.dispose();
    _churchController.dispose();
    _cityController.dispose();
    _bioController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _profilesFuture = widget.apiClient.fetchTalentProfiles();
      _competitionsFuture = widget.apiClient.fetchTalentCompetitions();
      _myProfileFuture = widget.session?.token == null
          ? Future.value(null)
          : widget.apiClient.fetchTalentMe(widget.session!.token);
    });
    final profile = await _myProfileFuture;
    if (!mounted) return;
    if (profile != null) {
      _displayNameController.text = profile.displayName;
      _categoryController.text = profile.category;
      _churchController.text = profile.churchName;
      _cityController.text = profile.city;
      _bioController.text = profile.bio;
      _contactController.text = profile.contactInfo;
    }
  }

  Future<void> _saveProfile() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(() => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.apiClient.upsertTalentProfile(
        token: token,
        displayName: _displayNameController.text,
        category: _categoryController.text,
        churchName: _churchController.text,
        city: _cityController.text,
        bio: _bioController.text,
        contactInfo: _contactController.text,
      );
      await _refresh();
      if (!mounted) return;
      setState(() => _status = AppStrings.of(widget.language, 'talent_saved'));
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = error.toString().replaceFirst('HttpException: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enterCompetition(String competitionId) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(() => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.apiClient.enterTalentCompetition(token: token, competitionId: competitionId);
      await _refresh();
      if (!mounted) return;
      setState(() => _status = AppStrings.of(widget.language, 'competition_entered'));
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = error.toString().replaceFirst('HttpException: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    final t = AppStrings.of;
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([_profilesFuture, _competitionsFuture, _myProfileFuture]),
      builder: (context, snapshot) {
        final profiles = snapshot.data != null ? snapshot.data![0] as List<TalentProfileItem> : const <TalentProfileItem>[];
        final competitions = snapshot.data != null ? snapshot.data![1] as List<TalentCompetitionItem> : const <TalentCompetitionItem>[];
        final myProfile = snapshot.data != null ? snapshot.data![2] as TalentProfileItem? : null;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _HubHeader(
              title: t(language, 'talent_hub'),
              subtitle: t(language, 'talent_hub_subtitle'),
              accent: const Color(0xFF6A1B9A),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: t(language, 'my_talent_profile'),
              children: [
                TextField(controller: _displayNameController, decoration: InputDecoration(labelText: t(language, 'display_name'))),
                const SizedBox(height: 10),
                TextField(controller: _categoryController, decoration: InputDecoration(labelText: t(language, 'talent_category'))),
                const SizedBox(height: 10),
                TextField(controller: _churchController, decoration: InputDecoration(labelText: t(language, 'church_name'))),
                const SizedBox(height: 10),
                TextField(controller: _cityController, decoration: InputDecoration(labelText: t(language, 'city'))),
                const SizedBox(height: 10),
                TextField(controller: _contactController, decoration: InputDecoration(labelText: t(language, 'talent_contact'))),
                const SizedBox(height: 10),
                TextField(controller: _bioController, maxLines: 3, decoration: InputDecoration(labelText: t(language, 'bio'))),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _saveProfile,
                  icon: const Icon(Icons.verified_rounded),
                  label: Text(t(language, 'save_talent_profile')),
                ),
                if (myProfile != null) ...[
                  const SizedBox(height: 12),
                  Text('${t(language, 'current_profile')}: ${myProfile.displayName}', maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: t(language, 'talent_competitions'),
              children: [
                if (competitions.isEmpty)
                  Text(t(language, 'no_competitions'))
                else
                  for (final competition in competitions) ...[
                    _CompetitionCard(
                      competition: competition,
                      language: language,
                      onEnter: _busy ? null : () => _enterCompetition(competition.id),
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: t(language, 'talent_showcase'),
              children: [
                if (profiles.isEmpty)
                  Text(t(language, 'no_talent_profiles'))
                else
                  for (final profile in profiles)
                    _MiniProfileCard(profile: profile, language: language),
              ],
            ),
            if (_status.isNotEmpty) ...[
              const SizedBox(height: 16),
              _StatusBanner(message: _status),
            ],
          ],
        );
      },
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
        gradient: LinearGradient(colors: [accent.withValues(alpha: 0.94), accent.withValues(alpha: 0.68)]),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.92))),
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
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(message, maxLines: 3, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.labelText, required this.hintText, required this.onChanged, this.onClear});

  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: onClear == null
            ? null
            : IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.clear_rounded),
              ),
      ),
    );
  }
}

class _OpportunityCard extends StatelessWidget {
  const _OpportunityCard({required this.opportunity, required this.language, required this.applied, this.onApply});

  final OpportunityItem opportunity;
  final AppLanguage language;
  final bool applied;
  final VoidCallback? onApply;

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(opportunity.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text('${opportunity.organization} • ${opportunity.location}', maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Chip(label: Text(opportunity.type, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 10),
            Text(opportunity.description, maxLines: 4, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('${t(language, 'deadline')}: ${opportunity.deadline}')),
                Chip(label: Text(applied ? t(language, 'applied') : t(language, 'available'))),
                if (opportunity.contactUrl.isNotEmpty) Chip(label: Text(opportunity.contactUrl, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: applied || onApply == null ? null : onApply,
                child: Text(applied ? t(language, 'applied') : t(language, 'apply_now')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaCard extends StatelessWidget {
  const _MediaCard({required this.media, required this.language});

  final MediaItem media;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(_iconForType(media.type)),
        ),
        title: Text(media.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text('${media.channel} • ${media.type} • ${media.description}', maxLines: 3, overflow: TextOverflow.ellipsis),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (media.featured) Chip(label: Text(t(language, 'featured'))),
            const SizedBox(height: 4),
            Text(media.language.toUpperCase()),
          ],
        ),
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(media.title),
            content: Text('${media.description}\n\n${t(language, 'media_url')}: ${media.url}'),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(t(language, 'close')))],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    return switch (type) {
      'podcast' => Icons.podcasts_rounded,
      'worship' => Icons.music_note_rounded,
      'livestream' => Icons.live_tv_rounded,
      _ => Icons.play_circle_outline_rounded,
    };
  }
}

class _CompetitionCard extends StatelessWidget {
  const _CompetitionCard({required this.competition, required this.language, this.onEnter});

  final TalentCompetitionItem competition;
  final AppLanguage language;
  final VoidCallback? onEnter;

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(competition.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium)),
              Chip(label: Text(competition.category, maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 8),
          Text(competition.description, maxLines: 3, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Row(
            children: [
              Chip(label: Text('${t(language, 'deadline')}: ${competition.deadline}')),
              const Spacer(),
              FilledButton(onPressed: onEnter, child: Text(t(language, 'enter_competition'))),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniProfileCard extends StatelessWidget {
  const _MiniProfileCard({required this.profile, required this.language});

  final TalentProfileItem profile;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(profile.displayName.isNotEmpty ? profile.displayName[0].toUpperCase() : '?')),
        title: Text(profile.displayName, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text('${profile.category} • ${profile.churchName} • ${profile.city}', maxLines: 3, overflow: TextOverflow.ellipsis),
        trailing: Text(profile.contactInfo, maxLines: 2, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(message, maxLines: 3, overflow: TextOverflow.ellipsis),
    );
  }
}
