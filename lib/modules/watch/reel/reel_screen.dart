import 'dart:convert';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/services/get_custom_list.dart';

// ── ReelScreen ─────────────────────────────────────────────────────────────
// TikTok-style screen for extensions that return type='reel' links.
// Three tabs:  Explorer  |  Suivis  |  Pour toi
//
// Route params:  source, listId (initial Pour toi list), startGifId (optional)
//
// Niches / Creators data are fetched directly from the extension via
// getCustomListProvider using well-known listId keys:
//   for_you            → trending For You feed
//   creators_trending  → popular creators list
//   niche_<id>         → gifs for a specific niche

const _kTabExplorer = 0;
const _kTabSuivis   = 1;
const _kTabPourToi  = 2;

// ── Niche filter list (mirrors redgifs.js _NICHES) ────────────────────────────
const _kNiches = <({String id, String label})>[
  (id: 'for_you',              label: 'Pour toi'),
  (id: 'niche_just-boobs',     label: 'Just Boobs'),
  (id: 'niche_blowjobs',       label: 'Blowjobs'),
  (id: 'niche_thick-booty',    label: 'Thick Booty'),
  (id: 'niche_amateur-girls',  label: 'Amateur Girls'),
  (id: 'niche_real-couples',   label: 'Real Couples'),
  (id: 'niche_real-orgasms',   label: 'Real Orgasms'),
  (id: 'niche_curvy-chicks',   label: 'Curvy Chicks'),
  (id: 'niche_rough-sex',      label: 'Rough Sex'),
  (id: 'niche_legal-teens',    label: 'Legal Teens'),
  (id: 'niche_busty-asians',   label: 'Busty Asians'),
  (id: 'niche_goth-girls',     label: 'Goth Girls'),
  (id: 'niche_latinas',        label: 'Latinas'),
];

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

Map<String, dynamic>? _parseLink(String? link) {
  if (link == null) return null;
  try { return jsonDecode(link) as Map<String, dynamic>; }
  catch (_) { return null; }
}

String _fmtCount(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1).replaceAll('.', ',')} M';
  if (n >=    1000) return '${(n /    1000).toStringAsFixed(1).replaceAll('.', ',')} K';
  return n.toString();
}

// ─────────────────────────────────────────────────────────────────────────────
// ReelScreen — main shell
// ─────────────────────────────────────────────────────────────────────────────

class ReelScreen extends ConsumerStatefulWidget {
  final Source  source;
  final String  listId;      // initial list for Pour toi tab
  final String? startGifId;  // scroll-to target in Pour toi

  const ReelScreen({
    required this.source,
    required this.listId,
    this.startGifId,
    super.key,
  });

  @override
  ConsumerState<ReelScreen> createState() => _ReelScreenState();
}

class _ReelScreenState extends ConsumerState<ReelScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _pourToiActive = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this, initialIndex: _kTabPourToi);
    _applySystemUI(true);
    _tabs.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging) return;
    final isPourToi = _tabs.index == _kTabPourToi;
    if (isPourToi != _pourToiActive) {
      setState(() => _pourToiActive = isPourToi);
      _applySystemUI(isPourToi);
    }
  }

  void _applySystemUI(bool pourToi) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      pourToi ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );
  }

  @override
  void dispose() {
    _tabs
      ..removeListener(_onTabChanged)
      ..dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  // ── Derived colours ─────────────────────────────────────────────────────────
  Color get _barBg    => _pourToiActive ? Colors.black       : Colors.white;
  Color get _iconCol  => _pourToiActive ? Colors.white       : Colors.black87;
  Color get _tabSel   => _pourToiActive ? Colors.white       : Colors.black87;
  Color get _tabUnsel => _pourToiActive ? Colors.white54     : Colors.black45;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _pourToiActive ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        extendBodyBehindAppBar: _pourToiActive,
        backgroundColor: _pourToiActive ? Colors.black : Colors.white,
        appBar: _buildAppBar(context),
        body: TabBarView(
          controller: _tabs,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _ExplorerTab(source: widget.source),
            _SuivisTab(source: widget.source),
            _PourToiTab(
              source:     widget.source,
              listId:     widget.listId,
              startGifId: widget.startGifId,
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor:       _pourToiActive ? Colors.transparent : Colors.white,
      surfaceTintColor:      Colors.transparent,
      shadowColor:           Colors.transparent,
      elevation:             0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      leading: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: _LiveBadge(color: _iconCol),
        ),
      ),
      // ── Tab strip centré ──────────────────────────────────────────
      title: TabBar(
        controller: _tabs,
        isScrollable: true,
        tabAlignment: TabAlignment.center,
        dividerHeight: 0,
        indicatorWeight: 2.2,
        indicatorColor: _tabSel,
        indicatorPadding: const EdgeInsets.symmetric(horizontal: 4),
        labelColor: _tabSel,
        unselectedLabelColor: _tabUnsel,
        labelStyle: const TextStyle(
          fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.1),
        unselectedLabelStyle: const TextStyle(
          fontSize: 15, fontWeight: FontWeight.w500),
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        tabs: const [
          Tab(text: 'Explorer'),
          Tab(text: 'Suivis'),
          Tab(text: 'Pour toi'),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.search_rounded, color: _iconCol, size: 24),
          onPressed: () {},
          splashRadius: 20,
          padding: const EdgeInsets.only(right: 6),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LIVE badge (top-left icon, TikTok style)
// ─────────────────────────────────────────────────────────────────────────────

class _LiveBadge extends StatelessWidget {
  final Color color;
  const _LiveBadge({required this.color});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(Icons.tv_rounded, color: color, size: 26),
        Positioned(
          right: -4, top: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text(
              'LIVE',
              style: TextStyle(
                color: Colors.white, fontSize: 7,
                fontWeight: FontWeight.w900, letterSpacing: 0.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// EXPLORER TAB — 2-col masonry grid + niche filter chips
// ══════════════════════════════════════════════════════════════════════════════

class _ExplorerTab extends ConsumerStatefulWidget {
  final Source source;
  const _ExplorerTab({required this.source});
  @override
  ConsumerState<_ExplorerTab> createState() => _ExplorerTabState();
}

class _ExplorerTabState extends ConsumerState<_ExplorerTab>
    with AutomaticKeepAliveClientMixin {
  int  _selNiche = 0;
  final List<MManga> _items = [];
  int  _page    = 1;
  bool _hasNext = true;
  bool _loading = false;
  bool _init    = true;
  final _scroll = ScrollController();

  @override bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() { _scroll.dispose(); super.dispose(); }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 800) _load();
  }

  Future<void> _load() async {
    if (_loading || !_hasNext) return;
    setState(() => _loading = true);
    try {
      final res = await ref.read(getCustomListProvider(
        source: widget.source,
        listId: _kNiches[_selNiche].id,
        page: _page,
      ).future);
      if (res != null && mounted) {
        setState(() {
          _items.addAll(res.list);
          _hasNext = res.hasNextPage;
          _page++;
          _init = false;
        });
      } else if (mounted) setState(() => _init = false);
    } catch (_) {
      if (mounted) setState(() => _init = false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectNiche(int idx) {
    if (idx == _selNiche) return;
    setState(() {
      _selNiche = idx;
      _items.clear();
      _page    = 1;
      _hasNext = true;
      _init    = true;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Split into two columns for masonry
    final left  = <MManga>[];
    final right = <MManga>[];
    for (var i = 0; i < _items.length; i++) {
      (i.isEven ? left : right).add(_items[i]);
    }

    return CustomScrollView(
      controller: _scroll,
      slivers: [
        // ── Niche filter chips ───────────────────────────────────────
        SliverToBoxAdapter(
          child: SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: _kNiches.length,
              itemBuilder: (ctx, i) {
                final sel = i == _selNiche;
                return GestureDetector(
                  onTap: () => _selectNiche(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: sel ? Colors.black87 : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel ? Colors.black87 : Colors.grey.shade300,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _kNiches[i].label,
                      style: TextStyle(
                        color: sel ? Colors.white : Colors.black87,
                        fontSize: 13, fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        if (_init)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_items.isEmpty)
          const SliverFillRemaining(
            child: Center(child: Text('Aucun contenu',
                style: TextStyle(color: Colors.black45))),
          )
        else ...[
          // ── 2-column masonry ─────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            sliver: SliverToBoxAdapter(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _GridColumn(items: left)),
                  const SizedBox(width: 2),
                  Expanded(child: _GridColumn(items: right)),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
        ],
      ],
    );
  }
}

class _GridColumn extends StatelessWidget {
  final List<MManga> items;
  const _GridColumn({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.map((m) => _ExplorerCard(manga: m)).toList(),
    );
  }
}

// ── Explorer card ─────────────────────────────────────────────────────────────

class _ExplorerCard extends StatelessWidget {
  final MManga manga;
  const _ExplorerCard({required this.manga});

  @override
  Widget build(BuildContext context) {
    final d      = _parseLink(manga.link);
    final w      = (d?['width']  as num?)?.toDouble() ?? 9.0;
    final h      = (d?['height'] as num?)?.toDouble() ?? 16.0;
    final ratio  = w > 0 && h > 0 ? w / h : 9 / 16;
    final likes  = (d?['likes'] as num?)?.toInt() ?? 0;
    final title  = (d?['title']  as String?)?.trim()   ?? '';
    final author = (d?['creator'] as String?)?.trim()  ?? manga.name ?? '';
    final img    = manga.imageUrl ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: ColoredBox(
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Thumbnail — natural aspect ratio
              AspectRatio(
                aspectRatio: ratio,
                child: img.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: img,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            const ColoredBox(color: Color(0xFFEEEEEE)),
                        errorWidget: (_, __, ___) =>
                            const ColoredBox(color: Color(0xFFEEEEEE)),
                      )
                    : const ColoredBox(color: Color(0xFFEEEEEE)),
              ),
              // Text info
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 5, 6, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty)
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: Colors.black87, height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Author avatar
                        Container(
                          width: 16, height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey.shade300,
                          ),
                          child: const Icon(Icons.person,
                              size: 11, color: Colors.white),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(author.isNotEmpty ? '@$author' : 'Anonyme',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.black54),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (likes > 0) ...[
                          const Icon(Icons.favorite_border_rounded,
                              size: 12, color: Colors.black38),
                          const SizedBox(width: 2),
                          Text(_fmtCount(likes),
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.black45)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SUIVIS TAB — popular creators grid
// ══════════════════════════════════════════════════════════════════════════════

class _SuivisTab extends ConsumerStatefulWidget {
  final Source source;
  const _SuivisTab({required this.source});
  @override
  ConsumerState<_SuivisTab> createState() => _SuivisTabState();
}

class _SuivisTabState extends ConsumerState<_SuivisTab>
    with AutomaticKeepAliveClientMixin {
  final List<MManga> _items = [];
  int  _page    = 1;
  bool _hasNext = true;
  bool _loading = false;
  bool _init    = true;
  final _scroll = ScrollController();

  @override bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() { _scroll.dispose(); super.dispose(); }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) _load();
  }

  Future<void> _load() async {
    if (_loading || !_hasNext) return;
    setState(() => _loading = true);
    try {
      final res = await ref.read(getCustomListProvider(
        source: widget.source,
        listId: 'creators_trending',
        page: _page,
      ).future);
      if (res != null && mounted) {
        setState(() {
          _items.addAll(res.list);
          _hasNext = res.hasNextPage;
          _page++;
          _init = false;
        });
      } else if (mounted) setState(() => _init = false);
    } catch (_) {
      if (mounted) setState(() => _init = false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_init) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Text(
            'Créateurs populaires',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: Colors.grey.shade600),
          ),
        ),
        Expanded(
          child: GridView.builder(
            controller: _scroll,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.68,
            ),
            itemCount: _items.length + (_loading ? 2 : 0),
            itemBuilder: (ctx, i) {
              if (i >= _items.length) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                );
              }
              return _CreatorCard(manga: _items[i]);
            },
          ),
        ),
      ],
    );
  }
}

class _CreatorCard extends StatelessWidget {
  final MManga manga;
  const _CreatorCard({required this.manga});

  @override
  Widget build(BuildContext context) {
    final d         = _parseLink(manga.link);
    final followers = (d?['followers'] as num?)?.toInt() ?? 0;
    final gifs      = (d?['totalGifs'] as num?)?.toInt() ?? 0;
    final verified  = d?['verified'] as bool? ?? false;
    final img       = manga.imageUrl ?? '';
    final username  = manga.name ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          // Avatar
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade200,
              border: Border.all(color: Colors.grey.shade300, width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: img.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: img,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        const Icon(Icons.person, size: 36, color: Colors.grey),
                  )
                : const Icon(Icons.person, size: 36, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          // Username + verified
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text('@$username',
                    style: const TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w700, color: Colors.black87),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                if (verified) ...[
                  const SizedBox(width: 3),
                  const Icon(Icons.verified_rounded,
                      size: 14, color: Color(0xFF1DA1F2)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 3),
          if (followers > 0)
            Text('${_fmtCount(followers)} abonnés',
                style: const TextStyle(fontSize: 11, color: Colors.black45)),
          if (gifs > 0)
            Text('$gifs GIFs',
                style: const TextStyle(fontSize: 11, color: Colors.black38)),
          const SizedBox(height: 10),
          // Follow button
          GestureDetector(
            onTap: () {},
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black87, width: 1.2),
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              child: const Text('Suivre',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: Colors.black87)),
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// POUR TOI TAB — full-screen vertical reel player
// ══════════════════════════════════════════════════════════════════════════════

class _PourToiTab extends ConsumerStatefulWidget {
  final Source  source;
  final String  listId;
  final String? startGifId;
  const _PourToiTab({
    required this.source,
    required this.listId,
    this.startGifId,
  });
  @override
  ConsumerState<_PourToiTab> createState() => _PourToiTabState();
}

class _PourToiTabState extends ConsumerState<_PourToiTab>
    with AutomaticKeepAliveClientMixin {
  late final Player          _player;
  late final VideoController _videoCtrl;
  late final PageController  _pageCtrl;

  final List<MManga> _items = [];
  int  _page    = 1;
  int  _curPage = 0;
  bool _hasNext = true;
  bool _loading = false;
  bool _init    = true;
  bool _paused  = false;

  @override bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _player    = Player();
    _videoCtrl = VideoController(_player);
    _pageCtrl  = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPage());
  }

  @override
  void dispose() {
    _player.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPage() async {
    if (_loading || !_hasNext) return;
    setState(() => _loading = true);
    try {
      final res = await ref.read(getCustomListProvider(
        source: widget.source,
        listId: widget.listId,
        page: _page,
      ).future);
      if (res != null && mounted) {
        final wasEmpty = _items.isEmpty;
        setState(() {
          _items.addAll(res.list);
          _hasNext = res.hasNextPage;
          _page++;
          _init = false;
        });
        if (wasEmpty && widget.startGifId != null) {
          final idx = _items.indexWhere((m) =>
              _parseLink(m.link)?['gifId'] == widget.startGifId);
          if (idx > 0) {
            _curPage = idx;
            _pageCtrl.jumpToPage(idx);
          }
        }
        _playCurrentItem();
      } else if (mounted) setState(() => _init = false);
    } catch (_) {
      if (mounted) setState(() => _init = false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _playCurrentItem() {
    if (_items.isEmpty || _curPage >= _items.length) return;
    final d   = _parseLink(_items[_curPage].link);
    final url = (d?['hd'] as String?) ?? (d?['sd'] as String?) ?? '';
    if (url.isEmpty) return;
    _player
      ..open(Media(url))
      ..setPlaylistMode(PlaylistMode.single)
      ..play();
    if (mounted) setState(() => _paused = false);
  }

  void _onPageChanged(int idx) {
    setState(() => _curPage = idx);
    _playCurrentItem();
    if (idx >= _items.length - 4) _loadPage();
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    _paused ? _player.pause() : _player.play();
  }

  MManga? get _current =>
      _items.isNotEmpty && _curPage < _items.length ? _items[_curPage] : null;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_init) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator(
            color: Colors.white54, strokeWidth: 2)),
      );
    }
    if (_items.isEmpty) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: Text('Aucun contenu',
            style: TextStyle(color: Colors.white54, fontSize: 15))),
      );
    }

    final d        = _parseLink(_current?.link);
    final hasAudio = d?['hasAudio'] as bool? ?? false;
    final likes    = (d?['likes'] as num?)?.toInt() ?? 0;
    final views    = (d?['views'] as num?)?.toInt() ?? 0;
    final creator  = (d?['creator'] as String?) ?? _current?.name ?? '';
    final title    = (d?['title'] as String?)   ?? _current?.description ?? '';

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        children: [
          // ── Vertical paged feed ──────────────────────────────────────
          PageView.builder(
            controller: _pageCtrl,
            scrollDirection: Axis.vertical,
            onPageChanged: _onPageChanged,
            physics: const PageScrollPhysics(),
            itemCount: _items.length + (_hasNext ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (i >= _items.length) {
                return const Center(child: CircularProgressIndicator(
                    color: Colors.white38, strokeWidth: 2));
              }
              return _ReelPage(
                manga: _items[i],
                videoController: _videoCtrl,
                isActive: i == _curPage,
                paused: _paused,
                onTap: _togglePause,
              );
            },
          ),

          // ── Top gradient ─────────────────────────────────────────────
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: const Alignment(0, -0.4),
                    colors: [
                      Colors.black.withValues(alpha: 0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // ── Bottom gradient ───────────────────────────────────────────
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: const Alignment(0, 0.25),
                    colors: [
                      Colors.black.withValues(alpha: 0.72),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55],
                  ),
                ),
              ),
            ),
          ),

          // ── Right action rail ─────────────────────────────────────────
          Positioned(
            right: 10,
            bottom: 90,
            child: _TikTokRail(
              hasAudio: hasAudio,
              likes: likes,
              views: views,
            ),
          ),

          // ── Bottom info ───────────────────────────────────────────────
          Positioned(
            left: 14, right: 90, bottom: 20,
            child: _BottomInfo(creator: creator, title: title),
          ),

          // ── Pause icon ────────────────────────────────────────────────
          if (_paused)
            const IgnorePointer(
              child: Center(
                child: Icon(Icons.play_arrow_rounded,
                    color: Colors.white54, size: 80),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Single reel page (poster + video) ─────────────────────────────────────────

class _ReelPage extends StatelessWidget {
  final MManga          manga;
  final VideoController videoController;
  final bool            isActive;
  final bool            paused;
  final VoidCallback    onTap;
  const _ReelPage({
    required this.manga,
    required this.videoController,
    required this.isActive,
    required this.paused,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final img = manga.imageUrl ?? '';
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (img.isNotEmpty)
            CachedNetworkImage(
              imageUrl: img, fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const ColoredBox(color: Colors.black),
            )
          else
            const ColoredBox(color: Colors.black),
          if (isActive)
            Video(
              controller: videoController,
              fit: BoxFit.contain,
              controls: NoVideoControls,
            ),
        ],
      ),
    );
  }
}

// ── TikTok-style right rail ────────────────────────────────────────────────────

class _TikTokRail extends StatelessWidget {
  final bool hasAudio;
  final int  likes;
  final int  views;
  const _TikTokRail({
    required this.hasAudio,
    required this.likes,
    required this.views,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar + follow
        _AvatarFollow(),
        const SizedBox(height: 20),
        _RailAction(
          icon: Icons.favorite_rounded,
          count: likes > 0 ? _fmtCount(likes) : null,
        ),
        const SizedBox(height: 16),
        _RailAction(
          icon: Icons.chat_bubble_rounded,
          count: views > 0 ? _fmtCount(views) : null,
        ),
        const SizedBox(height: 16),
        _RailAction(icon: Icons.bookmark_rounded),
        const SizedBox(height: 16),
        _RailAction(icon: Icons.reply_rounded, flip: true),
      ],
    );
  }
}

class _AvatarFollow extends StatelessWidget {
  const _AvatarFollow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44, height: 52,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade800,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 24),
          ),
          Positioned(
            bottom: 0,
            child: Container(
              width: 20, height: 20,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFF3B5C),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _RailAction extends StatelessWidget {
  final IconData icon;
  final String?  count;
  final bool     flip;
  const _RailAction({required this.icon, this.count, this.flip = false});

  @override
  Widget build(BuildContext context) {
    final ico = Icon(icon, color: Colors.white, size: 30);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        flip
            ? Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
                child: ico,
              )
            : ico,
        if (count != null) ...[
          const SizedBox(height: 3),
          Text(count!,
            style: const TextStyle(
              color: Colors.white, fontSize: 12,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Bottom info overlay (creator + description) ────────────────────────────────

class _BottomInfo extends StatefulWidget {
  final String creator;
  final String title;
  const _BottomInfo({required this.creator, required this.title});
  @override
  State<_BottomInfo> createState() => _BottomInfoState();
}

class _BottomInfoState extends State<_BottomInfo> {
  bool _expanded = false;

  @override
  void didUpdateWidget(_BottomInfo old) {
    super.didUpdateWidget(old);
    if (old.creator != widget.creator) setState(() => _expanded = false);
  }

  @override
  Widget build(BuildContext context) {
    const shadow = [Shadow(color: Colors.black54, blurRadius: 8)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.creator.isNotEmpty)
          Text('@${widget.creator}',
            style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700,
              fontSize: 15, shadows: shadow,
            ),
          ),
        if (widget.title.isNotEmpty) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                  color: Colors.white, fontSize: 13,
                  height: 1.35, shadows: shadow,
                ),
                children: [
                  TextSpan(text: widget.title),
                  if (!_expanded && widget.title.length > 55)
                    const TextSpan(
                      text: '...plus',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                      ),
                    ),
                ],
              ),
              maxLines: _expanded ? 6 : 2,
              overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}
