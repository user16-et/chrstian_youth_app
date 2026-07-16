part of '../module_pages.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({
    super.key,
    required this.language,
    required this.apiClient,
    required this.session,
  });

  final AppLanguage language;
  final ApiClient apiClient;
  final AuthResult? session;

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  Future<List<Map<String, dynamic>>>? _browseFuture;
  Future<List<Map<String, dynamic>>>? _savedFuture;
  Future<List<Map<String, dynamic>>>? _mineFuture;
  String _query = '';
  String _category = 'all';
  int _tab = 0;

  bool get _en => widget.language == AppLanguage.english;
  String _t(String en, String am) => _en ? en : am;
  String? get _token => widget.session?.token;

  static const List<(String, String, String, IconData)> _categories = [
    ('all', 'All', 'ሁሉም', Icons.grid_view_rounded),
    ('Electronics', 'Electronics', 'ኤሌክትሮኒክስ', Icons.devices_rounded),
    ('Phones', 'Phones', 'ስልኮች', Icons.smartphone_rounded),
    ('Vehicles', 'Vehicles', 'ተሽከርካሪ', Icons.directions_car_rounded),
    ('Furniture', 'Furniture', 'የቤት እቃ', Icons.chair_rounded),
    ('Fashion', 'Fashion', 'ልብስ', Icons.checkroom_rounded),
    ('Home', 'Home', 'ቤት', Icons.home_rounded),
    ('Books', 'Books', 'መጻሕፍት', Icons.menu_book_rounded),
    ('Property', 'Property', 'ንብረት', Icons.apartment_rounded),
    ('Services', 'Services', 'አገልግሎት', Icons.handyman_rounded),
    ('Other', 'Other', 'ሌላ', Icons.category_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _reloadBrowse();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _reloadBrowse() {
    _browseFuture = widget.apiClient.browseMarketplace(
        token: _token, q: _query, category: _category);
  }

  Future<void> _refreshBrowse() async {
    setState(_reloadBrowse);
    await _browseFuture;
  }

  Future<void> _refreshSaved() async {
    final t = _token;
    if (t == null || t.isEmpty) return;
    setState(() => _savedFuture = widget.apiClient.fetchSavedListings(t));
  }

  Future<void> _refreshMine() async {
    final t = _token;
    if (t == null || t.isEmpty) return;
    setState(() => _mineFuture = widget.apiClient.fetchMyListings(t));
  }

  void _onSearch(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      setState(() => _query = v.trim());
      _refreshBrowse();
    });
  }

  String _price(dynamic cents) {
    final n = (cents is num ? cents : 0) ~/ 100;
    final s = n.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return 'ETB $s';
  }

  Future<void> _openDetail(String id) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _ListingDetailPage(
        apiClient: widget.apiClient,
        session: widget.session,
        language: widget.language,
        listingId: id,
        priceFormatter: _price,
      ),
    ));
    _refreshBrowse();
    if (_tab == 1) _refreshSaved();
  }

  Future<void> _toggleSave(Map<String, dynamic> l) async {
    final t = _token;
    if (t == null || t.isEmpty) return;
    final id = '${l['id']}';
    final saved = l['saved'] == true;
    setState(() => l['saved'] = !saved);
    try {
      if (saved) {
        await widget.apiClient.unsaveListing(t, id);
      } else {
        await widget.apiClient.saveListing(t, id);
      }
    } catch (_) {
      if (mounted) setState(() => l['saved'] = saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 3,
      initialIndex: _tab,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_t('Marketplace', 'ገበያ')),
          bottom: TabBar(
            onTap: (i) {
              setState(() => _tab = i);
              if (i == 1) _refreshSaved();
              if (i == 2) _refreshMine();
            },
            tabs: [
              Tab(text: _t('Browse', 'ያስሱ')),
              Tab(text: _t('Saved', 'የተቀመጡ')),
              Tab(text: _t('Selling', 'የሚሸጡ')),
            ],
          ),
        ),
        floatingActionButton: (_token == null || _token!.isEmpty)
            ? null
            : FloatingActionButton.extended(
                onPressed: _createListing,
                icon: const Icon(Icons.add_rounded),
                label: Text(_t('Sell', 'ሽጥ')),
              ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: [_browseTab(colors), _savedTab(colors), _sellingTab(colors)],
        ),
      ),
    );
  }

  Widget _browseTab(ColorScheme colors) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearch,
          decoration: InputDecoration(
            hintText: _t('Search marketplace', 'ገበያ ፈልግ'),
            prefixIcon: const Icon(Icons.search_rounded),
            isDense: true,
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
      ),
      SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final c = _categories[i];
            final selected = _category == c.$1;
            return Center(
              child: ChoiceChip(
                avatar: Icon(c.$4, size: 16, color: selected ? colors.onPrimary : colors.primary),
                label: Text(_en ? c.$2 : c.$3),
                selected: selected,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onSelected: (_) {
                  setState(() => _category = c.$1);
                  _refreshBrowse();
                },
              ),
            );
          },
        ),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _refreshBrowse,
          child: _grid(_browseFuture, colors,
              empty: _t('Nothing here yet. Be the first to sell!', 'እስካሁን የለም። መጀመሪያ ሽጡ!')),
        ),
      ),
    ]);
  }

  Widget _savedTab(ColorScheme colors) {
    if (_token == null || _token!.isEmpty) {
      return Center(child: Text(_t('Sign in to save listings.', 'ለማስቀመጥ ይግቡ።')));
    }
    return RefreshIndicator(
      onRefresh: _refreshSaved,
      child: _grid(_savedFuture, colors, empty: _t('No saved listings yet.', 'የተቀመጠ የለም።')),
    );
  }

  Widget _grid(Future<List<Map<String, dynamic>>>? future, ColorScheme colors,
      {required String empty}) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <Map<String, dynamic>>[];
        if (snapshot.connectionState == ConnectionState.waiting && items.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (items.isEmpty) {
          return ListView(children: [
            const SizedBox(height: 120),
            Icon(Icons.storefront_rounded, size: 56, color: colors.outline),
            const SizedBox(height: 12),
            Center(child: Text(empty, style: TextStyle(color: colors.onSurfaceVariant))),
          ]);
        }
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            mainAxisExtent: 250,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) => _listingCard(items[i], colors),
        );
      },
    );
  }

  Widget _listingCard(Map<String, dynamic> l, ColorScheme colors) {
    final photo = '${l['imageUrl'] ?? ''}';
    final sold = l['sold'] == true;
    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: .35),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetail('${l['id']}'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              if (photo.isNotEmpty)
                Image.network(photo, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _photoFallback(colors))
              else
                _photoFallback(colors),
              if (sold)
                Container(
                  color: Colors.black45,
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(6)),
                    child: Text(_t('SOLD', 'ተሸጧል'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                ),
              if (_token != null && _token!.isNotEmpty)
                Positioned(
                  top: 6, right: 6,
                  child: InkWell(
                    onTap: () => _toggleSave(l),
                    child: CircleAvatar(
                      radius: 15,
                      backgroundColor: Colors.black38,
                      child: Icon(l['saved'] == true ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          size: 17, color: l['saved'] == true ? Colors.redAccent : Colors.white),
                    ),
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_price(l['priceCents']),
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: colors.primary)),
              const SizedBox(height: 2),
              Text('${l['title'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Row(children: [
                Icon(Icons.place_rounded, size: 12, color: colors.onSurface.withValues(alpha: .5)),
                const SizedBox(width: 2),
                Expanded(
                  child: Text('${l['location'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: .6))),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _photoFallback(ColorScheme colors) => Container(
      color: colors.surfaceContainerHighest,
      child: Icon(Icons.image_rounded, color: colors.outline, size: 40));

  Widget _sellingTab(ColorScheme colors) {
    if (_token == null || _token!.isEmpty) {
      return Center(child: Text(_t('Sign in to sell.', 'ለመሸጥ ይግቡ።')));
    }
    return RefreshIndicator(
      onRefresh: _refreshMine,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _mineFuture,
        builder: (context, snapshot) {
          final items = snapshot.data ?? const <Map<String, dynamic>>[];
          if (snapshot.connectionState == ConnectionState.waiting && items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Center(child: Text(_t('You have no listings. Tap Sell to post one.', 'ማስታወቂያ የለዎትም። ለመለጠፍ «ሽጥ» ይንኩ።'),
                      textAlign: TextAlign.center, style: TextStyle(color: colors.onSurfaceVariant))),
                )
              else
                for (final l in items) _myListingTile(l, colors),
            ],
          );
        },
      ),
    );
  }

  Widget _myListingTile(Map<String, dynamic> l, ColorScheme colors) {
    final photo = '${l['imageUrl'] ?? ''}';
    final sold = l['sold'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: colors.surfaceContainerHighest.withValues(alpha: .4), borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: photo.isNotEmpty
              ? Image.network(photo, width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _photoBox(colors))
              : _photoBox(colors),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${l['title'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(_price(l['priceCents']), style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
            if (sold) Text(_t('Sold', 'ተሸጧል'), style: TextStyle(fontSize: 12, color: colors.error, fontWeight: FontWeight.w600)),
          ]),
        ),
        PopupMenuButton<String>(
          onSelected: (v) => _manageListing(v, l),
          itemBuilder: (context) => [
            if (!sold) PopupMenuItem(value: 'sold', child: Text(_t('Mark as sold', 'ተሸጧል ማድረግ'))),
            PopupMenuItem(value: 'delete', child: Text(_t('Delete', 'ሰርዝ'))),
          ],
        ),
      ]),
    );
  }

  Widget _photoBox(ColorScheme colors) => Container(width: 56, height: 56, color: colors.surfaceContainerHighest, child: Icon(Icons.image_rounded, color: colors.outline));

  Future<void> _manageListing(String action, Map<String, dynamic> l) async {
    final t = _token;
    if (t == null || t.isEmpty) return;
    final id = '${l['id']}';
    try {
      if (action == 'sold') {
        await widget.apiClient.updateListing(t, id, {'sold': true});
      } else if (action == 'delete') {
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(_t('Delete listing?', 'ማስታወቂያ ይሰረዝ?')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: Text(_t('Cancel', 'ተወው'))),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(_t('Delete', 'ሰርዝ'))),
            ],
          ),
        );
        if (ok != true) return;
        await widget.apiClient.deleteListing(t, id);
      }
      await _refreshMine();
      _refreshBrowse();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.toString().replaceFirst('HttpException: ', ''))));
      }
    }
  }

  Future<void> _createListing() async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SellSheet(
        apiClient: widget.apiClient,
        token: token,
        language: widget.language,
        defaultPhone: widget.session?.user.phoneNumber ?? '',
        categories: _categories.where((c) => c.$1 != 'all').map((c) => c.$1).toList(),
      ),
    );
    if (created == true) {
      _refreshBrowse();
      _refreshMine();
    }
  }
}

// ---- Listing detail page ----
class _ListingDetailPage extends StatefulWidget {
  const _ListingDetailPage({
    required this.apiClient,
    required this.session,
    required this.language,
    required this.listingId,
    required this.priceFormatter,
  });

  final ApiClient apiClient;
  final AuthResult? session;
  final AppLanguage language;
  final String listingId;
  final String Function(dynamic) priceFormatter;

  @override
  State<_ListingDetailPage> createState() => _ListingDetailPageState();
}

class _ListingDetailPageState extends State<_ListingDetailPage> {
  Map<String, dynamic>? _listing;
  bool _loading = true;
  int _photo = 0;

  bool get _en => widget.language == AppLanguage.english;
  String _t(String en, String am) => _en ? en : am;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await widget.apiClient.fetchListingDetail(widget.listingId, token: widget.session?.token);
      if (mounted) setState(() { _listing = d; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleSave() async {
    final t = widget.session?.token;
    final l = _listing;
    if (t == null || t.isEmpty || l == null) return;
    final saved = l['saved'] == true;
    setState(() => l['saved'] = !saved);
    try {
      if (saved) {
        await widget.apiClient.unsaveListing(t, widget.listingId);
      } else {
        await widget.apiClient.saveListing(t, widget.listingId);
      }
    } catch (_) {
      if (mounted) setState(() => l['saved'] = saved);
    }
  }

  void _messageSeller() {
    final l = _listing;
    final t = widget.session?.token;
    if (l == null || t == null || t.isEmpty) return;
    final sellerId = '${l['sellerId'] ?? ''}';
    if (sellerId.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(left: 16, right: 16, bottom: MediaQuery.viewInsetsOf(context).bottom + 16),
        child: LiveChatPanel(
          apiClient: widget.apiClient,
          session: widget.session,
          language: widget.language,
          scopeType: 'direct',
          scopeId: sellerId,
          otherUserId: sellerId,
          title: '${l['sellerName'] ?? _t('Seller', 'ሻጭ')} · ${l['title'] ?? ''}',
          compact: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l = _listing;
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('Details', 'ዝርዝር')),
        actions: [
          if (l != null && widget.session?.token != null && (widget.session?.token ?? '').isNotEmpty)
            IconButton(
              onPressed: _toggleSave,
              icon: Icon(l['saved'] == true ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: l['saved'] == true ? Colors.redAccent : null),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : l == null
              ? Center(child: Text(_t('Listing not found.', 'ማስታወቂያ አልተገኘም።')))
              : _content(l, colors),
      bottomNavigationBar: (l == null || l['sold'] == true)
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _messageSeller,
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      label: Text(_t('Message seller', 'ለሻጭ መልእክት')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      final phone = '${l['phoneNumber'] ?? ''}';
                      if (phone.isNotEmpty) launchUrl(Uri.parse('tel:$phone'));
                    },
                    icon: const Icon(Icons.call_rounded),
                    label: Text(_t('Call', 'ደውል')),
                  ),
                ]),
              ),
            ),
    );
  }

  Widget _content(Map<String, dynamic> l, ColorScheme colors) {
    final images = ((l['images'] as List?) ?? const []).cast<String>();
    return ListView(children: [
      AspectRatio(
        aspectRatio: 1.1,
        child: Stack(children: [
          if (images.isEmpty)
            Container(color: colors.surfaceContainerHighest, child: Icon(Icons.image_rounded, size: 60, color: colors.outline))
          else
            PageView.builder(
              onPageChanged: (i) => setState(() => _photo = i),
              itemCount: images.length,
              itemBuilder: (context, i) => Image.network(images[i], fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: colors.surfaceContainerHighest, child: Icon(Icons.broken_image_rounded, color: colors.outline))),
            ),
          if (images.length > 1)
            Positioned(
              bottom: 10, left: 0, right: 0,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < images.length; i++)
                  Container(
                    width: 7, height: 7, margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: i == _photo ? Colors.white : Colors.white54),
                  ),
              ]),
            ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.priceFormatter(l['priceCents']),
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: colors.primary)),
          const SizedBox(height: 4),
          Text('${l['title'] ?? ''}', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _chip(Icons.place_rounded, '${l['location'] ?? ''}', colors),
            _chip(Icons.sell_rounded, _conditionLabel('${l['condition'] ?? ''}'), colors),
            _chip(Icons.category_rounded, '${l['category'] ?? ''}', colors),
          ]),
          const SizedBox(height: 16),
          if ('${l['description'] ?? ''}'.isNotEmpty) ...[
            Text(_t('Description', 'መግለጫ'), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('${l['description']}', style: TextStyle(color: colors.onSurface.withValues(alpha: .85), height: 1.4)),
            const SizedBox(height: 16),
          ],
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundImage: '${l['sellerPhoto'] ?? ''}'.isNotEmpty ? NetworkImage('${l['sellerPhoto']}') : null,
              child: '${l['sellerPhoto'] ?? ''}'.isEmpty ? const Icon(Icons.person_rounded) : null,
            ),
            title: Text('${l['sellerName'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(_t('Seller', 'ሻጭ')),
          ),
          if (l['sold'] == true)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: colors.errorContainer, borderRadius: BorderRadius.circular(12)),
              child: Text(_t('This item has been sold.', 'ይህ እቃ ተሽጧል።'),
                  textAlign: TextAlign.center, style: TextStyle(color: colors.onErrorContainer, fontWeight: FontWeight.w600)),
            ),
        ]),
      ),
    ]);
  }

  Widget _chip(IconData icon, String label, ColorScheme colors) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: colors.surfaceContainerHighest.withValues(alpha: .5), borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: colors.primary),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      );

  String _conditionLabel(String c) {
    switch (c) {
      case 'new':
        return _t('Brand new', 'አዲስ');
      case 'used_like_new':
        return _t('Like new', 'እንደ አዲስ');
      case 'used_good':
        return _t('Used - good', 'ያገለገለ - ጥሩ');
      case 'used_fair':
        return _t('Used - fair', 'ያገለገለ');
      default:
        return c.isEmpty ? _t('Used', 'ያገለገለ') : c;
    }
  }
}

// ---- Sell (create listing) sheet ----
class _SellSheet extends StatefulWidget {
  const _SellSheet({
    required this.apiClient,
    required this.token,
    required this.language,
    required this.defaultPhone,
    required this.categories,
  });

  final ApiClient apiClient;
  final String token;
  final AppLanguage language;
  final String defaultPhone;
  final List<String> categories;

  @override
  State<_SellSheet> createState() => _SellSheetState();
}

class _SellSheetState extends State<_SellSheet> {
  final _title = TextEditingController();
  final _price = TextEditingController();
  final _desc = TextEditingController();
  final _location = TextEditingController();
  late final TextEditingController _phone = TextEditingController(text: widget.defaultPhone);
  final List<String> _images = [];
  late String _category = widget.categories.first;
  String _condition = 'used_good';
  bool _saving = false;

  bool get _en => widget.language == AppLanguage.english;
  String _t(String en, String am) => _en ? en : am;

  @override
  void dispose() {
    _title.dispose();
    _price.dispose();
    _desc.dispose();
    _location.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    if (_images.length >= 8) return;
    final url = await pickAndUploadImage(context, apiClient: widget.apiClient, token: widget.token, usage: 'marketplace');
    if (url != null && mounted) setState(() => _images.add(url));
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty || _desc.text.trim().isEmpty || _phone.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('Add a title, description and phone.', 'ርዕስ፣ መግለጫ እና ስልክ ያክሉ።'))));
      return;
    }
    setState(() => _saving = true);
    try {
      final birr = double.tryParse(_price.text.trim().replaceAll(',', '')) ?? 0;
      await widget.apiClient.createListing(
        widget.token,
        title: _title.text.trim(),
        category: _category,
        priceCents: (birr * 100).round(),
        description: _desc.text.trim(),
        condition: _condition,
        location: _location.text.trim(),
        phoneNumber: _phone.text.trim(),
        images: _images,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('HttpException: ', ''))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 4, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(_t('Sell an item', 'እቃ ሽጥ'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          SizedBox(
            height: 84,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (var i = 0; i < _images.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(children: [
                    ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(_images[i], width: 84, height: 84, fit: BoxFit.cover)),
                    Positioned(top: 2, right: 2, child: InkWell(
                      onTap: () => setState(() => _images.removeAt(i)),
                      child: const CircleAvatar(radius: 11, backgroundColor: Colors.black54, child: Icon(Icons.close_rounded, size: 14, color: Colors.white)),
                    )),
                  ]),
                ),
              if (_images.length < 8)
                InkWell(
                  onTap: _addPhoto,
                  child: Container(
                    width: 84, height: 84,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: colors.outline), color: colors.surfaceContainerHighest),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.add_a_photo_rounded, color: colors.primary),
                      Text(_t('Photo', 'ፎቶ'), style: TextStyle(fontSize: 11, color: colors.primary)),
                    ]),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 12),
          TextField(controller: _title, textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: _t('Title', 'ርዕስ'), hintText: _t('e.g. iPhone 12 128GB', 'ለምሳሌ iPhone 12'))),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _fieldLabel(_t('Price (ETB)', 'ዋጋ (ብር)')),
              TextField(controller: _price, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(prefixText: 'ETB ')),
            ])),
            const SizedBox(width: 10),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _fieldLabel(_t('Category', 'ምድብ')),
              // Plain label above (not a floating label) so it never overlaps
              // the always-present selected category.
              DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                items: [for (final c in widget.categories) DropdownMenuItem(value: c, child: Text(c))],
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
            ])),
          ]),
          const SizedBox(height: 10),
          Text(_t('Condition', 'ሁኔታ'), style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: [
            for (final c in [('new', _t('New', 'አዲስ')), ('used_like_new', _t('Like new', 'እንደ አዲስ')), ('used_good', _t('Good', 'ጥሩ')), ('used_fair', _t('Fair', 'መካከለኛ'))])
              ChoiceChip(label: Text(c.$2), selected: _condition == c.$1, onSelected: (_) => setState(() => _condition = c.$1)),
          ]),
          const SizedBox(height: 10),
          TextField(controller: _location, decoration: InputDecoration(labelText: _t('Location', 'አካባቢ'), prefixIcon: const Icon(Icons.place_outlined))),
          const SizedBox(height: 10),
          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: _t('Phone', 'ስልክ'), prefixIcon: const Icon(Icons.call_outlined))),
          const SizedBox(height: 10),
          TextField(controller: _desc, minLines: 2, maxLines: 4, decoration: InputDecoration(labelText: _t('Description', 'መግለጫ'))),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: Text(_saving ? _t('Posting…', 'በመለጠፍ ላይ…') : _t('Post listing', 'ማስታወቂያ ለጥፍ')),
          ),
        ]),
      ),
    );
  }
}

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen(
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
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  late Future<List<PaymentPlanItem>> _plansFuture;
  late Future<List<PaymentHistoryItem>> _historyFuture;
  bool _busy = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _plansFuture = widget.apiClient.fetchPaymentPlans();
    final token = widget.session?.token;
    _historyFuture = token == null
        ? Future.value(const <PaymentHistoryItem>[])
        : widget.apiClient.fetchPaymentHistory(token);
  }

  Future<void> _refresh() async {
    final token = widget.session?.token;
    setState(() {
      _plansFuture = widget.apiClient.fetchPaymentPlans();
      _historyFuture = token == null
          ? Future.value(const <PaymentHistoryItem>[])
          : widget.apiClient.fetchPaymentHistory(token);
    });
    await Future.wait([_plansFuture, _historyFuture]);
  }

  Future<void> _support(String planId) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'login_required'));
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.apiClient.createPaymentRecord(token: token, planId: planId);
      await _refresh();
      await widget.onDataChanged();
      if (mounted) {
        setState(() =>
            _status = AppStrings.of(widget.language, 'payment_requested'));
      }
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
    final language = widget.language;
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.of(language, 'payments'))),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            _SectionHeader(
                title: AppStrings.of(language, 'payments'),
                subtitle: AppStrings.of(language, 'support_now')),
            const SizedBox(height: 16),
            _SectionCard(
              title: AppStrings.of(language, 'payment_plans'),
              children: [
                FutureBuilder<List<PaymentPlanItem>>(
                  future: _plansFuture,
                  builder: (context, snapshot) {
                    final plans = snapshot.data ?? const <PaymentPlanItem>[];
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        plans.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (plans.isEmpty) {
                      return Text(AppStrings.of(language, 'no_payment_plans'));
                    }
                    return Column(
                      children: [
                        for (final plan in plans)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ListTileRow(
                              icon: Icons.payments_rounded,
                              title: plan.name,
                              subtitle:
                                  '${plan.amount} ${plan.currency} • ${plan.description}',
                              onTap: _busy ? null : () => _support(plan.id),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                if (_status.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(_status, maxLines: 3, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: AppStrings.of(language, 'payment_history'),
              children: [
                FutureBuilder<List<PaymentHistoryItem>>(
                  future: _historyFuture,
                  builder: (context, snapshot) {
                    final history =
                        snapshot.data ?? const <PaymentHistoryItem>[];
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        history.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (history.isEmpty) {
                      return Text(
                          AppStrings.of(language, 'no_payment_history'));
                    }
                    return Column(
                      children: [
                        for (final item in history)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ListTileRow(
                              icon: Icons.receipt_long_rounded,
                              title: item.planName ?? item.purpose,
                              subtitle:
                                  '${item.amount} ${item.currency} • ${item.status} • ${item.userName}',
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
