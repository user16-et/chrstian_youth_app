import 'package:flutter/material.dart';

import '../../data/api_client.dart';
import '../../data/app_models.dart';
import '../../data/image_upload.dart';
import '../../i18n/app_i18n.dart';
import '../../theme/app_theme.dart';

class BelieverJourneyScreen extends StatefulWidget {
  const BelieverJourneyScreen(
      {super.key,
      required this.apiClient,
      required this.session,
      required this.language});

  final ApiClient apiClient;
  final AuthResult session;
  final AppLanguage language;

  @override
  State<BelieverJourneyScreen> createState() => _BelieverJourneyScreenState();
}

class _BelieverJourneyScreenState extends State<BelieverJourneyScreen> {
  late Future<Map<String, dynamic>> _future;
  final _city = TextEditingController(text: 'Addis Ababa');
  final _occupation = TextEditingController(text: 'Software Engineer');
  final _photo = TextEditingController();
  final _churchQuery = TextEditingController();
  final Set<String> _interests = {
    'Bible Study',
    'Evangelism',
    'Worship',
    'Courtship'
  };
  String? _churchId;
  ChurchItem? _selectedChurch;
  final Set<String> _ministryIds = {};
  bool _busy = false;

  bool get _english => widget.language == AppLanguage.english;
  String _text(String english, String amharic) => _english ? english : amharic;

  @override
  void initState() {
    super.initState();
    _future = widget.apiClient.fetchJourneyDashboard(widget.session.token);
  }

  @override
  void dispose() {
    _city.dispose();
    _occupation.dispose();
    _photo.dispose();
    _churchQuery.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final future = widget.apiClient.fetchJourneyDashboard(widget.session.token);
    if (!mounted) {
      await future;
      return;
    }
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<void> _run(Future<dynamic> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_text('My Christian journey', 'የክርስትና ጉዞዬ'))),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final profile = data['profile'] as Map<String, dynamic>?;
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
            children: [
              _JourneyHero(
                  name: widget.session.user.fullName,
                  complete: profile?['onboarding_complete'] == true,
                  language: widget.language),
              const SizedBox(height: 16),
              if (profile == null || profile['onboarding_complete'] != true)
                _onboarding(),
              if (profile != null &&
                  profile['onboarding_complete'] == true) ...[
                _summary(profile, data),
                const SizedBox(height: 18),
                _plans((data['plans'] as List).cast<Map<String, dynamic>>()),
                const SizedBox(height: 18),
                _courses(
                    (data['courses'] as List).cast<Map<String, dynamic>>()),
                const SizedBox(height: 18),
                _marketplace(),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _onboarding() {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        widget.apiClient.fetchChurches(),
        widget.apiClient.fetchMinistries()
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final churches = snapshot.data![0] as List<ChurchItem>;
        final ministries = snapshot.data![1] as List<MinistryItem>;
        final churchQuery = _churchQuery.text.trim().toLowerCase();
        final churchMatches = churches
            .where((church) =>
                churchQuery.isEmpty ||
                church.name.toLowerCase().contains(churchQuery) ||
                church.city.toLowerCase().contains(churchQuery) ||
                church.churchType.toLowerCase().contains(churchQuery))
            .take(8)
            .toList();
        final churchMinistries = _churchId == null
            ? const <MinistryItem>[]
            : ministries
                .where((ministry) => ministry.churchId == _churchId)
                .toList();
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_text('Complete your faith profile', 'የእምነት መገለጫዎን ያጠናቅቁ'),
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              Row(children: [
                ImageUploadAvatar(
                  apiClient: widget.apiClient,
                  token: widget.session.token,
                  usage: 'profile_photo',
                  currentUrl: _photo.text,
                  radius: 40,
                  onUploaded: (url) => setState(() => _photo.text = url),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                      _photo.text.isEmpty
                          ? _text('Tap the camera to upload your profile photo.',
                              'የመገለጫ ፎቶዎን ለመስቀል ካሜራውን ይንኩ።')
                          : _text('Profile photo added. Tap to change.',
                              'ፎቶ ተጨምሯል። ለመቀየር ይንኩ።'),
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
              ]),
              const SizedBox(height: 10),
              TextField(
                  controller: _city,
                  decoration: InputDecoration(labelText: _text('City', 'ከተማ'))),
              const SizedBox(height: 10),
              TextField(
                  controller: _occupation,
                  decoration:
                      InputDecoration(labelText: _text('Occupation', 'ሙያ'))),
              const SizedBox(height: 14),
              TextField(
                controller: _churchQuery,
                decoration: InputDecoration(
                  labelText:
                      _text('Search and select church', 'ቤተ ክርስቲያን ፈልገው ይምረጡ'),
                  hintText:
                      _text('Church name, city, or type', 'ስም፣ ከተማ ወይም አይነት'),
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _churchQuery.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setState(() {
                            _churchQuery.clear();
                          }),
                        ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              if (_selectedChurch != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.verified_rounded),
                  title: Text(_selectedChurch!.name),
                  subtitle: Text(_selectedChurch!.city),
                  trailing: TextButton(
                    onPressed: () => setState(() {
                      _churchId = null;
                      _selectedChurch = null;
                      _ministryIds.clear();
                    }),
                    child: Text(_text('Change', 'ቀይር')),
                  ),
                )
              else if (churchMatches.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(_text('No churches found. Try another search.',
                      'ቤተ ክርስቲያን አልተገኘም።')),
                )
              else
                for (final church in churchMatches)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      _churchId == church.id
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                    ),
                    title: Text(church.name),
                    subtitle: Text('${church.city} • ${church.churchType}'),
                    onTap: () => setState(() {
                      _churchId = church.id;
                      _selectedChurch = church;
                      _churchQuery.text = '${church.name} - ${church.city}';
                      _ministryIds.clear();
                    }),
                  ),
              const SizedBox(height: 14),
              Text(
                  _text('Ministries from selected church',
                      'ከተመረጠው ቤተ ክርስቲያን አገልግሎቶች'),
                  style: Theme.of(context).textTheme.titleMedium),
              if (_churchId == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(_text(
                      'Select a church first to see its ministries.',
                      'አገልግሎቶችን ለማየት መጀመሪያ ቤተ ክርስቲያን ይምረጡ።')),
                )
              else if (churchMinistries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(_text('This church has no ministries yet.',
                      'ይህ ቤተ ክርስቲያን እስካሁን አገልግሎት የለውም።')),
                )
              else
                for (final ministry in churchMinistries)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _ministryIds.contains(ministry.id),
                    title: Text(ministry.name),
                    subtitle: Text(ministry.department),
                    onChanged: (selected) => setState(() => selected == true
                        ? _ministryIds.add(ministry.id)
                        : _ministryIds.remove(ministry.id)),
                  ),
              Text(_text('Interests', 'ፍላጎቶች'),
                  style: Theme.of(context).textTheme.titleMedium),
              Wrap(
                  spacing: 8,
                  children: [
                    'Bible Study',
                    'Evangelism',
                    'Worship',
                    'Courtship'
                  ]
                      .map((interest) => FilterChip(
                            label: Text(_interestLabel(interest)),
                            selected: _interests.contains(interest),
                            onSelected: (selected) => setState(() => selected
                                ? _interests.add(interest)
                                : _interests.remove(interest)),
                          ))
                      .toList()),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () {
                        if (_churchId == null || _churchId!.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(_text(
                                'Select your church before continuing.',
                                'ከመቀጠልዎ በፊት ቤተ ክርስቲያንዎን ይምረጡ።')),
                          ));
                          return;
                        }
                        _run(() => widget.apiClient.completeJourneyOnboarding(
                              token: widget.session.token,
                              profile: {
                                'photoUrl': _photo.text,
                                'city': _city.text,
                                'occupation': _occupation.text,
                                'relationshipStatus': 'single',
                                'interests': _interests.toList(),
                                'churchId': _churchId,
                                'ministryIds': _ministryIds.toList()
                              },
                            ));
                      },
                icon: const Icon(Icons.check_circle_rounded),
                label: Text(_text('Create my journey', 'ጉዞዬን ጀምር')),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _summary(Map<String, dynamic> profile, Map<String, dynamic> data) =>
      Card(
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${profile['city']} | ${profile['occupation']}',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text((profile['interests'] as List? ?? []).join('  •  ')),
              const SizedBox(height: 12),
              Text(
                  '${(data['badges'] as List).length} badges  •  ${(data['friends'] as List).length} friendship requests  •  ${(data['orders'] as List).length} orders'),
            ])),
      );

  Widget _plans(List<Map<String, dynamic>> plans) => _section(
      'Bible reading plans',
      plans.map((plan) {
        final enrolled = plan['started_at'] != null;
        return ListTile(
          title: Text('${plan['title']}'),
          subtitle: Text(enrolled
              ? '${plan['completed_days']}/${plan['duration_days']} days • ${plan['streak']} day streak'
              : '${plan['duration_days']} days'),
          trailing: FilledButton.tonal(
              onPressed: _busy
                  ? null
                  : () => _run(() => enrolled
                      ? widget.apiClient.checkinReadingPlan(
                          widget.session.token, '${plan['id']}')
                      : widget.apiClient.enrollReadingPlan(
                          widget.session.token, '${plan['id']}')),
              child: Text(enrolled ? 'Complete day' : 'Join')),
        );
      }).toList());

  Widget _courses(List<Map<String, dynamic>> courses) => _section(
      'Learning and certification',
      courses.map((course) {
        final enrolled = course['enrolled_at'] != null;
        final certified = course['certificate_code'] != null;
        return ListTile(
          title: Text('${course['title']}'),
          subtitle: Text(certified
              ? 'Certificate ${course['certificate_code']}'
              : '${course['completed_lessons']}/${course['lesson_count']} lessons'),
          trailing: certified
              ? const Icon(Icons.workspace_premium_rounded,
                  color: AppTheme.gold)
              : FilledButton.tonal(
                  onPressed: _busy
                      ? null
                      : () => _run(() => enrolled
                          ? widget.apiClient.progressCourse(
                              widget.session.token, '${course['id']}')
                          : widget.apiClient.enrollCourse(
                              widget.session.token, '${course['id']}')),
                  child: Text(enrolled ? 'Finish lesson' : 'Enroll')),
        );
      }).toList());

  Widget _marketplace() => FutureBuilder<List<Map<String, dynamic>>>(
        future: widget.apiClient.fetchMarketplace(),
        builder: (context, snapshot) => _section(
            'Christian marketplace',
            (snapshot.data ?? [])
                .map((item) => ListTile(
                      title: Text('${item['title']}'),
                      subtitle: Text(
                          '${item['seller_name']} • ETB ${(item['price_cents'] as num) / 100}'),
                      trailing: FilledButton.tonal(
                          onPressed: _busy
                              ? null
                              : () => _run(() => widget.apiClient
                                  .orderMarketplaceItem(
                                      widget.session.token, '${item['id']}')),
                          child: Text(_text('Buy', 'ግዛ'))),
                    ))
                .toList()),
      );

  Widget _section(String title, List<Widget> children) => Card(
          child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...children,
        ]),
      ));

  String _interestLabel(String interest) => switch (interest) {
        'Bible Study' => _text('Bible Study', 'የመጽሐፍ ቅዱስ ጥናት'),
        'Evangelism' => _text('Evangelism', 'ወንጌል ስርጭት'),
        'Worship' => _text('Worship', 'አምልኮ'),
        'Courtship' => _text('Courtship', 'መጠናናት'),
        _ => interest,
      };
}

class _JourneyHero extends StatelessWidget {
  const _JourneyHero(
      {required this.name, required this.complete, required this.language});
  final String name;
  final bool complete;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AppTheme.forest, AppTheme.evergreen]),
            borderRadius: BorderRadius.circular(28)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.route_rounded, color: AppTheme.gold, size: 36),
          const SizedBox(height: 14),
          Text(
              language == AppLanguage.english
                  ? '$name, live your faith in one place.'
                  : '$name፣ እምነትዎን በአንድ ቦታ ይኑሩ።',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: Colors.white)),
          const SizedBox(height: 6),
          Text(
              complete
                  ? language == AppLanguage.english
                      ? 'Your church, growth, service and learning records are connected.'
                      : 'የቤተ ክርስቲያን፣ የእድገት፣ የአገልግሎት እና የትምህርት መረጃዎ ተገናኝቷል።'
                  : language == AppLanguage.english
                      ? 'Complete onboarding to connect every pillar.'
                      : 'ሁሉንም ክፍሎች ለማገናኘት መገለጫዎን ያጠናቅቁ።',
              style: const TextStyle(color: Colors.white70)),
        ]),
      );
}
