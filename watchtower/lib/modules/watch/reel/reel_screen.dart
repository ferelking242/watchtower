import 'dart:convert';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:share_plus/share_plus.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/watch/reel/creator_profile_screen.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/services/get_custom_list.dart';

// ── ReelScreen ─────────────────────────────────────────────────────────────
// TikTok-style screen for extensions that return type='reel' links.
// Three tabs:  Explorer  |  Suivis  |  Pour toi
//
// Route params:  source, listId (initial Pour toi list), startGifId (optional)

const _kTabExplorer = 0;
const _kTabSuivis   = 1;
const _kTabPourToi  = 2;

// ── Niche filter list (mirrors redgifs.js _NICHES) ────────────────────────────
const _kNiches = <({String id, String label})>[
  (id: 'for_you',              label: 'For you'),
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

List<String> _parseTags(Map<String, dynamic>? d) {
  final raw = d?['tags'];
  if (raw is List) return raw.map((e) => e.toString()).toList();
  return [];
}

// Saves/unsaves a reel to the Watchtower watch library.
// Returns the new favorite state.
bool _toggleFavoriteSync(MManga m, Source src) {
  final d     = _parseLink(m.link);
  final gifId = (d?['gifId'] as String?) ?? m.link ?? '';
  if (gifId.isEmpty || src.id == null) return false;

  final existing = isar.mangas
      .filter()
      .sourceIdEqualTo(src.id!)
      .and()
      .linkEqualTo(gifId)
      .findFirstSync();

  if (existing != null) {
    final next = !(existing.favorite ?? false);
    isar.writeTxnSync(() {
      existing.favorite = next;
      isar.mangas.putSync(existing);
    });
    return next;
  } else {
    isar.writeTxnSync(() {
      isar.mangas.putSync(Manga(
        source:      src.name ?? '',
        sourceId:    src.id,
        name:        (d?['creator'] as String?) ?? m.name ?? '',
        link:        gifId,
        imageUrl:    m.imageUrl ?? (d?['poster'] as String?) ?? '',
        description: (d?['title']   as String?) ?? m.description ?? '',
        author:      (d?['creator'] as String?) ?? '',
        artist:      '',
        genre:       _parseTags(d),
        lang:        src.lang ?? 'multi',
        status:      Status.unknown,
        favorite:    true,
        itemType:    src.itemType,
        dateAdded:   DateTime.now().millisecondsSinceEpoch,
      ));
    });
    return true;
  }
}

// Check whether a gifId is already favorited in isar.
bool _isFavoritedSync(String gifId, int? sourceId) {
  if (gifId.isEmpty || sourceId == null) return false;
  final existing = isar.mangas
      .filter()
      .sourceIdEqualTo(sourceId)
      .and()
      .linkEqualTo(gifId)
      .findFirstSync();
  return existing?.favorite ?? false;
}

// ─────────────────────────────────────────────────────────────────────────────
// ReelScreen — main shell
// ─────────────────────────────────────────────────────────────────────────────

class ReelScreen extends ConsumerStatefulWidget {
  final Source  source;
  final String  listId;
  final String? startGifId;

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
      pourToi
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.transparent,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.transparent,
            ),
    );
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPourToi = _pourToiActive;
    final bg        = isPourToi ? Colors.black : Colors.white;
    final iconCol   = isPourToi ? Colors.white : Colors.black87;
    final tabSel    = isPourToi ? Colors.white : Colors.black87;
    final tabUnsel  = isPourToi ? Colors.white54 : Colors.black38;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 78,
        // ── TV + LIVE badge ──────────────────────────────────────────
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: _TvLiveBadge(color: iconCol),
          ),
        ),
        // ── Tab strip centré ──────────────────────────────────────────
        title: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.center,
          dividerHeight: 0,
          indicatorWeight: 2.5,
          indicatorColor: tabSel,
          indicatorPadding: const EdgeInsets.symmetric(horizontal: 4),
          labelColor: tabSel,
          unselectedLabelColor: tabUnsel,
          labelStyle: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.1),
          unselectedLabelStyle: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w500),
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          tabs: [
            Tab(text: context.l10n.explore_tab),
            Tab(text: context.l10n.following_tab),
            Tab(text: context.l10n.for_you),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search_rounded, color: iconCol, size: 24),
            onPressed: () {},
            splashRadius: 20,
            padding: const EdgeInsets.only(right: 8),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ExplorerTab(source: widget.source),
          _SuivisTab(source: widget.source),
          _PourToiTab(
            source:      widget.source,
            listId:      widget.listId,
            startGifId:  widget.startGifId,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TV + LIVE badge — pixel-perfect TikTok header icon
// ─────────────────────────────────────────────────────────────────────────────

class _TvLiveBadge extends StatelessWidget {
  final Color color;
  const _TvLiveBadge({required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Monitor/TV outline icon
        Icon(Icons.tv_outlined, color: color, size: 22),
        const SizedBox(width: 4),
        // LIVE red pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFFF3B30),
            borderRadius: BorderRadius.circular(3),
          ),
          child: const Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EXPLORER TAB — masonry grid with type/niche filters
// ─────────────────────────────────────────────────────────────────────────────

enum _MediaType { all, gif, image }

class _ExplorerTab extends ConsumerStatefulWidget {
  final Source source;
  const _ExplorerTab({required this.source});
  @override
  ConsumerState<_ExplorerTab> createState() => _ExplorerTabState();
}

class _ExplorerTabState extends ConsumerState<_ExplorerTab>
    with AutomaticKeepAliveClientMixin {
  final List<MManga> _items = [];
  String     _listId   = _kNiches[0].id;
  int        _selNiche  = 0;
  _MediaType _mediaType = _MediaType.all;
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
        listId: _listId,
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
    if (idx == _selNiche && _mediaType == _MediaType.all) return;
    setState(() {
      _selNiche  = idx;
      _listId    = _kNiches[idx].id;
      _mediaType = _MediaType.all;
      _items.clear();
      _page    = 1;
      _hasNext = true;
      _init    = true;
    });
    _load();
  }

  void _selectType(_MediaType t) {
    if (t == _mediaType) return;
    setState(() {
      _mediaType = t;
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
    final left  = <MManga>[];
    final right = <MManga>[];
    for (var i = 0; i < _items.length; i++) {
      (i.isEven ? left : right).add(_items[i]);
    }

    return CustomScrollView(
      controller: _scroll,
      slivers: [
        // ── Top padding for AppBar ───────────────────────────────────
        SliverToBoxAdapter(child: SizedBox(
            height: MediaQuery.of(context).padding.top + kToolbarHeight + 8)),

        // ── Type filter (Tout / GIF / Image) ────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: [
                _TypePill(label: 'Tout',  active: _mediaType == _MediaType.all,
                    onTap: () => _selectType(_MediaType.all)),
                const SizedBox(width: 8),
                _TypePill(label: 'GIF',   active: _mediaType == _MediaType.gif,
                    onTap: () => _selectType(_MediaType.gif)),
                const SizedBox(width: 8),
                _TypePill(label: 'Image', active: _mediaType == _MediaType.image,
                    onTap: () => _selectType(_MediaType.image)),
              ],
            ),
          ),
        ),

        // ── Niche chips ──────────────────────────────────────────────
        if (_mediaType == _MediaType.all)
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
                          color: sel ? Colors.white : Colors.black54,
                          fontSize: 12, fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          )
        else
          const SliverToBoxAdapter(child: SizedBox(height: 8)),

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

class _TypePill extends StatelessWidget {
  final String       label;
  final bool         active;
  final VoidCallback onTap;
  const _TypePill({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: active ? Colors.black87 : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? Colors.black87 : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.black54,
            fontSize: 13, fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

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
    final title  = (d?['title']   as String?)?.trim()  ?? '';
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
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 5, 6, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty)
                      Text(title,
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
                        Container(
                          width: 16, height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey.shade300,
                          ),
                          child: const Icon(Icons.person,
                              size: 10, color: Colors.white),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(author,
                            style: const TextStyle(
                              fontSize: 11, color: Colors.black45,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (likes > 0) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.favorite_rounded,
                              size: 10, color: Colors.grey.shade400),
                          const SizedBox(width: 2),
                          Text(_fmtCount(likes),
                            style: TextStyle(
                              fontSize: 10, color: Colors.grey.shade500),
                          ),
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

// ─────────────────────────────────────────────────────────────────────────────
// SUIVIS TAB — creator cards grid
// ─────────────────────────────────────────────────────────────────────────────

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
        SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight + 4),
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
              return _CreatorCard(manga: _items[i], source: widget.source);
            },
          ),
        ),
      ],
    );
  }
}

class _CreatorCard extends StatelessWidget {
  final MManga manga;
  final Source source;
  const _CreatorCard({required this.manga, required this.source});

  void _openProfile(BuildContext ctx) {
    final d = _parseLink(manga.link);
    ctx.pushNamed('creatorProfile', extra: {
      'source':        source,
      'creator':       manga.name ?? '',
      'creatorAvatar': manga.imageUrl ?? '',
      'verified':      d?['verified'] as bool? ?? false,
      'followers':     (d?['followers'] as num?)?.toInt() ?? 0,
      'bio':           (d?['bio'] as String?) ?? '',
    });
  }

  @override
  Widget build(BuildContext context) {
    final d         = _parseLink(manga.link);
    final followers = (d?['followers'] as num?)?.toInt() ?? 0;
    final gifs      = (d?['totalGifs'] as num?)?.toInt() ?? 0;
    final verified  = d?['verified'] as bool? ?? false;
    final img       = manga.imageUrl ?? '';
    final username  = manga.name ?? '';
    final bannerUrl = (d?['bannerUrl'] as String?) ?? img;

    return GestureDetector(
      onTap: () => _openProfile(context),
      child: Container(
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
              child: AspectRatio(
                aspectRatio: 2.5,
                child: bannerUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: bannerUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            ColoredBox(color: Colors.grey.shade200),
                      )
                    : ColoredBox(color: Colors.grey.shade200),
              ),
            ),
            // Profile info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Column(
                  children: [
                    // Avatar
                    Transform.translate(
                      offset: const Offset(0, -20),
                      child: Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: ClipOval(
                          child: img.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: img,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) =>
                                      Container(color: Colors.grey.shade300,
                                        child: const Icon(Icons.person,
                                            color: Colors.white, size: 24)),
                                )
                              : Container(
                                  color: Colors.grey.shade300,
                                  child: const Icon(Icons.person,
                                      color: Colors.white, size: 24),
                                ),
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(0, -14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  username,
                                  style: const TextStyle(fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
                          const SizedBox(height: 3),
                          if (followers > 0)
                            Text('${_fmtCount(followers)} abonnés',
                                style: const TextStyle(fontSize: 11,
                                    color: Colors.black45)),
                          if (gifs > 0)
                            Text('$gifs GIFs',
                                style: const TextStyle(fontSize: 11,
                                    color: Colors.black38)),
                          const SizedBox(height: 10),
                          Container(
                            height: 30,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Colors.black87, width: 1.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            alignment: Alignment.center,
                            child: const Text('Suivre',
                              style: TextStyle(fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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

  final List<MManga> _items        = [];
  final Set<String>  _favoritedIds = {};
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
        // Pre-check favorites in isar
        final newFavIds = <String>{};
        for (final m in res.list) {
          final d = _parseLink(m.link);
          final gid = (d?['gifId'] as String?) ?? '';
          if (gid.isNotEmpty &&
              _isFavoritedSync(gid, widget.source.id)) {
            newFavIds.add(gid);
          }
        }
        setState(() {
          _items.addAll(res.list);
          _favoritedIds.addAll(newFavIds);
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

  void _onFavoriteTap() {
    if (_current == null) return;
    final d = _parseLink(_current!.link);
    final gifId = (d?['gifId'] as String?) ?? '';
    final next = _toggleFavoriteSync(_current!, widget.source);
    setState(() {
      if (next) {
        _favoritedIds.add(gifId);
      } else {
        _favoritedIds.remove(gifId);
      }
    });
  }

  void _onShareTap() {
    final d = _parseLink(_current?.link);
    final url = (d?['hd'] as String?) ??
        (d?['sd'] as String?) ??
        '${widget.source.baseUrl ?? ''}';
    SharePlus.instance.share(ShareParams(text: url));
  }

  void _openCreatorProfile(BuildContext ctx) {
    final d = _parseLink(_current?.link);
    final creator = (d?['creator'] as String?) ?? _current?.name ?? '';
    if (creator.isEmpty) return;
    ctx.pushNamed('creatorProfile', extra: {
      'source':        widget.source,
      'creator':       creator,
      'creatorAvatar': (d?['creatorAvatar'] as String?) ?? _current?.imageUrl ?? '',
      'verified':      d?['verified'] as bool? ?? false,
      'followers':     (d?['followers'] as num?)?.toInt() ?? 0,
      'bio':           (d?['bio'] as String?) ?? '',
    });
  }

  MManga? get _current =>
      _items.isNotEmpty && _curPage < _items.length ? _items[_curPage] : null;

  bool get _currentIsFavorited {
    final d = _parseLink(_current?.link);
    final gifId = (d?['gifId'] as String?) ?? '';
    return _favoritedIds.contains(gifId);
  }

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

    final d            = _parseLink(_current?.link);
    final hasAudio     = d?['hasAudio'] as bool? ?? false;
    final likes        = (d?['likes'] as num?)?.toInt() ?? 0;
    final views        = (d?['views'] as num?)?.toInt() ?? 0;
    final creator      = (d?['creator'] as String?) ?? _current?.name ?? '';
    final creatorAvatar= (d?['creatorAvatar'] as String?) ?? '';
    final verified     = d?['verified'] as bool? ?? false;
    final title        = (d?['title'] as String?) ?? _current?.description ?? '';
    final tags         = _parseTags(d);
    final supportsComments = widget.source.supportsComments ?? false;
    final isFav        = _currentIsFavorited;

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
                manga:           _items[i],
                videoController: _videoCtrl,
                isActive:        i == _curPage,
                paused:          _paused,
                onTap:           _togglePause,
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
            child: _ReelRail(
              creatorAvatar:    creatorAvatar,
              hasAudio:         hasAudio,
              likes:            likes,
              views:            views,
              isFavorited:      isFav,
              supportsComments: supportsComments,
              sourceIconUrl:    widget.source.iconUrl ?? '',
              sourceName:       widget.source.name ?? '',
              onAvatarTap:      () => _openCreatorProfile(context),
              onLike:           () {},          // like not supported yet — visual only
              onComment:        supportsComments ? () {} : null,
              onFavorite:       _onFavoriteTap,
              onShare:          _onShareTap,
            ),
          ),

          // ── Bottom left info ──────────────────────────────────────────
          Positioned(
            left: 14, right: 90, bottom: 20,
            child: _ReelBottomLeft(
              creator:    creator,
              verified:   verified,
              title:      title,
              tags:       tags,
              onCreatorTap: () => _openCreatorProfile(context),
              sourceIconUrl: widget.source.iconUrl ?? '',
              sourceName:    widget.source.name ?? '',
            ),
          ),

          // ── Pause overlay ─────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────────────────
// Single reel page — poster + video
// ─────────────────────────────────────────────────────────────────────────────

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
              imageUrl: img,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) =>
                  const ColoredBox(color: Colors.black),
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

// ─────────────────────────────────────────────────────────────────────────────
// Right action rail — TikTok pixel-perfect
// ─────────────────────────────────────────────────────────────────────────────

class _ReelRail extends StatelessWidget {
  final String   creatorAvatar;
  final bool     hasAudio;
  final int      likes;
  final int      views;
  final bool     isFavorited;
  final bool     supportsComments;
  final String   sourceIconUrl;
  final String   sourceName;
  final VoidCallback  onAvatarTap;
  final VoidCallback  onLike;
  final VoidCallback? onComment;
  final VoidCallback  onFavorite;
  final VoidCallback  onShare;

  const _ReelRail({
    required this.creatorAvatar,
    required this.hasAudio,
    required this.likes,
    required this.views,
    required this.isFavorited,
    required this.supportsComments,
    required this.sourceIconUrl,
    required this.sourceName,
    required this.onAvatarTap,
    required this.onLike,
    required this.onComment,
    required this.onFavorite,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Avatar + follow button ────────────────────────────────────
        GestureDetector(
          onTap: onAvatarTap,
          child: _AvatarFollow(avatarUrl: creatorAvatar),
        ),
        const SizedBox(height: 22),

        // ── J'aime ───────────────────────────────────────────────────
        GestureDetector(
          onTap: onLike,
          child: _RailBtn(
            icon: Icons.favorite_rounded,
            count: likes > 0 ? _fmtCount(likes) : null,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 18),

        // ── Commentaires ─────────────────────────────────────────────
        GestureDetector(
          onTap: onComment,
          child: _RailBtn(
            icon: Icons.chat_bubble_rounded,
            count: views > 0 ? _fmtCount(views) : null,
            color: supportsComments ? Colors.white : Colors.white30,
          ),
        ),
        const SizedBox(height: 18),

        // ── Favoris ──────────────────────────────────────────────────
        GestureDetector(
          onTap: onFavorite,
          child: _RailBtn(
            icon: isFavorited
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            color: isFavorited ? const Color(0xFFFFD700) : Colors.white,
          ),
        ),
        const SizedBox(height: 18),

        // ── Partager ─────────────────────────────────────────────────
        GestureDetector(
          onTap: onShare,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
            child: const _RailBtn(
              icon: Icons.reply_rounded,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 28),

        // ── Extension icon (replaces music disk) ─────────────────────
        _SourceDisk(iconUrl: sourceIconUrl, name: sourceName),
      ],
    );
  }
}

class _AvatarFollow extends StatelessWidget {
  final String avatarUrl;
  const _AvatarFollow({required this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48, height: 58,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.8),
            ),
            child: ClipOval(
              child: avatarUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: avatarUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          _DefaultAvatar(),
                    )
                  : _DefaultAvatar(),
            ),
          ),
          Positioned(
            bottom: 0,
            child: Container(
              width: 22, height: 22,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFF3B5C),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _DefaultAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade700,
      child: const Icon(Icons.person, color: Colors.white70, size: 26),
    );
  }
}

class _RailBtn extends StatelessWidget {
  final IconData icon;
  final String?  count;
  final Color    color;
  const _RailBtn({required this.icon, this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 32),
        if (count != null) ...[
          const SizedBox(height: 3),
          Text(count!,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              shadows: const [Shadow(color: Colors.black38, blurRadius: 4)],
            ),
          ),
        ],
      ],
    );
  }
}

class _SourceDisk extends StatelessWidget {
  final String iconUrl;
  final String name;
  const _SourceDisk({required this.iconUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey.shade900,
            border: Border.all(color: Colors.white24, width: 3),
          ),
          child: ClipOval(
            child: iconUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: iconUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const Icon(
                        Icons.extension, color: Colors.white54, size: 20),
                  )
                : const Icon(Icons.extension,
                    color: Colors.white54, size: 20),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom-left overlay — creator name, description, tags, translate
// ─────────────────────────────────────────────────────────────────────────────

class _ReelBottomLeft extends StatefulWidget {
  final String   creator;
  final bool     verified;
  final String   title;
  final List<String> tags;
  final VoidCallback onCreatorTap;
  final String   sourceIconUrl;
  final String   sourceName;

  const _ReelBottomLeft({
    required this.creator,
    required this.verified,
    required this.title,
    required this.tags,
    required this.onCreatorTap,
    required this.sourceIconUrl,
    required this.sourceName,
  });

  @override
  State<_ReelBottomLeft> createState() => _ReelBottomLeftState();
}

class _ReelBottomLeftState extends State<_ReelBottomLeft> {
  bool _expanded = false;

  @override
  void didUpdateWidget(_ReelBottomLeft old) {
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
        // ── Creator name + verified badge ─────────────────────────────
        if (widget.creator.isNotEmpty)
          GestureDetector(
            onTap: widget.onCreatorTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '@${widget.creator}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    shadows: shadow,
                  ),
                ),
                if (widget.verified) ...[
                  const SizedBox(width: 5),
                  const Icon(Icons.verified_rounded,
                      size: 16, color: Color(0xFF1DA1F2)),
                ],
              ],
            ),
          ),

        const SizedBox(height: 6),

        // ── Video title / description ─────────────────────────────────
        if (widget.title.isNotEmpty)
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.4,
                  shadows: shadow,
                ),
                children: [
                  TextSpan(text: _expanded
                      ? widget.title
                      : (widget.title.length > 80
                          ? widget.title.substring(0, 80)
                          : widget.title)),
                  if (!_expanded && widget.title.length > 80)
                    const TextSpan(
                      text: ' ...plus',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                      ),
                    ),
                ],
              ),
              maxLines: _expanded ? 6 : 2,
              overflow: _expanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
            ),
          ),

        // ── Tags row ──────────────────────────────────────────────────
        if (widget.tags.isNotEmpty) ...[
          const SizedBox(height: 5),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: widget.tags.map((t) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  '#$t',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    shadows: shadow,
                  ),
                ),
              )).toList(),
            ),
          ),
        ],

        const SizedBox(height: 8),

        // ── Voir la traduction (placeholder) ─────────────────────────
        GestureDetector(
          onTap: () {},   // TODO: translation provider
          child: const Text(
            'Voir la traduction',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              shadows: shadow,
            ),
          ),
        ),

        const SizedBox(height: 10),

        // ── Source row (replaces music row) ───────────────────────────
        _SourceRow(
          iconUrl: widget.sourceIconUrl,
          name:    widget.sourceName,
          creator: widget.creator,
        ),
      ],
    );
  }
}

class _SourceRow extends StatelessWidget {
  final String iconUrl;
  final String name;
  final String creator;
  const _SourceRow({
    required this.iconUrl,
    required this.name,
    required this.creator,
  });

  @override
  Widget build(BuildContext context) {
    const shadow = [Shadow(color: Colors.black54, blurRadius: 6)];
    final label = creator.isNotEmpty ? '$name · @$creator' : name;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Source icon in small circle
        Container(
          width: 22, height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black54,
            border: Border.all(color: Colors.white30, width: 1),
          ),
          child: ClipOval(
            child: iconUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: iconUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        const Icon(Icons.extension,
                            color: Colors.white54, size: 12),
                  )
                : const Icon(Icons.extension,
                    color: Colors.white54, size: 12),
          ),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              shadows: shadow,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
