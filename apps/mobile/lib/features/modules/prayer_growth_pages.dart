import 'package:flutter/material.dart';

import '../../data/api_client.dart';
import '../../data/app_models.dart';
import '../../data/date_format.dart';
import '../../i18n/app_i18n.dart';

/// Standalone screen kept for existing entry points; the body now lives in
/// [PrayerCirclesTab] so the merged Prayer hub can host it as a tab.
class PrayerChainsScreen extends StatelessWidget {
  const PrayerChainsScreen({super.key, required this.language, required this.apiClient, required this.session});

  final AppLanguage language;
  final ApiClient apiClient;
  final AuthResult? session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.of(language, 'prayer_chains'))),
      body: PrayerCirclesTab(language: language, apiClient: apiClient, session: session),
    );
  }
}

/// The prayer-circles (chains) directory as an embeddable body — no Scaffold —
/// so it can be shown both standalone and as a tab in the Prayer hub.
class PrayerCirclesTab extends StatefulWidget {
  const PrayerCirclesTab({super.key, required this.language, required this.apiClient, required this.session});

  final AppLanguage language;
  final ApiClient apiClient;
  final AuthResult? session;

  @override
  State<PrayerCirclesTab> createState() => _PrayerCirclesTabState();
}

class _PrayerCirclesTabState extends State<PrayerCirclesTab> {
  late Future<List<PrayerChainItem>> _chainsFuture;

  @override
  void initState() {
    super.initState();
    _chainsFuture = widget.apiClient.fetchPrayerChains(token: widget.session?.token);
  }

  Future<void> _refresh() async {
    final future = widget.apiClient.fetchPrayerChains(token: widget.session?.token);
    setState(() {
      _chainsFuture = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          _HeaderCard(
            title: AppStrings.of(language, 'prayer_chains'),
            subtitle: AppStrings.of(language, 'prayer_chain_directory'),
            accent: Colors.teal,
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<PrayerChainItem>>(
            future: _chainsFuture,
            builder: (context, snapshot) {
              final chains = snapshot.data ?? const <PrayerChainItem>[];
              if (snapshot.connectionState == ConnectionState.waiting && chains.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (chains.isEmpty) {
                return _EmptyCard(message: AppStrings.of(language, 'no_prayer_chains'));
              }
              return Column(
                children: [
                  for (final chain in chains)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ChainCard(
                        chain: chain,
                        language: language,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PrayerChainScreen(
                                language: language,
                                apiClient: widget.apiClient,
                                session: widget.session,
                                chain: chain,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class PrayerChainScreen extends StatefulWidget {
  const PrayerChainScreen({super.key, required this.language, required this.apiClient, required this.session, required this.chain});

  final AppLanguage language;
  final ApiClient apiClient;
  final AuthResult? session;
  final PrayerChainItem chain;

  @override
  State<PrayerChainScreen> createState() => _PrayerChainScreenState();
}

class _PrayerChainScreenState extends State<PrayerChainScreen> {
  final TextEditingController _bodyController = TextEditingController();
  late Future<_PrayerChainSnapshot> _snapshotFuture;
  bool _busy = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _snapshotFuture = _load();
  }

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  Future<_PrayerChainSnapshot> _load() async {
    final members = await widget.apiClient
        .fetchPrayerChainMembers(widget.chain.id, token: widget.session?.token);
    final posts = await widget.apiClient
        .fetchPrayerChainPosts(widget.chain.id, token: widget.session?.token);
    return _PrayerChainSnapshot(members: members, posts: posts);
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      _snapshotFuture = future;
    });
    await future;
  }

  Future<void> _join() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(() {
        _status = AppStrings.of(widget.language, 'login_required');
      });
      return;
    }
    setState(() {
      _busy = true;
      _status = AppStrings.of(widget.language, 'working');
    });
    try {
      await widget.apiClient.joinPrayerChain(token: token, chainId: widget.chain.id);
      await _refresh();
      if (!mounted) return;
      setState(() {
        _status = AppStrings.of(widget.language, 'success');
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _status = error.toString().replaceFirst('HttpException: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _post() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(() {
        _status = AppStrings.of(widget.language, 'login_required');
      });
      return;
    }
    if (_bodyController.text.trim().isEmpty) {
      setState(() {
        _status = AppStrings.of(widget.language, 'message_required');
      });
      return;
    }
    setState(() {
      _busy = true;
      _status = AppStrings.of(widget.language, 'working');
    });
    try {
      await widget.apiClient.createPrayerChainPost(token: token, chainId: widget.chain.id, body: _bodyController.text.trim());
      _bodyController.clear();
      await _refresh();
      if (!mounted) return;
      setState(() {
        _status = AppStrings.of(widget.language, 'prayer_chain_posted');
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _status = error.toString().replaceFirst('HttpException: ', '');
        });
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
    return Scaffold(
      appBar: AppBar(title: Text(widget.chain.name)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_PrayerChainSnapshot>(
          future: _snapshotFuture,
          builder: (context, snapshot) {
            final members = snapshot.data?.members ?? const <PrayerChainMemberItem>[];
            final posts = snapshot.data?.posts ?? const <PrayerChainPostItem>[];
            final joined = widget.session != null && members.any((member) => member.userId == widget.session!.user.id);
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                _HeaderCard(
                  title: widget.chain.name,
                  subtitle: widget.chain.description,
                  accent: Colors.teal,
                ),
                const SizedBox(height: 16),
                _StatRow(
                  items: [
                    _Stat(label: AppStrings.of(language, 'member_count'), value: members.length.toString()),
                    _Stat(label: AppStrings.of(language, 'chain_members'), value: members.length.toString()),
                    _Stat(label: AppStrings.of(language, 'chain_posts'), value: posts.length.toString()),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: AppStrings.of(language, 'members'),
                  children: [
                    if (members.isEmpty)
                      Text(AppStrings.of(language, 'no_prayer_chain_members'))
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [for (final member in members) Chip(label: Text(member.userName, maxLines: 1, overflow: TextOverflow.ellipsis))],
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: AppStrings.of(language, 'prayer_chain_posts'),
                  children: [
                    if (posts.isEmpty)
                      Text(AppStrings.of(language, 'no_prayer_chain_posts'))
                    else
                      Column(
                        children: [
                          for (final post in posts)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _PostCard(author: post.userName, body: post.body, time: relativeTime(post.createdAt)),
                            ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: AppStrings.of(language, 'join_chain'),
                  children: [
                    if (!joined)
                      FilledButton(
                        onPressed: _busy ? null : _join,
                        child: Text(AppStrings.of(language, 'join_chain')),
                      )
                    else ...[
                      Text(AppStrings.of(language, 'joined_chain')),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _bodyController,
                        maxLines: 3,
                        decoration: InputDecoration(labelText: AppStrings.of(language, 'new_chain_post')),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _busy ? null : _post,
                        child: Text(AppStrings.of(language, 'post_to_chain')),
                      ),
                    ],
                    if (_status.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(_status, maxLines: 3, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class GrowthScreen extends StatefulWidget {
  const GrowthScreen({super.key, required this.language, required this.apiClient, required this.session});

  final AppLanguage language;
  final ApiClient apiClient;
  final AuthResult? session;

  @override
  State<GrowthScreen> createState() => _GrowthScreenState();
}

class _GrowthScreenState extends State<GrowthScreen> {
  late Future<_GrowthSnapshot> _snapshotFuture;
  bool _busy = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _snapshotFuture = _load();
  }

  Future<_GrowthSnapshot> _load() async {
    final challenges = await widget.apiClient
        .fetchGrowthChallenges(token: widget.session?.token);
    GrowthSummaryItem? summary;
    if (widget.session != null) {
      summary = await widget.apiClient.fetchGrowthSummary(widget.session!.token);
    }
    return _GrowthSnapshot(challenges: challenges, summary: summary);
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      _snapshotFuture = future;
    });
    await future;
  }

  Future<void> _checkIn(String kind) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(() {
        _status = AppStrings.of(widget.language, 'login_required');
      });
      return;
    }
    setState(() {
      _busy = true;
      _status = AppStrings.of(widget.language, 'working');
    });
    try {
      await widget.apiClient.addGrowthCheckin(token: token, kind: kind);
      await _refresh();
      if (!mounted) return;
      setState(() {
        _status = AppStrings.of(widget.language, 'growth_checkin_success');
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _status = error.toString().replaceFirst('HttpException: ', '');
        });
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
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.of(language, 'growth_tracker'))),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_GrowthSnapshot>(
          future: _snapshotFuture,
          builder: (context, snapshot) {
            final challenges = snapshot.data?.challenges ?? const <GrowthChallengeItem>[];
            final summary = snapshot.data?.summary;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                _HeaderCard(
                  title: AppStrings.of(language, 'growth_tracker'),
                  subtitle: AppStrings.of(language, 'growth_tracker_subtitle'),
                  accent: Colors.deepOrange,
                ),
                const SizedBox(height: 16),
                if (summary != null) ...[
                  _SectionCard(
                    title: AppStrings.of(language, 'growth_summary'),
                    children: [
                      _StatRow(
                        items: [
                          _Stat(label: AppStrings.of(language, 'prayer_streak'), value: summary.prayerStreak.toString()),
                          _Stat(label: AppStrings.of(language, 'bible_streak'), value: summary.bibleStreak.toString()),
                          _Stat(label: AppStrings.of(language, 'service_streak'), value: summary.serviceStreak.toString()),
                          _Stat(label: AppStrings.of(language, 'total_checkins'), value: summary.totalCheckins.toString()),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('${AppStrings.of(language, 'level')}: ${summary.level}'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [for (final badge in summary.badges) Chip(label: Text(badge))],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                _SectionCard(
                  title: AppStrings.of(language, 'check_in'),
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton(onPressed: _busy ? null : () => _checkIn('prayer'), child: Text(AppStrings.of(language, 'prayer'))),
                        FilledButton(onPressed: _busy ? null : () => _checkIn('bible'), child: Text(AppStrings.of(language, 'bible'))),
                        FilledButton(onPressed: _busy ? null : () => _checkIn('service'), child: Text(AppStrings.of(language, 'service'))),
                      ],
                    ),
                    if (_status.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(_status, maxLines: 3, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: AppStrings.of(language, 'growth_challenges'),
                  children: [
                    if (challenges.isEmpty)
                      Text(AppStrings.of(language, 'no_growth_challenges'))
                    else
                      Column(
                        children: [
                          for (final challenge in challenges)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _ChallengeCard(challenge: challenge, language: language),
                            ),
                        ],
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PrayerChainSnapshot {
  const _PrayerChainSnapshot({required this.members, required this.posts});

  final List<PrayerChainMemberItem> members;
  final List<PrayerChainPostItem> posts;
}

class _GrowthSnapshot {
  const _GrowthSnapshot({required this.challenges, required this.summary});

  final List<GrowthChallengeItem> challenges;
  final GrowthSummaryItem? summary;
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.title, required this.subtitle, required this.accent});

  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [accent.withValues(alpha: 0.95), accent.withValues(alpha: 0.68)]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.local_fire_department_rounded, color: Colors.white.withValues(alpha: 0.95), size: 34),
          const SizedBox(height: 16),
          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
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

class _ChainCard extends StatelessWidget {
  const _ChainCard({required this.chain, required this.language, required this.onTap});

  final PrayerChainItem chain;
  final AppLanguage language;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(chain.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
                  ),
                  Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.outline),
                ],
              ),
              const SizedBox(height: 8),
              Text(chain.description, maxLines: 3, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('${chain.memberCount} ${AppStrings.of(language, 'members')}')),
                  Chip(label: Text(chain.creatorName)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.author, required this.body, required this.time});

  final String author;
  final String body;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(author, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(body, maxLines: 4, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Text(time, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.items});

  final List<_Stat> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [for (final item in items) _StatChip(stat: item)],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.stat});

  final _Stat stat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.55),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(stat.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
          Text(stat.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _Stat {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({required this.challenge, required this.language});

  final GrowthChallengeItem challenge;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)),
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(challenge.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
              ),
              Chip(label: Text('${challenge.targetDays} ${AppStrings.of(language, 'days')}')),
            ],
          ),
          const SizedBox(height: 8),
          Text(challenge.description, maxLines: 3, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Text(challenge.category, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
