import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/services/get_custom_list.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CreatorProfileScreen — TikTok-style creator profile
// ─────────────────────────────────────────────────────────────────────────────
// Route params (Map<String, dynamic>):
//   source, creator, creatorAvatar, verified, followers, bio

class CreatorProfileScreen extends ConsumerStatefulWidget {
  final Source source;
  final String creator;
  final String creatorAvatar;
  final bool   verified;
  final int    followers;
  final String bio;

  const CreatorProfileScreen({
    required this.source,
    required this.creator,
    required this.creatorAvatar,
    required this.verified,
    required this.followers,
    required this.bio,
    super.key,
  });

  @override
  ConsumerState<CreatorProfileScreen> createState() =>
      _CreatorProfileScreenState();
}

class _CreatorProfileScreenState
    extends ConsumerState<CreatorProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  final List<MManga> _videos    = [];
  int  _page    = 1;
  bool _hasNext = true;
  bool _loading = false;
  bool _init    = true;
  bool _following = false;

  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 1, vsync: this);
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabs.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 600)
      _load();
  }

  Future<void> _load() async {
    if (_loading || !_hasNext) return;
    setState(() => _loading = true);
    try {
      final listId = 'creator_${widget.creator}';
      final res = await ref.read(getCustomListProvider(
        source: widget.source,
        listId: listId,
        page: _page,
      ).future);
      if (res != null && mounted) {
        setState(() {
          _videos.addAll(res.list);
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

  void _share() {
    final url = '${widget.source.baseUrl ?? ''}/users/${widget.creator}';
    SharePlus.instance.share(ShareParams(text: url));
  }

  // ───────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: NestedScrollView(
        controller: _scroll,
        headerSliverBuilder: (ctx, _) => [
          _buildAppBar(ctx),
          _buildProfileHeader(ctx),
        ],
        body: _buildVideoGrid(),
      ),
    );
  }

  // ── App bar ─────────────────────────────────────────────────────────────────

  SliverAppBar _buildAppBar(BuildContext ctx) {
    return SliverAppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded,
            color: Colors.black87, size: 24),
        onPressed: () => Navigator.of(ctx).pop(),
      ),
      centerTitle: true,
      title: Text(
        widget.creator,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded,
              color: Colors.black87, size: 24),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.reply_rounded,
              color: Colors.black87, size: 24),
          onPressed: _share,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Profile header (avatar, stats, bio, buttons) ────────────────────────────

  SliverToBoxAdapter _buildProfileHeader(BuildContext ctx) {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          const SizedBox(height: 16),

          // ── Avatar ─────────────────────────────────────────────────
          Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade200, width: 1),
            ),
            child: ClipOval(
              child: widget.creatorAvatar.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: widget.creatorAvatar,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _DefaultAvatar(),
                    )
                  : _DefaultAvatar(),
            ),
          ),

          const SizedBox(height: 10),

          // ── Display name + verified ────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.creator,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              if (widget.verified) ...[
                const SizedBox(width: 5),
                const Icon(Icons.verified_rounded,
                    size: 18, color: Color(0xFF1DA1F2)),
              ],
            ],
          ),

          const SizedBox(height: 2),

          // ── @username ─────────────────────────────────────────────
          Text(
            '@${widget.creator}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w400,
            ),
          ),

          const SizedBox(height: 14),

          // ── Stats row ─────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatCell(value: '—', label: 'Suivis'),
              _Divider(),
              _StatCell(
                value: widget.followers > 0
                    ? _fmtCount(widget.followers)
                    : '—',
                label: 'Followers',
              ),
              _Divider(),
              _StatCell(value: '—', label: "J'aime"),
            ],
          ),

          const SizedBox(height: 16),

          // ── Action buttons ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // Suivre
                Expanded(
                  flex: 3,
                  child: GestureDetector(
                    onTap: () => setState(() => _following = !_following),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 40,
                      decoration: BoxDecoration(
                        color: _following
                            ? Colors.grey.shade200
                            : const Color(0xFFFF3B5C),
                        borderRadius: BorderRadius.circular(4),
                        border: _following
                            ? Border.all(color: Colors.grey.shade300)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _following ? 'Abonné(e)' : 'Suivre',
                        style: TextStyle(
                          color: _following
                              ? Colors.black87
                              : Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Message
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: Colors.grey.shade300, width: 1.2),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Message',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // More dropdown
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: Colors.grey.shade300, width: 1.2),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Colors.black87, size: 22),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Bio ───────────────────────────────────────────────────
          if (widget.bio.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                widget.bio,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
            ),

          const SizedBox(height: 16),

          // ── Divider ───────────────────────────────────────────────
          Divider(color: Colors.grey.shade200, height: 1),

          // ── Tab bar (single tab for now) ──────────────────────────
          TabBar(
            controller: _tabs,
            indicatorColor: Colors.black87,
            indicatorWeight: 2,
            labelColor: Colors.black87,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(icon: Icon(Icons.grid_on_rounded, size: 22)),
            ],
          ),

          Divider(color: Colors.grey.shade200, height: 1),
        ],
      ),
    );
  }

  // ── Video grid ──────────────────────────────────────────────────────────────

  Widget _buildVideoGrid() {
    if (_init) {
      return const Center(
          child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off_outlined,
                size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('Aucune vidéo disponible',
                style: TextStyle(
                    color: Colors.grey.shade400, fontSize: 14)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 1.5,
        crossAxisSpacing: 1.5,
        childAspectRatio: 9 / 16,
      ),
      itemCount: _videos.length + (_loading ? 3 : 0),
      itemBuilder: (ctx, i) {
        if (i >= _videos.length) {
          return Container(color: Colors.grey.shade100);
        }
        return _VideoThumb(
          manga:  _videos[i],
          source: widget.source,
          creator: widget.creator,
          allItems: _videos,
          index: i,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  const _StatCell({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1, height: 28,
      color: Colors.grey.shade300,
    );
  }
}

class _DefaultAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade200,
      child: Icon(Icons.person_rounded,
          color: Colors.grey.shade400, size: 48),
    );
  }
}

class _VideoThumb extends StatelessWidget {
  final MManga        manga;
  final Source        source;
  final String        creator;
  final List<MManga>  allItems;
  final int           index;

  const _VideoThumb({
    required this.manga,
    required this.source,
    required this.creator,
    required this.allItems,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final img = manga.imageUrl ?? '';

    return GestureDetector(
      onTap: () {
        context.pushNamed('reel', extra: {
          'source':     source,
          'listId':     'creator_$creator',
          'startGifId': _gifId(manga.link),
        });
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          img.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: img,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) =>
                      ColoredBox(color: Colors.grey.shade200),
                )
              : ColoredBox(color: Colors.grey.shade200),

          // Play icon overlay
          Positioned(
            left: 6, bottom: 6,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 14),
                const SizedBox(width: 2),
                Text(_viewCount(manga.link),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _gifId(String? link) {
    if (link == null) return '';
    try {
      final d = jsonDecode(link) as Map<String, dynamic>;
      return (d['gifId'] as String?) ?? '';
    } catch (_) {
      return '';
    }
  }

  String _viewCount(String? link) {
    if (link == null) return '';
    try {
      // Parse JSON link for views
      final idx = link.indexOf('"views"');
      if (idx < 0) return '';
      final sub = link.substring(idx + 8).trimLeft();
      final colon = sub.indexOf(':');
      if (colon < 0) return '';
      final rest = sub.substring(colon + 1).trim();
      final end = rest.indexOf(RegExp(r'[,}]'));
      final numStr = end >= 0 ? rest.substring(0, end).trim() : rest.trim();
      final n = int.tryParse(numStr);
      if (n == null || n == 0) return '';
      return _fmtCount(n);
    } catch (_) {
      return '';
    }
  }
}

// Helper imported from reel_screen via same lib (same package)
String _fmtCount(int n) {
  if (n >= 1000000)
    return '${(n / 1000000).toStringAsFixed(1).replaceAll('.', ',')} M';
  if (n >= 1000)
    return '${(n / 1000).toStringAsFixed(1).replaceAll('.', ',')} K';
  return n.toString();
}
