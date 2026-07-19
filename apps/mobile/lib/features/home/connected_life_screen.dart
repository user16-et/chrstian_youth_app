import 'package:flutter/material.dart';

import '../../data/api_client.dart';
import '../../data/app_models.dart';
import '../../i18n/app_i18n.dart';
import '../../theme/app_theme.dart';
import '../modules/live_chat_panel.dart';

class ConnectedLifeScreen extends StatefulWidget {
  const ConnectedLifeScreen({
    super.key,
    required this.language,
    required this.apiClient,
    required this.session,
  });

  final AppLanguage language;
  final ApiClient apiClient;
  final AuthResult session;

  @override
  State<ConnectedLifeScreen> createState() => _ConnectedLifeScreenState();
}

class _ConnectedLifeScreenState extends State<ConnectedLifeScreen> {
  late Future<Map<String, dynamic>> _future;
  bool _busy = false;

  bool get en => widget.language == AppLanguage.english;
  String get token => widget.session.token;

  @override
  void initState() {
    super.initState();
    _future = widget.apiClient.fetchCommunityHome(token);
  }

  void _refresh() {
    final next = widget.apiClient.fetchCommunityHome(token);
    setState(() => _future = next);
  }

  List<Map<String, dynamic>> _items(Map<String, dynamic> data, String key) =>
      (data[key] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();

  Future<String?> _ask(String title, {String hint = ''}) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(hintText: hint),
            maxLines: 3),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(en ? 'Cancel' : 'ተው')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text(en ? 'Continue' : 'ቀጥል')),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _run(Future<dynamic> Function() action,
      {String? success}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ?? (en ? 'Saved.' : 'ተቀምጧል።'))),
      );
      _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _line(Iterable<dynamic> values) => values
      .map((value) => value?.toString() ?? '')
      .where((value) => value.trim().isNotEmpty)
      .join(' • ');

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 8,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppTheme.forest, AppTheme.evergreen]),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(children: [
              const Icon(Icons.hub_rounded, color: Colors.white, size: 34),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(en ? 'Community network' : 'የማህበረሰብ አውታረ መረብ',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(color: Colors.white)),
                    Text(
                        en
                            ? 'Meet believers beyond your church: friends, groups, prayer, mentorship and opportunities.'
                            : 'ከቤተክርስቲያንህ ውጭ አማኞችን አግኝ፤ ጓደኞች፣ ቡድኖች፣ ጸሎት፣ ምክር እና ዕድሎች።',
                        style: const TextStyle(color: Colors.white70)),
                  ])),
              if (_busy)
                const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white)),
            ]),
          ),
          TabBar(isScrollable: true, tabs: [
            Tab(text: en ? 'Feed' : 'ፊድ'),
            Tab(text: en ? 'Discover' : 'አግኝ'),
            Tab(text: en ? 'Groups' : 'ቡድኖች'),
            Tab(text: en ? 'Fellowship' : 'ኅብረት'),
            Tab(text: en ? 'Mentorship' : 'ምክር'),
            Tab(text: en ? 'Prayer' : 'ጸሎት'),
            Tab(text: en ? 'Following' : 'ተከታዮች'),
            Tab(text: en ? 'Opportunities' : 'ዕድሎች'),
          ]),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _Empty(
                      message: snapshot.error.toString(), onRetry: _refresh);
                }
                final data = snapshot.data ?? const <String, dynamic>{};
                return TabBarView(children: [
                  _feed(data),
                  _discover(data),
                  _groups(data),
                  _fellowship(data),
                  _mentorship(data),
                  _prayer(data),
                  _following(data),
                  _opportunities(data),
                ]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _feed(Map<String, dynamic> data) => _list([
        _HeroAction(
          title: en ? 'Start a discussion' : 'ውይይት ጀምር',
          subtitle: en
              ? 'Ask a Bible, career, relationship, ministry or school question.'
              : 'የመጽሐፍ፣ ሥራ፣ ግንኙነት፣ አገልግሎት ወይም ትምህርት ጥያቄ ጠይቅ።',
          icon: Icons.edit_note_rounded,
          onTap: _createDiscussion,
        ),
        _SectionTitle(en ? 'Community discussions' : 'የማህበረሰብ ውይይቶች'),
        for (final item in _items(data, 'discussions'))
          _LifeCard(
            icon: Icons.question_answer_rounded,
            title: item['title']?.toString() ?? '',
            subtitle: '${item['body'] ?? ''}\n${_line([
                  item['authorName'],
                  item['category'],
                  item['groupName']
                ])}',
            badge:
                '${item['upvoteCount'] ?? 0} ↑ • ${item['replyCount'] ?? 0} replies',
            actions: [
              IconButton(
                  onPressed: item['upvotedByMe'] == true
                      ? null
                      : () => _run(() => widget.apiClient
                          .upvoteCommunityDiscussion(token, item['id'])),
                  icon: const Icon(Icons.arrow_upward_rounded)),
              IconButton(
                  onPressed: item['savedByMe'] == true
                      ? null
                      : () => _run(() => widget.apiClient
                          .saveCommunityDiscussion(token, item['id'])),
                  icon: const Icon(Icons.bookmark_add_outlined)),
              FilledButton.tonal(
                  onPressed: () async {
                    final body = await _ask(en ? 'Reply' : 'መልስ');
                    if (body?.isNotEmpty == true) {
                      _run(() => widget.apiClient
                          .replyCommunityDiscussion(token, item['id'], body!));
                    }
                  },
                  child: Text(en ? 'Reply' : 'መልስ')),
            ],
          ),
        _SectionTitle(en ? 'Community feed' : 'የማህበረሰብ ፊድ'),
        for (final item in _items(data, 'feed'))
          _LifeCard(
            icon: item['postType'] == 'video'
                ? Icons.play_circle_rounded
                : Icons.dynamic_feed_rounded,
            title: item['authorName']?.toString() ?? '',
            subtitle: '${item['body'] ?? ''}\n${_line([
                  item['churchName'],
                  item['ministryName']
                ])}',
            badge:
                '${item['likeCount'] ?? 0} likes • ${item['commentCount'] ?? 0} comments',
            actions: const [],
          ),
      ]);

  Future<void> _createDiscussion() async {
    final title = await _ask(en ? 'Discussion title' : 'የውይይት ርዕስ');
    if (title?.isNotEmpty != true) return;
    final body = await _ask(en ? 'Question or topic' : 'ጥያቄ ወይም ርዕስ');
    if (body?.isNotEmpty != true) return;
    _run(
        () => widget.apiClient.createCommunityDiscussion(token, {
              'title': title,
              'body': body,
              'category': 'general',
            }),
        success: en ? 'Discussion posted.' : 'ውይይት ተለጥፏል።');
  }

  Widget _discover(Map<String, dynamic> data) => _list([
        _SectionTitle(en ? 'Believers to know' : 'ልታውቃቸው የሚገቡ አማኞች'),
        for (final item in _items(data, 'discover'))
          _LifeCard(
            icon: Icons.person_search_rounded,
            title: item['fullName']?.toString() ?? '',
            subtitle: '${_line([
                  item['city'],
                  item['occupation'],
                  item['church']
                ])}\n${item['testimony'] ?? ''}',
            badge: item['friendStatus']?.toString().isNotEmpty == true
                ? item['friendStatus'].toString()
                : (item['followedByMe'] == true ? 'Following' : null),
            // Never offer follow/friend/message actions on your own account.
            actions: '${item['id']}' == widget.session.user.id
                ? const []
                : [
              FilledButton.tonal(
                  onPressed: item['followedByMe'] == true
                      ? null
                      : () => _run(() => widget.apiClient
                          .followUser(token: token, userId: item['id'])),
                  child: Text(en ? 'Follow' : 'ተከተል')),
              if (item['friendStatus'] != 'accepted')
                OutlinedButton(
                    onPressed: () => _run(
                        () => widget.apiClient
                            .sendFriendRequest(token, item['id']),
                        success:
                            en ? 'Friend request sent.' : 'የጓደኝነት ጥያቄ ተልኳል።'),
                    child: Text(en ? 'Friend' : 'ጓደኛ')),
              // Message only once you're friends.
              if (item['friendStatus'] == 'accepted')
                OutlinedButton(
                    onPressed: () => _run(
                        () => widget.apiClient
                            .startConversation(token, item['id']),
                        success: en ? 'Conversation opened.' : 'ውይይት ተከፍቷል።'),
                    child: Text(en ? 'Message' : 'መልዕክት')),
            ],
          ),
      ]);

  Widget _groups(Map<String, dynamic> data) => _list([
        _HeroAction(
          title: en ? 'Create community group' : 'የማህበረሰብ ቡድን ፍጠር',
          subtitle: en
              ? 'Start a Bible study, prayer, professional, youth or hobby community.'
              : 'የመጽሐፍ፣ ጸሎት፣ ሙያ፣ ወጣት ወይም የፍላጎት ቡድን ጀምር።',
          icon: Icons.add_circle_rounded,
          onTap: _createGroup,
        ),
        for (final item in _items(data, 'groups'))
          _LifeCard(
            icon: Icons.groups_rounded,
            title: item['name']?.toString() ?? '',
            subtitle:
                '${item['description'] ?? ''}\n${item['category']} • ${item['memberCount']} members • ${item['type']}',
            badge: item['membershipStatus']?.toString().isNotEmpty == true
                ? item['membershipStatus'].toString()
                : null,
            actions: [
              TextButton(
                  onPressed: item['membershipStatus'] == 'active'
                      ? () => _group(item)
                      : null,
                  child: Text(en ? 'Open activity' : 'እንቅስቃሴ')),
              FilledButton.tonal(
                  onPressed: item['membershipStatus'] == 'active'
                      ? () async {
                          final body = await _ask(
                              en ? 'New group discussion' : 'አዲስ ውይይት');
                          if (body?.isNotEmpty == true) {
                            _run(() => widget.apiClient
                                .createGroupPost(token, item['id'], body!));
                          }
                        }
                      : null,
                  child: Text(en ? 'Post' : 'ለጥፍ')),
              FilledButton(
                  onPressed: item['membershipStatus'] == 'active'
                      ? null
                      : () => _run(
                          () => widget.apiClient
                              .joinCommunityGroup(token, item['id']),
                          success: item['type'] == 'private'
                              ? 'Request sent.'
                              : 'Joined group.'),
                  child: Text(en ? 'Join' : 'ተቀላቀል')),
            ],
          ),
      ]);

  Future<void> _createGroup() async {
    final name = await _ask(en ? 'Group name' : 'የቡድን ስም');
    if (name?.isNotEmpty != true) return;
    final description = await _ask(en ? 'Description' : 'መግለጫ');
    _run(
        () => widget.apiClient.createCommunityGroup(token, {
              'name': name,
              'description': description ?? '',
              'category': 'Community',
              'type': 'public',
            }),
        success: en ? 'Community group created.' : 'የማህበረሰብ ቡድን ተፈጥሯል።');
  }

  Future<void> _group(Map<String, dynamic> group) async {
    final activity = await widget.apiClient
        .fetchGroupActivity(group['id'], token: widget.session.token);
    if (!mounted) return;
    final posts = _items(activity, 'posts');
    final resources = _items(activity, 'resources');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .72,
        builder: (_, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.all(20),
            children: [
              Text(group['name'],
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 14),
              LiveChatPanel(
                apiClient: widget.apiClient,
                session: widget.session,
                language: widget.language,
                scopeType: 'group',
                scopeId: group['id']?.toString() ?? '',
                title: '${group['name'] ?? 'Group'} chat',
                compact: true,
              ),
              const SizedBox(height: 14),
              Text(en ? 'Discussions' : 'ውይይቶች',
                  style: Theme.of(context).textTheme.titleLarge),
              for (final post in posts)
                ListTile(
                  leading: const CircleAvatar(
                      child: Icon(Icons.chat_bubble_outline_rounded)),
                  title: Text(post['body']?.toString() ?? ''),
                  subtitle: Text(post['authorName']?.toString() ?? ''),
                ),
              const Divider(),
              Text(en ? 'Shared resources' : 'የጋራ ግብዓቶች',
                  style: Theme.of(context).textTheme.titleLarge),
              for (final resource in resources)
                ListTile(
                  leading: const Icon(Icons.link_rounded),
                  title: Text(resource['title']?.toString() ?? ''),
                  subtitle: Text(resource['resourceUrl']?.toString() ?? ''),
                ),
            ]),
      ),
    );
  }

  Widget _fellowship(Map<String, dynamic> data) => _list([
        _HeroAction(
          title: en ? 'Find prayer partner' : 'የጸሎት አጋር ፈልግ',
          subtitle: en
              ? 'Ask the community for a weekly prayer accountability partner.'
              : 'ሳምንታዊ የጸሎት ተጠያቂነት አጋር ጠይቅ።',
          icon: Icons.handshake_rounded,
          onTap: _requestPrayerPartner,
        ),
        _SectionTitle(en ? 'Prayer partner requests' : 'የጸሎት አጋር ጥያቄዎች'),
        for (final item in _items(data, 'prayerPartners'))
          _LifeCard(
            icon: Icons.people_alt_rounded,
            title: item['requesterName']?.toString() ?? '',
            subtitle:
                '${item['city'] ?? ''}\n${(item['interests'] as List<dynamic>? ?? const []).join(', ')}',
            badge: item['status']?.toString(),
            actions: [
              FilledButton.tonal(
                  onPressed: () => _run(
                      () => widget.apiClient
                          .matchPrayerPartner(token, item['id']),
                      success: en
                          ? 'Prayer partner request sent.'
                          : 'የጸሎት አጋር ጥያቄ ተልኳል።'),
                  child: Text(en ? 'Partner' : 'አጋር'))
            ],
          ),
        _SectionTitle(en ? 'Community events' : 'የማህበረሰብ ዝግጅቶች'),
        for (final item in _items(data, 'events'))
          _LifeCard(
            icon: Icons.event_available_rounded,
            title: item['title']?.toString() ?? '',
            subtitle: '${item['description'] ?? ''}\n${_line([
                  item['category'],
                  item['location'],
                  item['startsAt']
                ])}',
            badge: '${item['registrationCount'] ?? 0}/${item['capacity'] ?? 0}',
            actions: [
              FilledButton(
                  onPressed: item['registeredByMe'] == true
                      ? null
                      : () => _run(
                          () => widget.apiClient
                              .registerCommunityEvent(token, item['id']),
                          success:
                              en ? 'Registered for event.' : 'ለዝግጅቱ ተመዝግበሃል።'),
                  child: Text(en ? 'Register' : 'ተመዝገብ')),
              OutlinedButton.icon(
                  onPressed: item['registeredByMe'] == true
                      ? () => _openCommunityEventChat(item)
                      : null,
                  icon: const Icon(Icons.forum_rounded),
                  label: Text(en ? 'Chat' : 'ውይይት')),
            ],
          ),
      ]);

  Future<void> _openCommunityEventChat(Map<String, dynamic> event) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: LiveChatPanel(
          apiClient: widget.apiClient,
          session: widget.session,
          language: widget.language,
          scopeType: 'community_event',
          scopeId: event['id']?.toString() ?? '',
          title: '${event['title'] ?? 'Event'} chat',
          compact: true,
        ),
      ),
    );
  }

  Future<void> _requestPrayerPartner() async {
    final city = await _ask(en ? 'City' : 'ከተማ', hint: 'Addis Ababa');
    _run(
        () => widget.apiClient.requestPrayerPartner(token, {
              'city': city ?? '',
              'interests': ['Prayer', 'Bible Study', 'Accountability'],
            }),
        success: en ? 'Prayer partner request opened.' : 'የጸሎት አጋር ጥያቄ ተከፍቷል።');
  }

  Widget _mentorship(Map<String, dynamic> data) => _list([
        _SectionTitle(
            en ? 'Mentors across the community' : 'በማህበረሰቡ ውስጥ መካሪዎች'),
        for (final item in _items(data, 'mentors'))
          _LifeCard(
            icon: Icons.psychology_alt_rounded,
            title: item['name']?.toString() ?? '',
            subtitle: '${_line([
                  item['title'],
                  item['specialty'],
                  item['city']
                ])}\n${item['bio'] ?? ''}',
            badge: item['verified'] == true ? 'Verified' : null,
            actions: [
              FilledButton.tonal(
                  onPressed: item['followedByMe'] == true
                      ? null
                      : () => _run(
                          () => widget.apiClient
                              .followMentor(token: token, mentorId: item['id']),
                          success: en ? 'Mentor followed.' : 'መካሪ ተከተልክ።'),
                  child: Text(en ? 'Follow' : 'ተከተል')),
              OutlinedButton(
                  onPressed: () async {
                    final note =
                        await _ask(en ? 'Mentorship note' : 'የምክር ማስታወሻ');
                    if (note?.isNotEmpty == true) {
                      _run(() => widget.apiClient.createMentorshipRequest(
                          token: token, mentorId: item['id'], note: note!));
                    }
                  },
                  child: Text(en ? 'Request' : 'ጠይቅ')),
            ],
          ),
      ]);

  Widget _prayer(Map<String, dynamic> data) => _list([
        _HeroAction(
          title: en ? 'Share a community prayer' : 'የማህበረሰብ ጸሎት አጋራ',
          subtitle: en
              ? 'Public, anonymous and community prayer requests remain visible here.'
              : 'የሕዝብ፣ ስም-አልባ እና የማህበረሰብ ጸሎቶች እዚህ ይታያሉ።',
          icon: Icons.volunteer_activism_rounded,
          onTap: () async {
            final title = await _ask(en ? 'Prayer title' : 'የጸሎት ርዕስ');
            if (title?.isNotEmpty != true) return;
            final body = await _ask(en ? 'Prayer body' : 'የጸሎት ይዘት');
            if (body?.isNotEmpty == true) {
              _run(() => widget.apiClient.createPrayerRequest(
                  token: token, title: title!, body: body!));
            }
          },
        ),
        for (final item in _items(data, 'prayers'))
          _LifeCard(
            icon: Icons.favorite_rounded,
            title: item['title']?.toString() ?? '',
            subtitle: '${item['description'] ?? ''}\n${_line([
                  item['authorName'],
                  item['visibility'],
                  item['status']
                ])}',
            badge: '${item['prayedCount'] ?? 0} prayed',
            actions: [
              FilledButton.tonal(
                  onPressed: item['prayedByMe'] == true
                      ? null
                      : () => _run(
                          () => widget.apiClient
                              .markPrayerPrayed(token, item['id']),
                          success: en
                              ? 'Prayer commitment recorded.'
                              : 'የጸሎት ቃል ተመዝግቧል።'),
                  child: Text(en ? 'I prayed' : 'ጸለይኩ'))
            ],
          ),
      ]);

  Widget _following(Map<String, dynamic> data) {
    final analytics = data['analytics'] as Map<String, dynamic>? ?? const {};
    return _list([
      _LifeCard(
        icon: Icons.analytics_rounded,
        title: en ? 'Community pulse' : 'የማህበረሰብ ሁኔታ',
        subtitle:
            'Users: ${analytics['activeUsers'] ?? 0}\nGroups: ${analytics['groups'] ?? 0}\nDiscussions: ${analytics['discussions'] ?? 0}\nPrayer actions: ${analytics['prayerActivity'] ?? 0}\nEvent registrations: ${analytics['eventRegistrations'] ?? 0}',
        actions: const [],
      ),
      _SectionTitle(en ? 'Following' : 'ተከታዮች'),
      for (final item in _items(data, 'following'))
        _LifeCard(
            icon: Icons.rss_feed_rounded,
            title: item['name']?.toString() ?? '',
            subtitle: _line([item['type'], item['subtitle']]),
            actions: const []),
    ]);
  }

  Widget _opportunities(Map<String, dynamic> data) => _list([
        _SectionTitle(en
            ? 'Jobs, internships, missions and scholarships'
            : 'ሥራ፣ ኢንተርንሺፕ፣ ሚሲዮን እና ስኮላርሺፕ'),
        for (final item in _items(data, 'opportunities'))
          _LifeCard(
            icon: Icons.work_outline_rounded,
            title: item['title']?.toString() ?? '',
            subtitle: '${_line([
                  item['organization'],
                  item['category'],
                  item['location']
                ])}\n${item['description'] ?? ''}',
            badge: item['deadline']?.toString(),
            actions: [
              FilledButton.tonal(
                  onPressed: () => _run(
                      () => widget.apiClient.applyForOpportunity(
                          token: token,
                          opportunityId: item['id'],
                          note: 'Applying from Community.'),
                      success: en ? 'Application sent.' : 'ማመልከቻ ተልኳል።'),
                  child: Text(en ? 'Apply' : 'አመልክት'))
            ],
          ),
        _SectionTitle(en ? 'Community challenges' : 'የማህበረሰብ ፈተናዎች'),
        for (final item in _items(data, 'challenges'))
          _LifeCard(
            icon: Icons.local_fire_department_rounded,
            title: item['title']?.toString() ?? '',
            subtitle:
                '${item['description']}\n${item['completedDays']}/${item['targetDays']} days • streak ${item['streak']}',
            badge: item['completedAt'] != null
                ? (en ? 'Completed' : 'ተጠናቋል')
                : null,
            actions: [
              if (item['enrolledAt'] == null)
                FilledButton(
                    onPressed: () => _run(() =>
                        widget.apiClient.enrollChallenge(token, item['id'])),
                    child: Text(en ? 'Join' : 'ተቀላቀል'))
              else
                FilledButton.tonal(
                    onPressed: () => _run(() =>
                        widget.apiClient.checkinChallenge(token, item['id'])),
                    child: Text(en ? 'Today complete' : 'ዛሬ ተጠናቋል')),
            ],
          ),
      ]);

  Widget _list(List<Widget> children) => RefreshIndicator(
        onRefresh: () async {
          _refresh();
          await _future;
        },
        child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
            children: [
              ...children
                  .expand((child) => [child, const SizedBox(height: 12)]),
            ]),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 2),
        child: Text(text, style: Theme.of(context).textTheme.titleLarge),
      );
}

class _HeroAction extends StatelessWidget {
  const _HeroAction(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.onTap});
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF12372A), Color(0xFF3E6B43), Color(0xFFF6C453)],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x2212372A),
                  blurRadius: 24,
                  offset: Offset(0, 12))
            ],
          ),
          child: Row(children: [
            Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(18)),
                child: Icon(icon, color: Colors.white, size: 30)),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.white70)),
                ])),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white),
          ]),
        ),
      );
}

class _LifeCard extends StatelessWidget {
  const _LifeCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.actions,
      this.badge});
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> actions;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: colors.outline.withValues(alpha: .18)),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: .10),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [AppTheme.forest, AppTheme.evergreen]),
                        borderRadius: BorderRadius.circular(15)),
                    child: Icon(icon, color: Colors.white)),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(title,
                        style: Theme.of(context).textTheme.titleLarge)),
                if (badge != null) Chip(label: Text(badge!)),
              ]),
              const SizedBox(height: 10),
              Text(subtitle),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(spacing: 8, runSpacing: 8, children: actions),
              ],
            ],
          )),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
          child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_rounded, size: 44),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ]),
      ));
}
