part of '../module_pages.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.language,
    required this.apiClient,
    required this.session,
    required this.onAuthChanged,
    required this.onDataChanged,
  });

  final AppLanguage language;
  final ApiClient apiClient;
  final AuthResult? session;
  final ValueChanged<AuthResult?> onAuthChanged;
  final Future<void> Function() onDataChanged;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _testimonyController = TextEditingController();
  final TextEditingController _favoriteVerseController =
      TextEditingController();
  String _profileLanguage = 'en';
  UserProfile? _profile;
  List<ChurchMembershipItem> _memberships = const [];
  Map<String, dynamic> _dashboard = const {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final user = widget.session?.user;
    _profile = user;
    _profileLanguage = user?.language ?? widget.language.code;
    _fullNameController.text = user?.fullName ?? '';
    if (widget.session != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    _testimonyController.dispose();
    _favoriteVerseController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      return;
    }
    final UserProfile? profile;
    final List<ChurchMembershipItem> memberships;
    final Map<String, dynamic> dashboard;
    try {
      profile = await widget.apiClient.me(token);
      memberships = await widget.apiClient.fetchMyChurchMemberships(token);
      dashboard = await widget.apiClient.fetchProfileDashboard(token);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(error.toString().replaceFirst('HttpException: ', ''))));
      }
      return;
    }
    if (!mounted) {
      return;
    }
    final identity =
        (dashboard['identity'] as Map<String, dynamic>?) ?? const {};
    setState(() {
      _profile = profile ?? widget.session?.user;
      _memberships = memberships;
      _dashboard = dashboard;
      _fullNameController.text = _profile?.fullName ?? '';
      _bioController.text = '${identity['bio'] ?? ''}';
      _cityController.text = '${identity['city'] ?? ''}';
      _testimonyController.text = '${identity['testimony'] ?? ''}';
      _favoriteVerseController.text = '${identity['favoriteVerse'] ?? ''}';
      _profileLanguage = _profile?.language ?? widget.language.code;
    });
  }

  Future<void> _changePassword() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) return;
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final en = widget.language == AppLanguage.english;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(en ? 'Change password' : 'የይለፍ ቃል ቀይር'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: current,
              obscureText: true,
              decoration: InputDecoration(
                  labelText: en ? 'Current password' : 'የአሁኑ የይለፍ ቃል'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: next,
              obscureText: true,
              decoration: InputDecoration(
                  labelText: en ? 'New password' : 'አዲስ የይለፍ ቃል'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: confirm,
              obscureText: true,
              decoration: InputDecoration(
                  labelText:
                      en ? 'Confirm new password' : 'አዲሱን የይለፍ ቃል ያረጋግጡ'),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(en ? 'Cancel' : 'ተወው')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(en ? 'Change' : 'ቀይር')),
        ],
      ),
    );
    final currentPassword = current.text;
    final newPassword = next.text;
    final confirmPassword = confirm.text;
    current.dispose();
    next.dispose();
    confirm.dispose();
    if (ok != true) return;
    if (currentPassword.isEmpty || newPassword.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(en
                ? 'Enter your current and new password.'
                : 'የአሁኑን እና አዲሱን የይለፍ ቃል ያስገቡ።')));
      }
      return;
    }
    if (newPassword != confirmPassword) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(en ? 'Passwords do not match.' : 'የይለፍ ቃሎቹ አይዛመዱም።')));
      }
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.apiClient.changePassword(
        token: token,
        currentPassword: currentPassword,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(error.toString().replaceFirst('HttpException: ', ''))));
      }
      return;
    }
    if (!mounted) return;
    widget.onAuthChanged(null);
    await widget.onDataChanged();
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(en
            ? 'Password changed. Sign in again.'
            : 'የይለፍ ቃል ተቀይሯል። እንደገና ይግቡ።')));
  }

  // Persists a freshly uploaded profile or cover photo, then refreshes so the
  // new image shows everywhere immediately.
  Future<void> _savePhoto({String? profileImage, String? coverImage}) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) return;
    setState(() => _busy = true);
    try {
      await widget.apiClient.updateProfileDashboard(token, {
        if (profileImage != null) 'profileImage': profileImage,
        if (coverImage != null) 'coverImage': coverImage,
      });
      await _reload();
      await widget.onDataChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(widget.language == AppLanguage.english
                ? 'Photo updated.'
                : 'ፎቶ ተቀይሯል።')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                error.toString().replaceFirst('HttpException: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeCoverPhoto() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) return;
    final url = await pickAndUploadImage(context,
        apiClient: widget.apiClient, token: token, usage: 'cover_photo');
    if (url != null) await _savePhoto(coverImage: url);
  }

  Future<void> _save() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      return;
    }
    final en = widget.language == AppLanguage.english;
    if (_fullNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(en ? 'Name cannot be empty.' : 'ስም ባዶ መሆን አይችልም።')));
      return;
    }
    setState(() {
      _busy = true;
    });
    try {
      await widget.apiClient.updateProfileDashboard(token, {
        'fullName': _fullNameController.text.trim(),
        'language': _profileLanguage,
        'bio': _bioController.text,
        'city': _cityController.text,
        'testimony': _testimonyController.text,
        'favoriteVerse': _favoriteVerseController.text,
      });
      final updated = await widget.apiClient.me(token);
      final dashboard = await widget.apiClient.fetchProfileDashboard(token);
      if (!mounted) return;
      setState(() {
        _profile = updated ?? _profile;
        _dashboard = dashboard;
      });
      widget.onAuthChanged(
          AuthResult(token: token, user: _profile ?? widget.session!.user));
      await widget.onDataChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(en ? 'Profile saved.' : 'መገለጫ ተቀምጧል።')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(error.toString().replaceFirst('HttpException: ', ''))));
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    final en = language == AppLanguage.english;
    final identity =
        (_dashboard['identity'] as Map<String, dynamic>?) ?? const {};
    final community =
        (_dashboard['community'] as Map<String, dynamic>?) ?? const {};
    final bible = (_dashboard['bible'] as Map<String, dynamic>?) ?? const {};
    final prayers =
        (_dashboard['prayers'] as Map<String, dynamic>?) ?? const {};
    final volunteer =
        (_dashboard['volunteer'] as Map<String, dynamic>?) ?? const {};
    final relationship =
        (_dashboard['relationship'] as Map<String, dynamic>?) ?? const {};
    final analytics =
        (_dashboard['analytics'] as Map<String, dynamic>?) ?? const {};
    List<Map<String, dynamic>> items(String key) =>
        (_dashboard[key] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>();
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.of(language, 'profile_details'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SectionHeader(
            title: en ? 'Complete Christian identity' : 'ሙሉ ክርስቲያናዊ መታወቂያ',
            subtitle: en
                ? 'Social, church, ministry, spiritual, relationship, service and achievement profile.'
                : 'ማህበራዊ፣ ቤተ ክርስቲያን፣ አገልግሎት፣ መንፈሳዊ፣ ግንኙነት፣ አገልግሎት እና ሽልማት መገለጫ።',
          ),
          const SizedBox(height: 16),
          _SectionCard(title: en ? 'Public profile' : 'የሚታይ መገለጫ', children: [
            Row(children: [
              ImageUploadAvatar(
                apiClient: widget.apiClient,
                token: widget.session?.token ?? '',
                usage: 'profile_photo',
                radius: 34,
                currentUrl: '${identity['profileImage'] ?? identity['photoUrl'] ?? ''}',
                initials: (_profile?.fullName.isNotEmpty == true
                        ? _profile!.fullName[0]
                        : '?')
                    .toUpperCase(),
                onUploaded: (url) => _savePhoto(profileImage: url),
              ),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(_profile?.fullName ?? '',
                        style: Theme.of(context).textTheme.titleLarge),
                    Text(
                        '@${identity['username'] ?? ''} • ${identity['city'] ?? ''} • ${identity['country'] ?? 'Ethiopia'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    Text('${identity['bio'] ?? ''}',
                        maxLines: 3, overflow: TextOverflow.ellipsis),
                  ])),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _InfoChip(label: '${community['followers'] ?? 0} followers'),
              _InfoChip(label: '${community['following'] ?? 0} following'),
              _InfoChip(label: '${community['friends'] ?? 0} friends'),
              _InfoChip(label: '${items('achievements').length} badges'),
            ]),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _changeCoverPhoto,
                icon: const Icon(Icons.image_rounded, size: 18),
                label: Text(en ? 'Change cover photo' : 'የሽፋን ፎቶ ቀይር'),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          _SectionCard(
            title:
                en ? 'Personal, spiritual and settings' : 'የግል፣ መንፈሳዊ እና ቅንብሮች',
            children: [
              TextField(
                controller: _fullNameController,
                decoration: InputDecoration(
                    labelText: AppStrings.of(language, 'full_name')),
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: _bioController,
                  decoration: const InputDecoration(labelText: 'Bio'),
                  maxLines: 2),
              const SizedBox(height: 12),
              TextField(
                  controller: _cityController,
                  decoration: InputDecoration(
                      labelText: AppStrings.of(language, 'city'))),
              const SizedBox(height: 12),
              TextField(
                  controller: _testimonyController,
                  decoration:
                      const InputDecoration(labelText: 'Salvation testimony'),
                  maxLines: 3),
              const SizedBox(height: 12),
              TextField(
                  controller: _favoriteVerseController,
                  decoration:
                      const InputDecoration(labelText: 'Favorite Bible verse')),
              const SizedBox(height: 12),
              _fieldLabel(AppStrings.of(language, 'preferred_language')),
              DropdownButtonFormField<String>(
                initialValue: _profileLanguage,
                isExpanded: true,
                items: [
                  DropdownMenuItem(
                      value: 'en',
                      child:
                          Text(AppStrings.of(AppLanguage.english, 'english'))),
                  DropdownMenuItem(
                      value: 'am',
                      child:
                          Text(AppStrings.of(AppLanguage.amharic, 'amharic'))),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(
                        () => _profileLanguage = value ?? _profileLanguage),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(AppStrings.of(language, 'save_profile')),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _changePassword,
                icon: const Icon(Icons.lock_reset_rounded),
                label: Text(en ? 'Change password' : 'የይለፍ ቃል ቀይር'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ProfileGrid(title: en ? 'Spiritual life' : 'መንፈሳዊ ሕይወት', rows: [
            ('Years in faith', '${identity['yearsInFaith'] ?? 0}'),
            ('Baptism', '${identity['baptismStatus'] ?? 'not_set'}'),
            ('Favorite verse', '${identity['favoriteVerse'] ?? ''}'),
            ('Bible notes', '${bible['notes'] ?? 0}'),
            ('Bookmarks', '${bible['bookmarks'] ?? 0}'),
            ('Reading streak', '${bible['streak'] ?? 0}'),
            ('Prayer requests', '${prayers['requests'] ?? 0}'),
            ('Answered prayers', '${prayers['answered'] ?? 0}'),
          ]),
          const SizedBox(height: 16),
          _SectionCard(
            title: AppStrings.of(language, 'joined_churches'),
            children: [
              if (_memberships.isEmpty)
                Text(AppStrings.of(language, 'no_memberships'))
              else
                ..._memberships.map((membership) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                          '${membership.churchName} • ${membership.city}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    )),
            ],
          ),
          const SizedBox(height: 16),
          _ProfileList(
              title: en ? 'Ministries and service' : 'አገልግሎቶች እና አገልግሎት',
              icon: Icons.volunteer_activism_rounded,
              items: items('ministries'),
              titleOf: (x) => '${x['name'] ?? ''}',
              subtitleOf: (x) =>
                  '${x['role'] ?? ''} • ${x['status'] ?? ''} • ${x['serviceHours'] ?? 0}h'),
          const SizedBox(height: 16),
          _ProfileGrid(
              title: en ? 'Community and relationship' : 'ማህበረሰብ እና ግንኙነት',
              rows: [
                ('Groups', '${community['groups'] ?? 0}'),
                ('Discussions', '${community['discussions'] ?? 0}'),
                (
                  'Relationship',
                  '${relationship['activationMode'] ?? 'hidden'}'
                ),
                ('Connections', '${relationship['connections'] ?? 0}'),
                (
                  'Church verified',
                  '${relationship['churchVerified'] == true}'
                ),
                (
                  'Pastor recommended',
                  '${relationship['pastorRecommended'] == true}'
                ),
              ]),
          const SizedBox(height: 16),
          _ProfileList(
              title: en ? 'Posts and testimonies' : 'ፖስቶች እና ምስክርነቶች',
              icon: Icons.dynamic_feed_rounded,
              items: items('posts'),
              titleOf: (x) => '${x['postType'] ?? 'post'}',
              subtitleOf: (x) => '${x['body'] ?? ''}'),
          const SizedBox(height: 16),
          _ProfileList(
              title: en ? 'Event history' : 'የዝግጅት ታሪክ',
              icon: Icons.event_available_rounded,
              items: items('events'),
              titleOf: (x) => '${x['title'] ?? ''}',
              subtitleOf: (x) =>
                  '${x['status'] ?? ''} • ${_friendlyDateTime('${x['checkedInAt'] ?? x['startsAt'] ?? ''}')}'),
          const SizedBox(height: 16),
          _ProfileGrid(
              title: en ? 'Volunteer profile' : 'የበፈቃድ አገልግሎት መገለጫ',
              rows: [
                ('Ministry hours', '${volunteer['ministryHours'] ?? 0}'),
                ('Event roles', '${volunteer['eventVolunteerRoles'] ?? 0}'),
                (
                  'Ministry roles',
                  '${volunteer['ministryVolunteerRoles'] ?? 0}'
                ),
              ]),
          const SizedBox(height: 16),
          _ProfileList(
              title: en ? 'Achievements and badges' : 'ሽልማቶች እና ባጆች',
              icon: Icons.workspace_premium_rounded,
              items: items('achievements'),
              titleOf: (x) => '${x['title'] ?? x['badge'] ?? ''}',
              subtitleOf: (x) => x['earnedAt'] == null
                  ? ''
                  : 'Earned ${_friendlyDateTime('${x['earnedAt']}')}'),
          const SizedBox(height: 16),
          _ProfileList(
              title: en ? 'Notes and saved library' : 'ማስታወሻዎች እና የተቀመጡ ምንጮች',
              icon: Icons.bookmark_rounded,
              items: [...items('notes'), ...items('saved')],
              titleOf: (x) => '${x['title'] ?? x['contentType'] ?? ''}',
              subtitleOf: (x) =>
                  '${x['body'] ?? x['url'] ?? x['createdAt'] ?? ''}'),
          const SizedBox(height: 16),
          _ProfileList(
              title: en ? 'Mentorship' : 'ምክር',
              icon: Icons.psychology_rounded,
              items: items('mentorship'),
              titleOf: (x) => '${x['mentorName'] ?? ''}',
              subtitleOf: (x) =>
                  '${x['status'] ?? ''} • ${x['ministry'] ?? ''}'),
          const SizedBox(height: 16),
          _ProfileList(
              title: en ? 'Verification center' : 'የማረጋገጫ ማዕከል',
              icon: Icons.verified_user_rounded,
              items: items('verifications'),
              titleOf: (x) => '${x['type'] ?? ''}',
              subtitleOf: (x) => '${x['status'] ?? ''}'),
          const SizedBox(height: 16),
          if (widget.session?.token.isNotEmpty == true)
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.notifications_active_rounded),
                title: Text(en ? 'Notification settings' : 'የማሳወቂያ ቅንብሮች'),
                subtitle: Text(en
                    ? 'Choose what reaches your phone'
                    : 'ወደ ስልክዎ የሚደርሱትን ይምረጡ'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => NotificationSettingsScreen(
                    apiClient: widget.apiClient,
                    token: widget.session!.token,
                    language: widget.language,
                  ),
                )),
              ),
            ),
          const SizedBox(height: 16),
          _ProfileList(
              title: en ? 'Notification history' : 'የማሳወቂያ ታሪክ',
              icon: Icons.notifications_rounded,
              items: items('notifications'),
              titleOf: (x) => '${x['title'] ?? ''}',
              subtitleOf: (x) => '${x['body'] ?? ''}'),
          const SizedBox(height: 16),
          _ProfileGrid(title: en ? 'Personal analytics' : 'የግል ትንታኔ', rows: [
            ('Profile views', '${analytics['profileViews'] ?? 0}'),
            ('Engagement', '${analytics['engagement'] ?? 0}'),
            ('Followers', '${analytics['followers'] ?? 0}'),
            ('Events attended', '${analytics['eventsAttended'] ?? 0}'),
          ]),
          const SizedBox(height: 16),
          Text(AppStrings.of(language, 'current_session')),
          Text(_profile?.phoneNumber ?? '',
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _ProfileGrid extends StatelessWidget {
  const _ProfileGrid({required this.title, required this.rows});
  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: title,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final row in rows)
              Container(
                width: 150,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 6),
                    Text(row.$2, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ProfileList extends StatelessWidget {
  const _ProfileList(
      {required this.title,
      required this.icon,
      required this.items,
      required this.titleOf,
      required this.subtitleOf});
  final String title;
  final IconData icon;
  final List<Map<String, dynamic>> items;
  final String Function(Map<String, dynamic>) titleOf;
  final String Function(Map<String, dynamic>) subtitleOf;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: title,
      children: items.isEmpty
          ? [const Text('No records yet.')]
          : [
              for (final item in items.take(5))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ListTileRow(
                      icon: icon,
                      title: titleOf(item),
                      subtitle: subtitleOf(item)),
                ),
            ],
    );
  }
}

class ChurchMembershipManagementScreen extends StatefulWidget {
  const ChurchMembershipManagementScreen({
    super.key,
    required this.language,
    required this.apiClient,
    required this.session,
    required this.onDataChanged,
  });

  final AppLanguage language;
  final ApiClient apiClient;
  final AuthResult? session;
  final Future<void> Function() onDataChanged;

  @override
  State<ChurchMembershipManagementScreen> createState() =>
      _ChurchMembershipManagementScreenState();
}

class _ChurchMembershipManagementScreenState
    extends State<ChurchMembershipManagementScreen> {
  late Future<List<ChurchMembershipItem>> _membershipsFuture;
  bool _busy = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _membershipsFuture = _load();
  }

  Future<List<ChurchMembershipItem>> _load() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      return const <ChurchMembershipItem>[];
    }
    return widget.apiClient.fetchMyChurchMemberships(token);
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      _membershipsFuture = future;
    });
    await future;
  }

  Future<void> _leaveChurch(ChurchMembershipItem membership) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(() {
        _status = AppStrings.of(widget.language, 'login_required');
      });
      return;
    }

    setState(() {
      _busy = true;
    });
    try {
      await widget.apiClient
          .leaveChurch(token: token, churchId: membership.churchId);
      await widget.onDataChanged();
      await _refresh();
      if (!mounted) {
        return;
      }
      setState(() {
        _status = AppStrings.of(widget.language, 'church_removed');
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = error.toString().replaceFirst('HttpException: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    return Scaffold(
      appBar:
          AppBar(title: Text(AppStrings.of(language, 'membership_management'))),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            _SectionHeader(
              title: AppStrings.of(language, 'membership_management'),
              subtitle: AppStrings.of(language, 'joined_churches'),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<ChurchMembershipItem>>(
              future: _membershipsFuture,
              builder: (context, snapshot) {
                final memberships =
                    snapshot.data ?? const <ChurchMembershipItem>[];
                if (snapshot.connectionState == ConnectionState.waiting &&
                    memberships.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (memberships.isEmpty) {
                  return _EmptyState(
                      message: AppStrings.of(language, 'no_memberships'));
                }
                return Column(
                  children: [
                    for (final membership in memberships) ...[
                      _ListTileRow(
                        icon: Icons.church_rounded,
                        title: membership.churchName,
                        subtitle:
                            '${membership.city} • ${membership.role} • ${membership.verified ? (AppStrings.of(language, 'verified')) : (AppStrings.of(language, 'pending'))}',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChurchDetailScreen(
                                language: language,
                                apiClient: widget.apiClient,
                                church: ChurchItem(
                                  id: membership.churchId,
                                  name: membership.churchName,
                                  city: membership.city,
                                  verified: membership.verified,
                                ),
                                session: widget.session,
                                onDataChanged: widget.onDataChanged,
                              ),
                            ),
                          );
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                  '${AppStrings.of(language, 'member_since')}: ${membership.joinedAt.length >= 10 ? membership.joinedAt.substring(0, 10) : membership.joinedAt}'),
                            ),
                            TextButton(
                              onPressed:
                                  _busy ? null : () => _leaveChurch(membership),
                              child:
                                  Text(AppStrings.of(language, 'leave_church')),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            if (_status.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(_status, maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }
}
