part of '../module_pages.dart';

class CourtshipScreen extends StatefulWidget {
  const CourtshipScreen(
      {super.key,
      required this.language,
      required this.apiClient,
      required this.session,
      required this.onDataChanged});

  final AppLanguage language;
  final ApiClient apiClient;
  final AuthResult? session;
  final Future<void> Function() onDataChanged;

  @override
  State<CourtshipScreen> createState() => _CourtshipScreenState();
}

class _CourtshipScreenState extends State<CourtshipScreen> {
  late Future<List<CourtshipProfileItem>> _profilesFuture;
  late Future<CourtshipProfileItem?> _meFuture;
  late Future<List<CourtshipInterestItem>> _interestsFuture;
  late Future<Map<String, dynamic>> _relationshipFuture;

  final TextEditingController _churchNameController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _interestsController = TextEditingController();
  final TextEditingController _faithStatementController =
      TextEditingController();
  final TextEditingController _ministryInvolvementController =
      TextEditingController();
  final TextEditingController _lifeGoalsController = TextEditingController();
  final TextEditingController _marriageVisionController =
      TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  bool _visible = true;
  String _relationshipIntent = 'serious';
  bool _busy = false;
  String _status = '';
  int _tab = 0; // 0 Discover, 1 Likes, 2 Matches, 3 Profile
  CourtshipProfileItem? _me;
  bool _meLoaded = false;
  bool _locationTried = false;

  @override
  void initState() {
    super.initState();
    _profilesFuture = widget.apiClient.fetchCourtshipProfiles();
    _refreshAccount();
  }

  @override
  void didUpdateWidget(covariant CourtshipScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session?.token != widget.session?.token) {
      _refreshAccount();
    }
  }

  @override
  void dispose() {
    _churchNameController.dispose();
    _cityController.dispose();
    _bioController.dispose();
    _interestsController.dispose();
    _faithStatementController.dispose();
    _ministryInvolvementController.dispose();
    _lifeGoalsController.dispose();
    _marriageVisionController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _refreshAccount() async {
    final token = widget.session?.token;
    final profilesFuture = widget.apiClient.fetchCourtshipProfiles();
    final meFuture = token == null
        ? Future.value(null)
        : widget.apiClient.fetchCourtshipMe(token);
    final interestsFuture = token == null
        ? Future.value(const <CourtshipInterestItem>[])
        : widget.apiClient.fetchCourtshipInterests(token);
    final relationshipFuture = token == null
        ? Future.value(const <String, dynamic>{})
        : widget.apiClient.fetchRelationshipHome(token);
    setState(() {
      _profilesFuture = profilesFuture;
      _meFuture = meFuture;
      _interestsFuture = interestsFuture;
      _relationshipFuture = relationshipFuture;
    });
    await profilesFuture;
    final me = await meFuture;
    await interestsFuture;
    await relationshipFuture;
    if (mounted) {
      setState(() {
        _me = me;
        _meLoaded = true;
      });
    }
    // Once the user has a profile, capture their location (best-effort) so the
    // deck can show distance. Only attempt once per screen lifetime.
    final tk = widget.session?.token;
    if (me != null && !_locationTried && tk != null && tk.isNotEmpty) {
      _locationTried = true;
      captureAndSendCourtshipLocation(apiClient: widget.apiClient, token: tk);
    }
  }

  Future<void> _saveProfile() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    await _runAction(() async {
      await widget.apiClient.saveRelationshipProfile(token, {
        'churchName': _churchNameController.text,
        'city': _cityController.text,
        'bio': _bioController.text,
        'interests': _interestsController.text,
        'faithStatement': _faithStatementController.text,
        'ministryInvolvement': _ministryInvolvementController.text,
        'lifeGoals': _lifeGoalsController.text,
        'marriageVision': _marriageVisionController.text,
        'relationshipGoal': _relationshipIntent,
        'activationMode': _relationshipIntent == 'friendship'
            ? 'friendship_only'
            : _relationshipIntent == 'prayerful'
                ? 'fellowship_friendship'
                : 'marriage_oriented',
        'visible': _visible,
        'visibility': _visible ? 'relationship_mode_only' : 'hidden',
        'marriageTimeline': 'In prayerful timing',
        'devotionalHabits': 'Bible, prayer and church fellowship',
      });
      await _refreshAccount();
      await widget.onDataChanged();
      setState(() => _status = AppStrings.of(widget.language, 'success'));
    });
  }

  Future<void> _sendInterest(CourtshipProfileItem profile) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    await _runAction(() async {
      await widget.apiClient.expressRelationshipInterest(
          token, profile.userId, _noteController.text);
      _noteController.clear();
      await _refreshAccount();
      await widget.onDataChanged();
      setState(() => _status = AppStrings.of(widget.language, 'interest_sent'));
    });
  }

  Future<void> _updateInterest(
      CourtshipInterestItem item, String status) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    await _runAction(() async {
      if (status == 'accepted') {
        await widget.apiClient.acceptRelationshipInterest(token, item.id);
      } else {
        await widget.apiClient.rejectRelationshipInterest(token, item.id);
      }
      await _refreshAccount();
      await widget.onDataChanged();
      setState(
          () => _status = AppStrings.of(widget.language, 'interest_updated'));
    });
  }

  Future<void> _openProfileDetail(CourtshipProfileItem profile) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CourtshipProfileDetailScreen(
          language: widget.language,
          profile: profile,
          noteController: _noteController,
          onSendInterest: () => _sendInterest(profile),
        ),
      ),
    );
  }

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      setState(
          () => _status = error.toString().replaceFirst('HttpException: ', ''));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    final en = language == AppLanguage.english;
    final token = widget.session?.token;
    final loggedIn = token != null && token.isNotEmpty;
    final colors = Theme.of(context).colorScheme;

    Widget tabBody() {
      if (_tab == 3) return _profileTab(context);
      if (!loggedIn) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.favorite_rounded, size: 48, color: colors.primary),
              const SizedBox(height: 12),
              Text(
                  en
                      ? 'Sign in to discover and connect.'
                      : 'ለማግኘትና ለመገናኘት ይግቡ።',
                  textAlign: TextAlign.center),
            ]),
          ),
        );
      }
      // Gate: you must create a profile before browsing others (and to appear
      // to them). Shown once we've confirmed there is no profile.
      if (_meLoaded && _me == null) {
        return _createProfileGate(en, colors);
      }
      switch (_tab) {
        case 0:
          // Swipe deck — key on token so it rebuilds on account change.
          return CourtshipSwipeScreen(
              key: const ValueKey('courtship-discover'),
              apiClient: widget.apiClient,
              token: token,
              language: language);
        case 1:
          return LikesYouScreen(
              apiClient: widget.apiClient, token: token, language: language);
        case 2:
          return MatchesInboxScreen(
              apiClient: widget.apiClient, token: token, language: language);
        default:
          return _profileTab(context);
      }
    }

    return Scaffold(
      body: SafeArea(bottom: false, child: tabBody()),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          if (i == 3) _refreshAccount();
        },
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.explore_outlined),
              selectedIcon: const Icon(Icons.explore_rounded),
              label: en ? 'Discover' : 'ያግኙ'),
          NavigationDestination(
              icon: const Icon(Icons.favorite_border_rounded),
              selectedIcon: const Icon(Icons.favorite_rounded),
              label: en ? 'Likes' : 'ወዳጆች'),
          NavigationDestination(
              icon: const Icon(Icons.forum_outlined),
              selectedIcon: const Icon(Icons.forum_rounded),
              label: en ? 'Matches' : 'ተዛማጆች'),
          NavigationDestination(
              icon: const Icon(Icons.person_outline_rounded),
              selectedIcon: const Icon(Icons.person_rounded),
              label: en ? 'Profile' : 'መገለጫ'),
        ],
      ),
    );
  }

  // Shown on Discover/Likes/Matches until the user creates a profile.
  Widget _createProfileGate(bool en, ColorScheme colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient:
                  LinearGradient(colors: [colors.primary, colors.secondary]),
            ),
            child: const Icon(Icons.favorite_rounded,
                color: Colors.white, size: 40),
          ),
          const SizedBox(height: 20),
          Text(
              en
                  ? 'Create your profile to start'
                  : 'ለመጀመር መገለጫዎን ይፍጠሩ',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
              en
                  ? 'Add a few photos and tell your story. You need a profile to discover others and to appear to them — this keeps the community genuine and safe.'
                  : 'ጥቂት ፎቶዎችን ያክሉ እና ታሪክዎን ይንገሩ። ሌሎችን ለማግኘትና ለእነሱ ለመታየት መገለጫ ያስፈልግዎታል — ይህ ማህበረሰቡን እውነተኛና ደህንነቱ የተጠበቀ ያደርገዋል።',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: colors.onSurface.withValues(alpha: .7))),
          const SizedBox(height: 22),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
            onPressed: () => setState(() => _tab = 3),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: Text(en ? 'Set up my profile' : 'መገለጫዬን ላዘጋጅ'),
          ),
        ]),
      ),
    );
  }

  Widget _profileTab(BuildContext context) {
    final language = widget.language;
    return FutureBuilder<List<CourtshipProfileItem>>(
      future: _profilesFuture,
      builder: (context, profilesSnapshot) {
        return FutureBuilder<CourtshipProfileItem?>(
          future: _meFuture,
          builder: (context, meSnapshot) {
            final me = meSnapshot.data;
            if (me != null && _churchNameController.text.isEmpty) {
              _churchNameController.text = me.churchName;
              _cityController.text = me.city;
              _bioController.text = me.bio;
              _interestsController.text = me.interests;
              _faithStatementController.text = me.faithStatement;
              _ministryInvolvementController.text = me.ministryInvolvement;
              _lifeGoalsController.text = me.lifeGoals;
              _marriageVisionController.text = me.marriageVision;
              _relationshipIntent = me.relationshipIntent;
              _visible = me.visible;
            }
            return FutureBuilder<List<CourtshipInterestItem>>(
              future: _interestsFuture,
              builder: (context, interestsSnapshot) {
                final profiles =
                    profilesSnapshot.data ?? const <CourtshipProfileItem>[];
                final interests =
                    interestsSnapshot.data ?? const <CourtshipInterestItem>[];
                final received = me == null
                    ? const <CourtshipInterestItem>[]
                    : interests
                        .where((item) => item.receiverId == me.userId)
                        .toList();
                final sent = me == null
                    ? const <CourtshipInterestItem>[]
                    : interests
                        .where((item) => item.senderId == me.userId)
                        .toList();
                return RefreshIndicator(
                  onRefresh: _refreshAccount,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: [
                      _SectionHeader(
                        title: language == AppLanguage.english
                            ? 'Relationship & Courtship'
                            : 'ግንኙነት እና መተዋወቅ',
                        subtitle: language == AppLanguage.english
                            ? 'Christian friendship, intentional courtship, marriage preparation and accountability.'
                            : 'ክርስቲያናዊ ወዳጅነት፣ በዓላማ የተመሠረተ መተዋወቅ፣ የጋብቻ ዝግጅት እና ተጠያቂነት።',
                      ),
                      const SizedBox(height: 16),
                      FutureBuilder<Map<String, dynamic>>(
                        future: _relationshipFuture,
                        builder: (context, relationshipSnapshot) =>
                            _RelationshipEcosystemPanel(
                          data: relationshipSnapshot.data ??
                              const <String, dynamic>{},
                          language: language,
                          token: widget.session?.token,
                          apiClient: widget.apiClient,
                          onChanged: _refreshAccount,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: language == AppLanguage.english
                            ? 'Relationship activation and profile'
                            : 'የግንኙነት ማንቃት እና መገለጫ',
                        children: [
                          Text(
                              AppStrings.of(language, 'courtship_profile_body'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 12),
                          TextField(
                              controller: _churchNameController,
                              decoration: InputDecoration(
                                  labelText:
                                      AppStrings.of(language, 'church_name'))),
                          const SizedBox(height: 12),
                          TextField(
                              controller: _cityController,
                              decoration: InputDecoration(
                                  labelText: AppStrings.of(language, 'city'))),
                          const SizedBox(height: 12),
                          TextField(
                              controller: _bioController,
                              decoration: InputDecoration(
                                  labelText: AppStrings.of(language, 'bio')),
                              maxLines: 3),
                          const SizedBox(height: 12),
                          TextField(
                              controller: _interestsController,
                              decoration: InputDecoration(
                                  labelText: AppStrings.of(
                                      language, 'interests_label')),
                              maxLines: 2),
                          const SizedBox(height: 12),
                          TextField(
                              controller: _faithStatementController,
                              decoration: const InputDecoration(
                                  labelText: 'Faith statement'),
                              maxLines: 3),
                          const SizedBox(height: 12),
                          TextField(
                              controller: _ministryInvolvementController,
                              decoration: const InputDecoration(
                                  labelText: 'Ministry involvement'),
                              maxLines: 2),
                          const SizedBox(height: 12),
                          TextField(
                              controller: _lifeGoalsController,
                              decoration: const InputDecoration(
                                  labelText: 'Life goals'),
                              maxLines: 3),
                          const SizedBox(height: 12),
                          TextField(
                              controller: _marriageVisionController,
                              decoration: const InputDecoration(
                                  labelText: 'Marriage and family vision'),
                              maxLines: 3),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _relationshipIntent,
                            decoration: InputDecoration(
                                labelText: AppStrings.of(
                                    language, 'relationship_intent')),
                            items: [
                              DropdownMenuItem(
                                  value: 'serious',
                                  child:
                                      Text(AppStrings.of(language, 'serious'))),
                              DropdownMenuItem(
                                  value: 'friendship',
                                  child: Text(
                                      AppStrings.of(language, 'friendship'))),
                              DropdownMenuItem(
                                  value: 'prayerful',
                                  child: Text(
                                      AppStrings.of(language, 'prayerful'))),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _relationshipIntent = value);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            value: _visible,
                            title: Text(
                                AppStrings.of(language, 'visible_profile')),
                            onChanged: (value) =>
                                setState(() => _visible = value),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _busy ? null : _saveProfile,
                            child:
                                Text(AppStrings.of(language, 'save_profile')),
                          ),
                          if (me != null) ...[
                            const SizedBox(height: 8),
                            Text(
                                '${AppStrings.of(language, 'verified')}: ${me.verified ? AppStrings.of(language, 'ready') : AppStrings.of(language, 'pending')}'),
                          ],
                          if (_status.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(_status,
                                maxLines: 3, overflow: TextOverflow.ellipsis),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: AppStrings.of(language, 'courtship_directory'),
                        children: profilesSnapshot.connectionState ==
                                    ConnectionState.waiting &&
                                profiles.isEmpty
                            ? const [
                                Padding(
                                  padding: EdgeInsets.only(top: 24),
                                  child: Center(
                                      child: CircularProgressIndicator()),
                                ),
                              ]
                            : profiles.isEmpty
                                ? [
                                    Text(AppStrings.of(
                                        language, 'no_courtship_profiles'))
                                  ]
                                : [
                                    for (final profile in profiles)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 10),
                                        child: _ListTileRow(
                                          icon: profile.verified
                                              ? Icons.verified_rounded
                                              : Icons.favorite_border_rounded,
                                          title: profile.fullName,
                                          subtitle:
                                              '${profile.churchName} • ${profile.city} • ${AppStrings.of(language, profile.relationshipIntent)}',
                                          onTap: () =>
                                              _openProfileDetail(profile),
                                        ),
                                      ),
                                  ],
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: AppStrings.of(language, 'courtship_requests'),
                        children: interestsSnapshot.connectionState ==
                                    ConnectionState.waiting &&
                                interests.isEmpty
                            ? const [
                                Padding(
                                  padding: EdgeInsets.only(top: 24),
                                  child: Center(
                                      child: CircularProgressIndicator()),
                                ),
                              ]
                            : interests.isEmpty
                                ? [
                                    Text(AppStrings.of(
                                        language, 'no_courtship_interests'))
                                  ]
                                : [
                                    if (received.isNotEmpty) ...[
                                      Text(
                                          AppStrings.of(
                                              language, 'received_interests'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 8),
                                      for (final item in received)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 10),
                                          child: _CourtshipInterestCard(
                                            item: item,
                                            language: language,
                                            isReceiver:
                                                me?.userId == item.receiverId,
                                            onAccept: _busy
                                                ? null
                                                : () => _updateInterest(
                                                    item, 'accepted'),
                                            onDecline: _busy
                                                ? null
                                                : () => _updateInterest(
                                                    item, 'declined'),
                                          ),
                                        ),
                                    ],
                                    if (sent.isNotEmpty) ...[
                                      Text(
                                          AppStrings.of(
                                              language, 'sent_interests'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 8),
                                      for (final item in sent)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 10),
                                          child: _CourtshipInterestCard(
                                            item: item,
                                            language: language,
                                            isReceiver: false,
                                          ),
                                        ),
                                    ],
                                  ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class CourtshipProfileDetailScreen extends StatelessWidget {
  const CourtshipProfileDetailScreen(
      {super.key,
      required this.language,
      required this.profile,
      required this.noteController,
      required this.onSendInterest});

  final AppLanguage language;
  final CourtshipProfileItem profile;
  final TextEditingController noteController;
  final Future<void> Function() onSendInterest;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.of(language, 'courtship_profile'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SectionHeader(
              title: profile.fullName,
              subtitle: '${profile.churchName} • ${profile.city}'),
          const SizedBox(height: 16),
          _SectionCard(
            title: AppStrings.of(language, 'courtship_profile'),
            children: [
              Text(profile.bio, maxLines: 4, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              Text(
                  '${AppStrings.of(language, 'interests_label')}: ${profile.interests}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Text(
                  '${AppStrings.of(language, 'relationship_intent')}: ${AppStrings.of(language, profile.relationshipIntent)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Text(
                  '${AppStrings.of(language, 'verified')}: ${profile.verified ? AppStrings.of(language, 'ready') : AppStrings.of(language, 'pending')}'),
              const SizedBox(height: 12),
              TextField(
                  controller: noteController,
                  decoration: InputDecoration(
                      labelText: AppStrings.of(language, 'courtship_note')),
                  maxLines: 3),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  await onSendInterest();
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: Text(AppStrings.of(language, 'send_interest')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RelationshipEcosystemPanel extends StatefulWidget {
  const _RelationshipEcosystemPanel(
      {required this.data,
      required this.language,
      required this.token,
      required this.apiClient,
      required this.onChanged});
  final Map<String, dynamic> data;
  final AppLanguage language;
  final String? token;
  final ApiClient apiClient;
  final Future<void> Function() onChanged;

  @override
  State<_RelationshipEcosystemPanel> createState() =>
      _RelationshipEcosystemPanelState();
}

class _RelationshipEcosystemPanelState
    extends State<_RelationshipEcosystemPanel> {
  bool _busy = false;
  String _status = '';
  List<Map<String, dynamic>> _storyFeed = const [];
  bool get en => widget.language == AppLanguage.english;
  List<Map<String, dynamic>> _items(String key) =>
      (widget.data[key] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();
  Map<String, dynamic> get _analytics =>
      (widget.data['analytics'] as Map<String, dynamic>?) ?? const {};
  Map<String, dynamic> get _me =>
      (widget.data['me'] as Map<String, dynamic>?) ?? const {};
  List<Map<String, dynamic>> get _myPhotos =>
      (_me['photos'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();

  Future<void> _addCourtshipPhoto() async {
    final token = widget.token;
    if (token == null || token.isEmpty) {
      setState(() => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    final url = await pickAndUploadImage(context,
        apiClient: widget.apiClient, token: token, usage: 'profile_photo');
    if (url == null) return;
    await _run((t) => widget.apiClient.addRelationshipPhoto(t, url),
        en ? 'Photo added.' : 'ፎቶ ተጨምሯል።');
  }

  void _deleteCourtshipPhoto(String photoId) => _run(
      (t) => widget.apiClient.deleteRelationshipPhoto(t, photoId),
      en ? 'Photo removed.' : 'ፎቶ ተወግዷል።');

  @override
  void initState() {
    super.initState();
    _loadStoryFeed();
  }

  Future<void> _loadStoryFeed() async {
    final token = widget.token;
    if (token == null || token.isEmpty) return;
    try {
      final feed = await widget.apiClient.fetchRelationshipStoryFeed(token);
      if (mounted) setState(() => _storyFeed = feed);
    } catch (_) {
      // Story ring is non-critical; ignore load failures.
    }
  }

  Future<void> _postStory() async {
    final token = widget.token;
    if (token == null || token.isEmpty) {
      setState(() => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    final input = await showAddMediaDialog(context,
        language: widget.language,
        apiClient: widget.apiClient,
        token: token,
        title: en ? 'Post a story' : 'ታሪክ ይለጥፉ');
    if (input == null) return;
    await _run(
        (t) => widget.apiClient.createRelationshipStory(t,
            mediaUrl: input['url'] ?? '', caption: input['caption'] ?? ''),
        en ? 'Story posted.' : 'ታሪክ ተለጥፏል።');
    await _loadStoryFeed();
  }

  void _openStory(String userId, String fullName) {
    final token = widget.token;
    if (token == null || token.isEmpty) return;
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) => StoryViewerScreen(
                apiClient: widget.apiClient,
                token: token,
                userId: userId,
                fullName: fullName,
                language: widget.language)))
        .then((_) => _loadStoryFeed());
  }

  Future<void> _openProfile(String userId) async {
    final token = widget.token;
    if (token == null || token.isEmpty) {
      setState(() => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    final expressed = await showRelationshipProfileSheet(context,
        apiClient: widget.apiClient, token: token, userId: userId, language: widget.language);
    if (expressed) {
      await widget.onChanged();
      if (mounted) setState(() => _status = en ? 'Interest sent.' : 'ፍላጎት ተልኳል።');
    }
  }

  Map<String, dynamic> get _interests =>
      (widget.data['interests'] as Map<String, dynamic>?) ?? const {};
  List<Map<String, dynamic>> _interestList(String key) =>
      (_interests[key] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();

  void _acceptInterest(String id) => _run(
      (t) => widget.apiClient.acceptRelationshipInterest(t, id),
      en ? "It's a match! 🎉" : 'ተገጣጠማችሁ! 🎉');
  void _declineInterest(String id) =>
      _run((t) => widget.apiClient.rejectRelationshipInterest(t, id), en ? 'Passed.' : 'ተላልፏል።');

  Widget _interestTile({
    required String? photo,
    required String name,
    required String subtitle,
    required VoidCallback onTap,
    required Widget trailing,
  }) {
    final hasPhoto = photo != null && photo.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Row(children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: hasPhoto ? NetworkImage(photo) : null,
            child: hasPhoto ? null : const Icon(Icons.person_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall),
              if (subtitle.isNotEmpty)
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
          trailing,
        ]),
      ),
    );
  }

  Future<void> _run(
      Future<dynamic> Function(String token) action, String success) async {
    final token = widget.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    setState(() {
      _busy = true;
      _status = AppStrings.of(widget.language, 'working');
    });
    try {
      await action(token);
      await widget.onChanged();
      if (mounted) setState(() => _status = success);
    } catch (error) {
      if (mounted) {
        setState(() =>
            _status = error.toString().replaceFirst('HttpException: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connections = _items('connections');
    final discovery = _items('discovery');
    final resources = _items('resources');
    final events = _items('events');
    final mentors = _items('mentors');
    final firstConnection = connections.isEmpty ? null : connections.first;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _SectionCard(
          title: en ? 'Stories' : 'ታሪኮች',
          children: [
            Text(
                en
                    ? 'Share a moment that disappears after 24 hours — separate from your profile photos.'
                    : 'ከ24 ሰዓት በኋላ የሚጠፋ ቅጽበት ያጋሩ — ከመገለጫ ፎቶዎችዎ የተለየ ነው።',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),
            RelationshipStoryRing(
              stories: _storyFeed,
              language: widget.language,
              myCoverPhoto: _me['coverPhoto']?.toString(),
              onAddStory: _postStory,
              onOpenStory: _openStory,
            ),
          ]),
      const SizedBox(height: 12),
      _SectionCard(
          title: en ? 'Relationship dashboard' : 'የግንኙነት ዳሽቦርድ',
          children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              _InfoChip(label: '${_analytics['profileViews'] ?? 0} views'),
              _InfoChip(
                  label: '${_analytics['receivedInterests'] ?? 0} received'),
              _InfoChip(label: '${_analytics['sentInterests'] ?? 0} sent'),
              _InfoChip(
                  label: '${_analytics['acceptedInterests'] ?? 0} accepted'),
              _InfoChip(label: '${_analytics['connections'] ?? 0} connections'),
            ]),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: (widget.token == null || widget.token!.isEmpty)
                    ? null
                    : () => showStoryViewersSheet(context,
                        apiClient: widget.apiClient,
                        token: widget.token!,
                        language: widget.language),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: Text(en ? 'Who viewed your story' : 'ታሪክዎን የተመለከቱ'),
              ),
            ),
            if (_status.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(_status, maxLines: 2, overflow: TextOverflow.ellipsis)
            ],
          ]),
      const SizedBox(height: 12),
      if (_me.isNotEmpty)
        _SectionCard(
          title: en ? 'Profile photos' : 'የመገለጫ ፎቶዎች',
          children: [
            Text(
                en
                    ? 'Up to 9 permanent photos shown on your profile (not stories). Tap ✕ to remove.'
                    : 'በመገለጫዎ ላይ የሚታዩ እስከ 9 ቋሚ ፎቶዎች (ታሪክ አይደሉም)። ለማስወገድ ✕ ይንኩ።',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            SizedBox(
              height: 104,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final photo in _myPhotos)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Stack(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network('${photo['url']}',
                            width: 92, height: 104, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                                width: 92, height: 104,
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                child: const Icon(Icons.broken_image_outlined))),
                      ),
                      Positioned(
                        top: 3, right: 3,
                        child: InkWell(
                          onTap: _busy ? null : () => _deleteCourtshipPhoto('${photo['id']}'),
                          child: const CircleAvatar(
                              radius: 12, backgroundColor: Colors.black54,
                              child: Icon(Icons.close_rounded, size: 15, color: Colors.white)),
                        ),
                      ),
                    ]),
                  ),
                if (_myPhotos.length < 9)
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _busy ? null : _addCourtshipPhoto,
                    child: Container(
                      width: 92, height: 104,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.add_a_photo_rounded, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 4),
                        Text(en ? 'Add' : 'ጨምር',
                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
              ]),
            ),
          ],
        ),
      if (_me.isNotEmpty) const SizedBox(height: 12),
      if ('${widget.data['userGender'] ?? ''}'.isEmpty)
        Builder(builder: (context) {
          final colors = Theme.of(context).colorScheme;
          return Card(
            color: colors.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(en ? 'Complete your profile for matching' : 'ለማዛመድ መገለጫዎን ያሟሉ',
                    style: TextStyle(fontWeight: FontWeight.w800, color: colors.onSecondaryContainer)),
                const SizedBox(height: 4),
                Text(
                    en
                        ? 'Tell us your sex so you appear to the right people. This is set once.'
                        : 'ለትክክለኛ ሰዎች እንዲታዩ ጾታዎን ይንገሩን። አንዴ ብቻ ይቀመጣል።',
                    style: TextStyle(color: colors.onSecondaryContainer)),
                const SizedBox(height: 12),
                Row(children: [
                  for (final g in [('male', en ? 'Male' : 'ወንድ'), ('female', en ? 'Female' : 'ሴት')])
                    Padding(
                      padding: EdgeInsets.only(right: g.$1 == 'male' ? 8 : 0),
                      child: FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _run((t) => widget.apiClient.setRelationshipGender(t, g.$1),
                                en ? 'Saved.' : 'ተቀምጧል።'),
                        child: Text(g.$2),
                      ),
                    ),
                ]),
              ]),
            ),
          );
        }),
      if (_interestList('received').isNotEmpty)
        Builder(builder: (context) {
          final received = _interestList('received');
          final superCount = received.where((r) => r['super'] == true).length;
          final colors = Theme.of(context).colorScheme;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: (widget.token == null || widget.token!.isEmpty)
                    ? null
                    : () async {
                        await Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => LikesYouScreen(
                                apiClient: widget.apiClient,
                                token: widget.token!,
                                language: widget.language)));
                        await widget.onChanged();
                      },
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Icon(Icons.favorite_rounded, color: colors.onPrimaryContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                            en
                                ? '${received.length} ${received.length == 1 ? 'person likes' : 'people like'} you'
                                : '${received.length} ሰዎች ወደዱዎት',
                            style: TextStyle(color: colors.onPrimaryContainer, fontWeight: FontWeight.w800, fontSize: 16)),
                        if (superCount > 0)
                          Text(en ? '$superCount super-liked you 💙' : '$superCount ሱፐር ወደዱዎት 💙',
                              style: TextStyle(color: colors.onPrimaryContainer.withValues(alpha: .85), fontSize: 13)),
                      ]),
                    ),
                    Icon(Icons.chevron_right_rounded, color: colors.onPrimaryContainer),
                  ]),
                ),
              ),
            ),
          );
        }),
      _SectionCard(
          title: en ? 'Compatibility discovery' : 'ተስማሚነት ፍለጋ',
          children: discovery.isEmpty
              ? [
                  Text(en
                      ? 'Create your relationship profile to see compatible believers.'
                      : 'ተስማሚ አማኞችን ለማየት የግንኙነት መገለጫህን ፍጠር።')
                ]
              : [
                  for (final item in discovery.take(6))
                    Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: (item['userId'] ?? '').toString().isEmpty
                              ? null
                              : () => _openProfile('${item['userId']}'),
                          child: Row(children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundImage: (item['coverPhoto']?.toString().isNotEmpty ?? false)
                                  ? NetworkImage(item['coverPhoto'].toString())
                                  : null,
                              child: (item['coverPhoto']?.toString().isNotEmpty ?? false)
                                  ? null
                                  : const Icon(Icons.person_rounded),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ListTileRow(
                                icon: Icons.favorite_rounded,
                                title:
                                    '${item['fullName'] ?? ''} • ${((item['compatibility'] as Map<String, dynamic>?) ?? const {})['overall'] ?? 70}%',
                                subtitle:
                                    '${item['churchName'] ?? ''} • ${item['city'] ?? ''}\nFaith ${((item['compatibility'] as Map<String, dynamic>?) ?? const {})['faith'] ?? 70}% • Family ${((item['compatibility'] as Map<String, dynamic>?) ?? const {})['familyVision'] ?? 70}%',
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded),
                          ]),
                        )),
                ]),
      const SizedBox(height: 12),
      if (_interestList('received').isNotEmpty) ...[
        _SectionCard(
            title: en ? 'Interested in you' : 'በእርስዎ የተፈለጉ',
            children: [
              for (final it in _interestList('received'))
                _interestTile(
                  photo: it['otherPhoto']?.toString(),
                  name: '${it['otherName'] ?? ''}',
                  subtitle: [it['otherCity'], it['note']]
                      .where((e) => (e ?? '').toString().isNotEmpty)
                      .join(' • '),
                  onTap: () => _openProfile('${it['otherId']}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                        tooltip: en ? 'Pass' : 'አልፍ',
                        onPressed: _busy ? null : () => _declineInterest('${it['id']}'),
                        icon: const Icon(Icons.close_rounded)),
                    IconButton.filled(
                        tooltip: en ? 'Match' : 'ተጣመር',
                        onPressed: _busy ? null : () => _acceptInterest('${it['id']}'),
                        icon: const Icon(Icons.favorite_rounded)),
                  ]),
                ),
            ]),
        const SizedBox(height: 12),
      ],
      if (_interestList('sent').isNotEmpty) ...[
        _SectionCard(
            title: en ? 'Your interests' : 'የእርስዎ ፍላጎቶች',
            children: [
              for (final it in _interestList('sent'))
                _interestTile(
                  photo: it['otherPhoto']?.toString(),
                  name: '${it['otherName'] ?? ''}',
                  subtitle: '${it['otherCity'] ?? ''}',
                  onTap: () => _openProfile('${it['otherId']}'),
                  trailing: Chip(
                    label: Text('${it['status'] ?? 'pending'}'),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ]),
        const SizedBox(height: 12),
      ],
      _SectionCard(
          title: en ? 'Connections and shared journey' : 'ግንኙነቶች እና የጋራ ጉዞ',
          children: connections.isEmpty
              ? [
                  Text(en
                      ? 'Accepted introduction requests will open friendship/courtship connections here.'
                      : 'የተቀበሉ መተዋወቂያ ጥያቄዎች እዚህ ይታያሉ።')
                ]
              : [
                  for (final item in connections.take(3))
                    Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ListTileRow(
                            icon: Icons.handshake_rounded,
                            title: '${item['partnerName'] ?? ''}',
                            subtitle:
                                '${item['stage'] ?? 'friendship'} • ${item['status'] ?? 'active'}')),
                  if (firstConnection != null)
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      FilledButton.tonal(
                          onPressed: _busy
                              ? null
                              : () => _run(
                                  (t) => widget.apiClient
                                      .updateRelationshipStage(
                                          t,
                                          '${firstConnection['id']}',
                                          'courtship'),
                                  en ? 'Stage updated.' : 'ደረጃው ተዘምኗል።'),
                          child: Text(en ? 'Start courtship' : 'መተዋወቅ ጀምር')),
                      OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _run(
                                  (t) => widget.apiClient
                                      .sendRelationshipMessage(
                                          t,
                                          '${firstConnection['id']}',
                                          'Let us pray and walk wisely.',
                                          verseReference: 'Proverbs 3:5-6'),
                                  en ? 'Message sent.' : 'መልዕክት ተልኳል።'),
                          child: Text(en ? 'Verse chat' : 'ቃል አጋራ')),
                      OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _run(
                                  (t) => widget.apiClient.addRelationshipPrayer(
                                      t,
                                      '${firstConnection['id']}',
                                      'Pray for wisdom',
                                      'Guide our friendship and decisions.'),
                                  en ? 'Prayer added.' : 'ጸሎት ታክሏል።'),
                          child: Text(en ? 'Shared prayer' : 'የጋራ ጸሎት')),
                      OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _run(
                                  (t) => widget.apiClient
                                      .addRelationshipBiblePlan(
                                          t,
                                          '${firstConnection['id']}',
                                          'Proverbs for Relationships',
                                          'Proverbs 3'),
                                  en
                                      ? 'Bible plan started.'
                                      : 'የመጽሐፍ ቅዱስ እቅድ ተጀመረ።'),
                          child: Text(en ? 'Bible plan' : 'የቃል እቅድ')),
                      OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _run(
                                  (t) => widget.apiClient
                                      .addRelationshipMilestone(
                                          t,
                                          '${firstConnection['id']}',
                                          'Started Courtship',
                                          'courtship'),
                                  en ? 'Milestone added.' : 'ምዕራፍ ታክሏል።'),
                          child: Text(en ? 'Milestone' : 'ምዕራፍ')),
                      if (mentors.isNotEmpty)
                        OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => _run(
                                    (t) => widget.apiClient
                                        .inviteRelationshipMentor(
                                            t,
                                            '${firstConnection['id']}',
                                            '${mentors.first['id']}'),
                                    en ? 'Mentor invited.' : 'መካሪ ተጋብዟል።'),
                            child: Text(en ? 'Invite mentor' : 'መካሪ ጋብዝ')),
                      OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _run(
                                  (t) => widget.apiClient
                                      .reportRelationshipSafety(t,
                                          relationshipId:
                                              '${firstConnection['id']}',
                                          reason: 'Safety review requested'),
                                  en
                                      ? 'Safety report sent.'
                                      : 'የደህንነት ሪፖርት ተልኳል።'),
                          child: Text(en ? 'Safety' : 'ደህንነት')),
                    ]),
                ]),
      const SizedBox(height: 12),
      _SectionCard(
          title:
              en ? 'Preparation resources and events' : 'የዝግጅት ምንጮች እና ዝግጅቶች',
          children: [
            for (final item in resources.take(3))
              _ListTileRow(
                  icon: Icons.menu_book_rounded,
                  title: '${item['title'] ?? ''}',
                  subtitle:
                      '${item['category'] ?? ''} • ${item['description'] ?? ''}'),
            for (final item in events.take(2))
              _ListTileRow(
                  icon: Icons.event_available_rounded,
                  title: '${item['title'] ?? ''}',
                  subtitle:
                      '${item['location'] ?? ''} • ${_friendlyDateTime('${item['startsAt'] ?? ''}')}'),
          ]),
    ]);
  }
}

class _CourtshipInterestCard extends StatelessWidget {
  const _CourtshipInterestCard(
      {required this.item,
      required this.language,
      required this.isReceiver,
      this.onAccept,
      this.onDecline});

  final CourtshipInterestItem item;
  final AppLanguage language;
  final bool isReceiver;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    final statusLabel = item.status == 'accepted'
        ? AppStrings.of(language, 'accepted')
        : item.status == 'declined'
            ? AppStrings.of(language, 'declined')
            : AppStrings.of(language, 'pending');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${item.senderName} → ${item.receiverName}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(item.note, maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Text('${AppStrings.of(language, 'courtship_status')}: $statusLabel',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            if (isReceiver && item.status == 'pending') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                      onPressed: onDecline,
                      child: Text(AppStrings.of(language, 'declined'))),
                  const SizedBox(width: 8),
                  FilledButton(
                      onPressed: onAccept,
                      child: Text(AppStrings.of(language, 'accepted'))),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
