part of '../module_pages.dart';

class ChurchScreen extends StatefulWidget {
  const ChurchScreen(
      {super.key,
      required this.language,
      required this.snapshotFuture,
      required this.apiClient,
      required this.session,
      required this.onDataChanged});

  final AppLanguage language;
  final ApiClient apiClient;
  final AuthResult? session;
  final Future<void> Function() onDataChanged;
  final Future<DashboardSnapshot> snapshotFuture;

  @override
  State<ChurchScreen> createState() => _ChurchScreenState();
}

class _ChurchScreenState extends State<ChurchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _city = 'All';
  bool _verifiedOnly = false;

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    return FutureBuilder<DashboardSnapshot>(
      future: widget.snapshotFuture,
      builder: (context, snapshot) {
        final churches = snapshot.data?.churches ?? const <ChurchItem>[];
        final cities = <String>{'All', ...churches.map((item) => item.city)};
        final filtered = churches.where((church) {
          final matchesQuery = _query.isEmpty ||
              church.name.toLowerCase().contains(_query.toLowerCase()) ||
              church.city.toLowerCase().contains(_query.toLowerCase());
          return matchesQuery &&
              (_city == 'All' || church.city == _city) &&
              (!_verifiedOnly || church.verified);
        }).toList();
        return _ListModuleScreen(
          title: AppStrings.of(language, 'church_network'),
          subtitle: 'Discover, join and serve in verified Gospel communities.',
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF0B5147), Color(0xFF167D68)]),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Row(children: [
                  const Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Find your spiritual home',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800)),
                        SizedBox(height: 5),
                        Text(
                            'Church pages, service times, sermons and ministries in one place.',
                            style: TextStyle(color: Colors.white70)),
                      ])),
                  const Chip(
                    avatar: Icon(Icons.verified_rounded),
                    label: Text('Official pages'),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              _SearchField(
                controller: _searchController,
                labelText: AppStrings.of(language, 'search'),
                hintText: AppStrings.of(language, 'church_search_hint'),
                onChanged: (value) => setState(() => _query = value.trim()),
                onClear: _query.isEmpty
                    ? null
                    : () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  FilterChip(
                    selected: _verifiedOnly,
                    avatar: const Icon(Icons.verified_rounded, size: 17),
                    label: const Text('Verified only'),
                    onSelected: (value) =>
                        setState(() => _verifiedOnly = value),
                  ),
                  const SizedBox(width: 8),
                  ...cities.map((city) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(city),
                          selected: _city == city,
                          onSelected: (_) => setState(() => _city = city),
                        ),
                      )),
                ]),
              ),
            ],
          ),
          items: snapshot.connectionState == ConnectionState.waiting &&
                  churches.isEmpty
              ? const [
                  Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ]
              : filtered.isEmpty
                  ? [
                      _EmptyState(
                        message: _query.isEmpty
                            ? AppStrings.of(language, 'no_churches_available')
                            : AppStrings.of(language, 'no_search_results'),
                      ),
                    ]
                  : filtered
                      .map(
                        (church) => Card(
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ChurchDetailScreen(
                                  language: language,
                                  apiClient: widget.apiClient,
                                  church: church,
                                  session: widget.session,
                                  onDataChanged: widget.onDataChanged,
                                ),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Row(children: [
                                Container(
                                  width: 58,
                                  height: 58,
                                  decoration: BoxDecoration(
                                    color: church.verified
                                        ? const Color(0xFFE2F4ED)
                                        : const Color(0xFFFFF1D5),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Icon(Icons.church_rounded,
                                      color: church.verified
                                          ? AppTheme.evergreen
                                          : const Color(0xFF9A6500)),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Row(children: [
                                        Expanded(
                                            child: Text(church.name,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w800))),
                                        if (church.verified)
                                          const Icon(Icons.verified_rounded,
                                              color: Color(0xFF16876F),
                                              size: 20),
                                      ]),
                                      const SizedBox(height: 4),
                                      Text(
                                          '${church.city} • ${church.churchType}'),
                                      if (church.description.isNotEmpty) ...[
                                        const SizedBox(height: 5),
                                        Text(church.description,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis),
                                      ],
                                      const SizedBox(height: 8),
                                      Text(
                                          '${church.memberCount} members  •  ${church.followerCount} followers  •  ${church.branchCount} branches',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.evergreen)),
                                    ])),
                                const Icon(Icons.arrow_forward_ios_rounded,
                                    size: 16),
                              ]),
                            ),
                          ),
                        ),
                      )
                      .toList(),
        );
      },
    );
  }
}
