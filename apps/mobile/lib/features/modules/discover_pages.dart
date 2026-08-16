import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/api_client.dart';
import '../../data/app_models.dart';
import '../../data/image_upload.dart';
import '../../i18n/app_i18n.dart';

/// Shared talent categories — a fixed set keeps the directory filterable and
/// consistent instead of free-typed strings.
const List<String> kTalentCategories = [
  'Singing',
  'Instruments',
  'Worship leading',
  'Preaching & teaching',
  'Poetry & spoken word',
  'Writing',
  'Photography',
  'Videography',
  'Graphic design',
  'Drama & acting',
  'Dance',
  'Media production',
  'Sound & tech',
  'Other',
];

IconData talentCategoryIcon(String category) {
  switch (category) {
    case 'Singing':
    case 'Worship leading':
      return Icons.mic_rounded;
    case 'Instruments':
      return Icons.piano_rounded;
    case 'Preaching & teaching':
      return Icons.record_voice_over_rounded;
    case 'Poetry & spoken word':
    case 'Writing':
      return Icons.menu_book_rounded;
    case 'Photography':
      return Icons.photo_camera_rounded;
    case 'Videography':
    case 'Media production':
      return Icons.videocam_rounded;
    case 'Graphic design':
      return Icons.brush_rounded;
    case 'Drama & acting':
      return Icons.theater_comedy_rounded;
    case 'Dance':
      return Icons.music_note_rounded;
    case 'Sound & tech':
      return Icons.graphic_eq_rounded;
    default:
      return Icons.star_rounded;
  }
}

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
  String _category = 'Singing';
  final TextEditingController _churchController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  TalentProfileItem? _myProfile;
  String _categoryFilter = 'all';
  String _status = '';
  bool _busy = false;

  bool get _en => widget.language == AppLanguage.english;
  String _t(String en, String am) => _en ? en : am;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _churchController.dispose();
    _cityController.dispose();
    _bioController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _profilesFuture =
          widget.apiClient.fetchTalentProfiles(token: widget.session?.token);
      _competitionsFuture = widget.apiClient.fetchTalentCompetitions();
      _myProfileFuture = widget.session?.token == null
          ? Future.value(null)
          : widget.apiClient.fetchTalentMe(widget.session!.token);
    });
    final profile = await _myProfileFuture;
    if (!mounted) return;
    setState(() {
      _myProfile = profile;
      if (profile != null) {
        _displayNameController.text = profile.displayName;
        _category = kTalentCategories.contains(profile.category)
            ? profile.category
            : 'Other';
        _churchController.text = profile.churchName;
        _cityController.text = profile.city;
        _bioController.text = profile.bio;
        _contactController.text = profile.contactInfo;
      }
    });
  }

  bool _requireLogin() {
    final token = widget.session?.token;
    if (token != null && token.isNotEmpty) return true;
    setState(() => _status = AppStrings.of(widget.language, 'login_required'));
    return false;
  }

  Future<void> _saveProfile() async {
    if (!_requireLogin()) return;
    if (_displayNameController.text.trim().isEmpty) {
      setState(() => _status = _t('Add a stage/display name first.', 'መጀመሪያ የመድረክ ስም ያክሉ።'));
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.apiClient.upsertTalentProfile(
        token: widget.session!.token,
        displayName: _displayNameController.text.trim(),
        category: _category,
        churchName: _churchController.text.trim(),
        city: _cityController.text.trim(),
        bio: _bioController.text.trim(),
        contactInfo: _contactController.text.trim(),
      );
      await _refresh();
      if (!mounted) return;
      setState(() => _status = _t('Talent profile saved.', 'የተሰጥኦ መገለጫ ተቀምጧል።'));
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = error.toString().replaceFirst('HttpException: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enterCompetition(String competitionId) async {
    if (!_requireLogin()) return;
    setState(() => _busy = true);
    try {
      await widget.apiClient
          .enterTalentCompetition(token: widget.session!.token, competitionId: competitionId);
      await _refresh();
      if (!mounted) return;
      setState(() => _status = _t('You are entered. Blessings!', 'ገብተዋል። መልካም!'));
    } catch (error) {
      if (!mounted) return;
      final raw = error.toString().replaceFirst('HttpException: ', '');
      setState(() => _status = raw.contains('talent_profile_required')
          ? _t('Create your talent profile before entering.',
              'ከመግባትዎ በፊት የተሰጥኦ መገለጫ ይፍጠሩ።')
          : raw);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---- Showcase (portfolio) ----

  Future<void> _addShowcase() async {
    if (!_requireLogin()) return;
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ShowcaseComposer(
          apiClient: widget.apiClient,
          token: widget.session!.token,
          language: widget.language),
    );
    if (result == null) return;
    setState(() => _busy = true);
    try {
      await widget.apiClient.addTalentShowcase(
        token: widget.session!.token,
        title: result['title'] ?? '',
        description: result['description'] ?? '',
        mediaUrl: result['mediaUrl'] ?? '',
        mediaType: result['mediaType'] ?? 'image',
        linkUrl: result['linkUrl'] ?? '',
      );
      await _refresh();
      if (!mounted) return;
      setState(() => _status = _t('Added to your showcase.', 'ወደ ማሳያዎ ታክሏል።'));
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = error.toString().replaceFirst('HttpException: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeShowcase(String id) async {
    if (!_requireLogin()) return;
    setState(() => _busy = true);
    try {
      await widget.apiClient.removeTalentShowcase(widget.session!.token, id);
      await _refresh();
    } catch (error) {
      if (mounted) {
        setState(() => _status = error.toString().replaceFirst('HttpException: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleEndorse(TalentProfileItem profile) async {
    if (!_requireLogin()) return;
    final endorse = !profile.endorsedByMe;
    var note = '';
    if (endorse) {
      // Offer an optional written testimonial with the endorsement.
      final controller = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(_t('Endorse ${profile.displayName}', '${profile.displayName}ን አጽድቅ')),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            maxLength: 500,
            decoration: InputDecoration(
                hintText: _t('Add a testimonial (optional) — how have they blessed you?',
                    'ምስክርነት ያክሉ (አማራጭ) — እንዴት ባርከዋል?')),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_t('Cancel', 'ተወው'))),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(_t('Endorse', 'አጽድቅ'))),
          ],
        ),
      );
      note = controller.text.trim();
      controller.dispose();
      if (ok != true) return;
    }
    try {
      await widget.apiClient.endorseTalent(widget.session!.token, profile.userId,
          endorse: endorse, note: note);
      await _refresh();
    } catch (error) {
      if (mounted) {
        setState(() => _status = error.toString().replaceFirst('HttpException: ', ''));
      }
    }
  }

  void _openTalent(TalentProfileItem profile) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TalentDetailSheet(
        profile: profile,
        language: widget.language,
        isMe: profile.userId == widget.session?.user.id,
        apiClient: widget.apiClient,
        token: widget.session?.token,
        onEndorse: () async {
          Navigator.pop(context);
          await _toggleEndorse(profile);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future:
          Future.wait([_profilesFuture, _competitionsFuture, _myProfileFuture]),
      builder: (context, snapshot) {
        final profiles = snapshot.data != null
            ? snapshot.data![0] as List<TalentProfileItem>
            : const <TalentProfileItem>[];
        final competitions = snapshot.data != null
            ? snapshot.data![1] as List<TalentCompetitionItem>
            : const <TalentCompetitionItem>[];
        final filtered = _categoryFilter == 'all'
            ? profiles
            : profiles.where((p) => p.category == _categoryFilter).toList();
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _HubHeader(
                title: _t('Talent Hub', 'የተሰጥኦ ማዕከል'),
                subtitle: _t(
                    'Show the gift God gave you, discover other believers, and enter competitions.',
                    'እግዚአብሔር የሰጠዎትን ስጦታ ያሳዩ፣ ሌሎች አማኞችን ያግኙ እና በውድድር ይሳተፉ።'),
                accent: const Color(0xFF6A1B9A),
              ),
              const SizedBox(height: 16),
              _buildMyProfileCard(),
              const SizedBox(height: 16),
              _buildMyShowcaseCard(),
              const SizedBox(height: 16),
              if (competitions.isNotEmpty) ...[
                _SectionCard(
                  title: _t('Competitions', 'ውድድሮች'),
                  children: [
                    for (final c in competitions) ...[
                      _CompetitionCard(
                        competition: c,
                        language: widget.language,
                        onEnter: _busy ? null : () => _enterCompetition(c.id),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
              ],
              _buildDirectory(profiles, filtered),
              if (_status.isNotEmpty) ...[
                const SizedBox(height: 16),
                _StatusBanner(message: _status),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMyProfileCard() {
    return _SectionCard(
      title: _t('My talent profile', 'የእኔ የተሰጥኦ መገለጫ'),
      children: [
        TextField(
            controller: _displayNameController,
            decoration: InputDecoration(
                labelText: _t('Stage / display name', 'የመድረክ ስም'),
                prefixIcon: const Icon(Icons.badge_rounded))),
        const SizedBox(height: 12),
        _fieldLabel(_t('Category', 'ምድብ')),
        DropdownButtonFormField<String>(
          initialValue: _category,
          isExpanded: true,
          items: [
            for (final c in kTalentCategories)
              DropdownMenuItem(
                  value: c,
                  child: Row(children: [
                    Icon(talentCategoryIcon(c), size: 18),
                    const SizedBox(width: 8),
                    Flexible(child: Text(c, overflow: TextOverflow.ellipsis)),
                  ])),
          ],
          onChanged: _busy ? null : (v) => setState(() => _category = v ?? _category),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: TextField(
                  controller: _churchController,
                  decoration:
                      InputDecoration(labelText: _t('Church', 'ቤተ ክርስቲያን')))),
          const SizedBox(width: 10),
          Expanded(
              child: TextField(
                  controller: _cityController,
                  decoration: InputDecoration(labelText: _t('City', 'ከተማ')))),
        ]),
        const SizedBox(height: 12),
        TextField(
            controller: _contactController,
            decoration: InputDecoration(
                labelText: _t('Contact (phone/email)', 'ስልክ/ኢሜይል'),
                prefixIcon: const Icon(Icons.contact_page_rounded))),
        const SizedBox(height: 12),
        TextField(
            controller: _bioController,
            maxLines: 3,
            decoration: InputDecoration(
                labelText: _t('About your gift', 'ስለ ስጦታዎ'))),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _busy ? null : _saveProfile,
          icon: const Icon(Icons.save_rounded),
          label: Text(_myProfile == null
              ? _t('Create profile', 'መገለጫ ፍጠር')
              : _t('Save changes', 'ለውጦችን አስቀምጥ')),
        ),
      ],
    );
  }

  Widget _buildMyShowcaseCard() {
    final items = _myProfile?.showcase ?? const <TalentShowcaseItem>[];
    return _SectionCard(
      title: _t('My showcase', 'የእኔ ማሳያ'),
      children: [
        Text(
            _t('Add songs, videos, photos or links that show your gift.',
                'ስጦታዎን የሚያሳዩ ዘፈኖች፣ ቪዲዮዎች፣ ፎቶዎች ወይም አገናኞች ያክሉ።'),
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(_t('Nothing here yet.', 'እስካሁን ምንም የለም።'),
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          )
        else
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: [
              for (final item in items)
                _ShowcaseThumb(
                  item: item,
                  onTap: () => _openMedia(item),
                  onRemove: _busy ? null : () => _removeShowcase(item.id),
                ),
            ],
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _busy ? null : _addShowcase,
          icon: const Icon(Icons.add_photo_alternate_rounded),
          label: Text(_t('Add to showcase', 'ወደ ማሳያ ጨምር')),
        ),
      ],
    );
  }

  Widget _buildDirectory(
      List<TalentProfileItem> all, List<TalentProfileItem> filtered) {
    final categories = <String>{for (final p in all) p.category}.toList()
      ..sort();
    return _SectionCard(
      title: _t('Talent directory', 'የተሰጥኦ ማውጫ'),
      children: [
        if (categories.isNotEmpty)
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_t('All', 'ሁሉም')),
                    selected: _categoryFilter == 'all',
                    onSelected: (_) => setState(() => _categoryFilter = 'all'),
                  ),
                ),
                for (final c in categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: Icon(talentCategoryIcon(c), size: 16),
                      label: Text(c),
                      selected: _categoryFilter == c,
                      onSelected: (_) => setState(() => _categoryFilter = c),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          Text(_t('No talents here yet — be the first!', 'እስካሁን ተሰጥኦ የለም — መጀመሪያ ይሁኑ!'))
        else
          for (final profile in filtered) ...[
            _TalentCard(
              profile: profile,
              language: widget.language,
              onTap: () => _openTalent(profile),
              onEndorse:
                  _busy ? null : () => _toggleEndorse(profile),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  Future<void> _openMedia(TalentShowcaseItem item) async {
    final url = item.linkUrl.isNotEmpty ? item.linkUrl : item.mediaUrl;
    if (url.isEmpty) return;
    if (item.mediaType == 'image' && item.linkUrl.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          child: InteractiveViewer(
            child: Image.network(url,
                errorBuilder: (_, __, ___) => const Padding(
                    padding: EdgeInsets.all(40),
                    child: Icon(Icons.broken_image_rounded, size: 48))),
          ),
        ),
      );
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _fieldLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
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

// A rich directory card: avatar, name, category, a showcase strip preview, and
// an endorse button with a live count.
class _TalentCard extends StatelessWidget {
  const _TalentCard({
    required this.profile,
    required this.language,
    required this.onTap,
    required this.onEndorse,
  });

  final TalentProfileItem profile;
  final AppLanguage language;
  final VoidCallback onTap;
  final VoidCallback? onEndorse;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final images = profile.showcase
        .where((s) => s.mediaType == 'image' && s.mediaUrl.isNotEmpty)
        .toList();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(
                backgroundColor: colors.primaryContainer,
                foregroundColor: colors.onPrimaryContainer,
                child: Icon(talentCategoryIcon(profile.category), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          profile.displayName.isNotEmpty
                              ? profile.displayName
                              : profile.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(
                          [profile.category, profile.churchName, profile.city]
                              .where((s) => s.isNotEmpty)
                              .join(' • '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: colors.onSurfaceVariant)),
                    ]),
              ),
              _EndorseButton(
                  count: profile.endorsementCount,
                  endorsed: profile.endorsedByMe,
                  onPressed: onEndorse),
            ]),
            if (images.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(images[i].mediaUrl,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                            width: 72,
                            height: 72,
                            color: colors.surfaceContainerHighest,
                            child: const Icon(Icons.image_rounded))),
                  ),
                ),
              ),
            ] else if (profile.showcase.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('${profile.showcase.length} ${language == AppLanguage.english ? 'showcase items' : 'ማሳያዎች'}',
                  style: TextStyle(fontSize: 12, color: colors.primary)),
            ],
          ]),
        ),
      ),
    );
  }
}

class _EndorseButton extends StatelessWidget {
  const _EndorseButton(
      {required this.count, required this.endorsed, required this.onPressed});
  final int count;
  final bool endorsed;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(
              endorsed
                  ? Icons.thumb_up_alt_rounded
                  : Icons.thumb_up_off_alt_rounded,
              size: 20,
              color: endorsed ? colors.primary : colors.onSurfaceVariant),
          const SizedBox(height: 2),
          Text('$count',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: endorsed ? colors.primary : colors.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

class _ShowcaseThumb extends StatelessWidget {
  const _ShowcaseThumb(
      {required this.item, required this.onTap, required this.onRemove});
  final TalentShowcaseItem item;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isImage = item.mediaType == 'image' && item.mediaUrl.isNotEmpty;
    return Stack(children: [
      Positioned.fill(
        child: InkWell(
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: isImage
                ? Image.network(item.mediaUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(colors))
                : _placeholder(colors),
          ),
        ),
      ),
      if (onRemove != null)
        Positioned(
          top: 2,
          right: 2,
          child: InkWell(
            onTap: onRemove,
            child: const CircleAvatar(
                radius: 11,
                backgroundColor: Colors.black54,
                child: Icon(Icons.close_rounded, size: 14, color: Colors.white)),
          ),
        ),
    ]);
  }

  Widget _placeholder(ColorScheme colors) => Container(
        color: colors.surfaceContainerHighest,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(
              item.mediaType == 'video'
                  ? Icons.play_circle_rounded
                  : item.mediaType == 'audio'
                      ? Icons.audiotrack_rounded
                      : Icons.link_rounded,
              color: colors.primary),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 9)),
          ),
        ]),
      );
}

/// Composer for a showcase item: upload an image, or paste a video/audio/link
/// URL. Returns {title, description, mediaUrl, mediaType, linkUrl}.
class _ShowcaseComposer extends StatefulWidget {
  const _ShowcaseComposer(
      {required this.apiClient, required this.token, required this.language});
  final ApiClient apiClient;
  final String token;
  final AppLanguage language;

  @override
  State<_ShowcaseComposer> createState() => _ShowcaseComposerState();
}

class _ShowcaseComposerState extends State<_ShowcaseComposer> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _link = TextEditingController();
  String _type = 'image';
  String _imageUrl = '';

  bool get _en => widget.language == AppLanguage.english;
  String _t(String en, String am) => _en ? en : am;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _link.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 4, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(_t('Add to showcase', 'ወደ ማሳያ ጨምር'),
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          // A Wrap of chips instead of a 4-segment SegmentedButton, which would
          // overflow horizontally on narrow screens (especially in Amharic).
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final opt in const [
                ('image', 'Photo', 'ፎቶ', Icons.image_rounded),
                ('video', 'Video', 'ቪዲዮ', Icons.videocam_rounded),
                ('audio', 'Audio', 'ድምጽ', Icons.audiotrack_rounded),
                ('link', 'Link', 'አገናኝ', Icons.link_rounded),
              ])
                ChoiceChip(
                  avatar: Icon(opt.$4, size: 16),
                  label: Text(_t(opt.$2, opt.$3)),
                  selected: _type == opt.$1,
                  onSelected: (_) => setState(() => _type = opt.$1),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_type == 'image') ...[
            if (_imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(_imageUrl,
                    height: 160, width: double.infinity, fit: BoxFit.cover),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final url = await pickAndUploadImage(context,
                    apiClient: widget.apiClient,
                    token: widget.token,
                    usage: 'post_media');
                if (url != null && mounted) setState(() => _imageUrl = url);
              },
              icon: const Icon(Icons.add_photo_alternate_rounded),
              label: Text(_imageUrl.isEmpty
                  ? _t('Upload photo', 'ፎቶ ስቀል')
                  : _t('Change photo', 'ፎቶ ቀይር')),
            ),
          ] else
            TextField(
              controller: _link,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: _type == 'video'
                    ? _t('Video URL (YouTube…)', 'የቪዲዮ አገናኝ')
                    : _type == 'audio'
                        ? _t('Audio URL', 'የድምጽ አገናኝ')
                        : _t('Link URL', 'አገናኝ'),
                prefixIcon: const Icon(Icons.link_rounded),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
              controller: _title,
              decoration: InputDecoration(labelText: _t('Title', 'ርዕስ'))),
          const SizedBox(height: 10),
          TextField(
              controller: _description,
              maxLines: 2,
              decoration: InputDecoration(
                  labelText: _t('Description (optional)', 'መግለጫ (አማራጭ)'))),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              final title = _title.text.trim();
              final hasMedia =
                  _type == 'image' ? _imageUrl.isNotEmpty : _link.text.trim().isNotEmpty;
              if (title.isEmpty || !hasMedia) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(_t('Add a title and media/link.',
                        'ርዕስ እና ሚዲያ/አገናኝ ያክሉ።'))));
                return;
              }
              Navigator.pop(context, {
                'title': title,
                'description': _description.text.trim(),
                'mediaType': _type,
                'mediaUrl': _type == 'image' ? _imageUrl : '',
                'linkUrl': _type == 'image' ? '' : _link.text.trim(),
              });
            },
            child: Text(_t('Add', 'ጨምር')),
          ),
        ]),
      ),
    );
  }
}

/// Full talent view: bio, media gallery, contact and an endorse action.
class _TalentDetailSheet extends StatelessWidget {
  const _TalentDetailSheet({
    required this.profile,
    required this.language,
    required this.isMe,
    required this.onEndorse,
    required this.apiClient,
    this.token,
  });

  final TalentProfileItem profile;
  final AppLanguage language;
  final bool isMe;
  final VoidCallback onEndorse;
  final ApiClient apiClient;
  final String? token;

  bool get _en => language == AppLanguage.english;
  String _t(String en, String am) => _en ? en : am;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .8,
      maxChildSize: .95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Row(children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
              child: Icon(talentCategoryIcon(profile.category), size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                    profile.displayName.isNotEmpty
                        ? profile.displayName
                        : profile.fullName,
                    style: Theme.of(context).textTheme.titleLarge),
                Text(profile.category,
                    style: TextStyle(color: colors.onSurfaceVariant)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (profile.churchName.isNotEmpty)
              Chip(avatar: const Icon(Icons.church_rounded, size: 16), label: Text(profile.churchName)),
            if (profile.city.isNotEmpty)
              Chip(avatar: const Icon(Icons.place_rounded, size: 16), label: Text(profile.city)),
            Chip(
                avatar: const Icon(Icons.thumb_up_alt_rounded, size: 16),
                label: Text('${profile.endorsementCount} ${_t('endorsements', 'ድጋፎች')}')),
          ]),
          if (profile.bio.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(profile.bio),
          ],
          if (profile.showcase.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(_t('Showcase', 'ማሳያ'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            for (final item in profile.showcase) _showcaseTile(context, item),
          ],
          const SizedBox(height: 18),
          _TalentTestimonials(
            apiClient: apiClient,
            token: token,
            userId: profile.userId,
            language: language,
          ),
          if (profile.contactInfo.isNotEmpty) ...[
            const SizedBox(height: 18),
            Card(
              child: ListTile(
                leading: const Icon(Icons.contact_page_rounded),
                title: Text(_t('Contact', 'አግኝ')),
                subtitle: Text(profile.contactInfo),
              ),
            ),
          ],
          if (!isMe) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onEndorse,
              icon: Icon(profile.endorsedByMe
                  ? Icons.thumb_up_alt_rounded
                  : Icons.thumb_up_off_alt_rounded),
              label: Text(profile.endorsedByMe
                  ? _t('Endorsed', 'ተደግፏል')
                  : _t('Endorse this talent', 'ይህን ተሰጥኦ ደግፍ')),
            ),
          ],
        ],
      ),
    );
  }

  Widget _showcaseTile(BuildContext context, TalentShowcaseItem item) {
    final isImage = item.mediaType == 'image' && item.mediaUrl.isNotEmpty;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          final url = item.linkUrl.isNotEmpty ? item.linkUrl : item.mediaUrl;
          final uri = Uri.tryParse(url);
          if (uri != null && item.linkUrl.isNotEmpty) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (isImage)
            Image.network(item.mediaUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(
                    height: 180, child: Icon(Icons.broken_image_rounded))),
          ListTile(
            leading: Icon(item.mediaType == 'video'
                ? Icons.play_circle_rounded
                : item.mediaType == 'audio'
                    ? Icons.audiotrack_rounded
                    : item.mediaType == 'link'
                        ? Icons.link_rounded
                        : Icons.image_rounded),
            title: Text(item.title),
            subtitle: item.description.isNotEmpty ? Text(item.description) : null,
            trailing: item.linkUrl.isNotEmpty
                ? const Icon(Icons.open_in_new_rounded)
                : null,
          ),
        ]),
      ),
    );
  }
}

/// Loads and shows a talent's written endorsements (testimonials).
class _TalentTestimonials extends StatefulWidget {
  const _TalentTestimonials({
    required this.apiClient,
    required this.token,
    required this.userId,
    required this.language,
  });

  final ApiClient apiClient;
  final String? token;
  final String userId;
  final AppLanguage language;

  @override
  State<_TalentTestimonials> createState() => _TalentTestimonialsState();
}

class _TalentTestimonialsState extends State<_TalentTestimonials> {
  List<TalentEndorsementItem> _items = const [];
  bool _loading = true;

  bool get _en => widget.language == AppLanguage.english;
  String _t(String en, String am) => _en ? en : am;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await widget.apiClient
          .fetchTalentEndorsements(widget.userId, token: widget.token);
      if (mounted) setState(() { _items = r; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    // Only show entries that carry a written testimonial.
    final withNotes = _items.where((e) => e.note.trim().isNotEmpty).toList();
    if (withNotes.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_t('Testimonials', 'ምስክርነቶች'),
          style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 10),
      for (final e in withNotes)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('“${e.note}”', style: const TextStyle(fontStyle: FontStyle.italic)),
            const SizedBox(height: 6),
            Text('— ${e.endorserName}',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: colors.onSurfaceVariant)),
          ]),
        ),
    ]);
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
