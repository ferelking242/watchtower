import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/services/get_custom_list.dart';

// ── WatchReelFeedScreen ───────────────────────────────────────────────────────
// TikTok-style vertical reel feed for extensions that return type='reel' links.
// Each item's manga.link is a JSON string:
//   { type:'reel', listId:'trending', gifId:'abc', hd:'…', sd:'…',
//     poster:'…', hasAudio:true, duration:15 }
// The screen fetches pages lazily via getCustomListProvider, positions to the
// tapped gifId, and plays videos one-at-a-time with a single shared Player.

class WatchReelFeedScreen extends ConsumerStatefulWidget {
  final Source source;
  final String listId;
  final String? startGifId;

  const WatchReelFeedScreen({
    required this.source,
    required this.listId,
    this.startGifId,
    super.key,
  });

  @override
  ConsumerState<WatchReelFeedScreen> createState() =>
      _WatchReelFeedScreenState();
}

class _WatchReelFeedScreenState extends ConsumerState<WatchReelFeedScreen> {
  late final Player _player;
  late final VideoController _videoController;
  late final PageController _pageController;

  final List<MManga> _items = [];
  int _currentPage = 0;
  int _fetchPage = 1;
  bool _hasNext = true;
  bool _loadingMore = false;
  bool _isInitialLoad = true;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _videoController = VideoController(_player);
    _pageController = PageController();
    // True fullscreen — system nav hidden while in reel mode.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPage());
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _player.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadPage() async {
    if (_loadingMore || !_hasNext) return;
    setState(() => _loadingMore = true);
    try {
      final result = await ref.read(
        getCustomListProvider(
          source: widget.source,
          listId: widget.listId,
          page: _fetchPage,
        ).future,
      );
      if (result != null && mounted) {
        final wasEmpty = _items.isEmpty;
        setState(() {
          _items.addAll(result.list);
          _hasNext = result.hasNextPage;
          _fetchPage++;
          _isInitialLoad = false;
        });
        // Jump to the tapped item if a startGifId was passed.
        if (wasEmpty && widget.startGifId != null) {
          final idx = _items.indexWhere((m) {
            try {
              final d = jsonDecode(m.link ?? '') as Map<String, dynamic>;
              return d['gifId'] == widget.startGifId;
            } catch (_) {
              return false;
            }
          });
          if (idx > 0) {
            _currentPage = idx;
            _pageController.jumpToPage(idx);
          }
        }
        _playCurrentItem();
      }
    } catch (_) {
      if (mounted) setState(() => _isInitialLoad = false);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Map<String, dynamic>? _parseLink(MManga? m) {
    if (m == null || m.link == null) return null;
    try {
      return jsonDecode(m.link!) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  void _playCurrentItem() {
    if (_items.isEmpty || _currentPage >= _items.length) return;
    final data = _parseLink(_items[_currentPage]);
    if (data == null) return;
    final url = (data['hd'] as String?) ?? (data['sd'] as String?) ?? '';
    if (url.isEmpty) return;
    _player.open(Media(url));
    _player.setPlaylistMode(PlaylistMode.single);
    _player.play();
    if (mounted) setState(() => _paused = false);
  }

  void _onPageChanged(int idx) {
    setState(() => _currentPage = idx);
    _playCurrentItem();
    // Prefetch next pages when approaching end.
    if (idx >= _items.length - 4) _loadPage();
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    _paused ? _player.pause() : _player.play();
  }

  MManga? get _current =>
      (_items.isNotEmpty && _currentPage < _items.length)
          ? _items[_currentPage]
          : null;

  @override
  Widget build(BuildContext context) {
    final data = _parseLink(_current);
    final hasAudio = data?['hasAudio'] as bool? ?? false;
    final name = _current?.name ?? '';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _isInitialLoad
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white))
            : _items.isEmpty
                ? _buildEmpty()
                : Stack(
                    children: [
                      // ── Vertical paged video feed ───────────────────────────
                      PageView.builder(
                        controller: _pageController,
                        scrollDirection: Axis.vertical,
                        onPageChanged: _onPageChanged,
                        physics: const PageScrollPhysics(),
                        itemCount: _items.length + (_hasNext ? 1 : 0),
                        itemBuilder: (ctx, i) {
                          if (i >= _items.length) {
                            return const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white54),
                            );
                          }
                          return _ReelPage(
                            manga: _items[i],
                            videoController: _videoController,
                            isActive: i == _currentPage,
                            paused: _paused,
                            onTap: _togglePause,
                          );
                        },
                      ),

                      // ── Gradient overlays for readability ───────────────────
                      // Top gradient (back button area)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.center,
                                colors: [
                                  Colors.black.withValues(alpha: 0.55),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.35],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Bottom gradient (info area)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.center,
                                colors: [
                                  Colors.black.withValues(alpha: 0.75),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.45],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // ── Right action rail ───────────────────────────────────
                      Positioned(
                        right: 12,
                        bottom: 160,
                        child: _RightRail(hasAudio: hasAudio),
                      ),

                      // ── Bottom info ─────────────────────────────────────────
                      Positioned(
                        left: 16,
                        right: 80,
                        bottom: 104,
                        child: _BottomInfo(name: name),
                      ),

                      // ── Pause overlay ───────────────────────────────────────
                      if (_paused)
                        const IgnorePointer(
                          child: Center(
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white54,
                              size: 88,
                            ),
                          ),
                        ),

                      // ── Floating close pill (dock-style) ────────────────────
                      _CloseButton(onClose: () => Navigator.of(context).pop()),
                    ],
                  ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.video_library_outlined,
              color: Colors.white54, size: 56),
          const SizedBox(height: 12),
          const Text('Aucun contenu',
              style: TextStyle(color: Colors.white54, fontSize: 16)),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Retour',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ── Individual reel page ──────────────────────────────────────────────────────

class _ReelPage extends StatelessWidget {
  final MManga manga;
  final VideoController videoController;
  final bool isActive;
  final bool paused;
  final VoidCallback onTap;

  const _ReelPage({
    required this.manga,
    required this.videoController,
    required this.isActive,
    required this.paused,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imgUrl = manga.imageUrl ?? '';
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Poster image — shown while video loads / on inactive pages.
          if (imgUrl.isNotEmpty)
            Image.network(
              imgUrl,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (_, __, ___) =>
                  const ColoredBox(color: Colors.black),
            )
          else
            const ColoredBox(color: Colors.black),

          // Video player overlay (active page only).
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

// ── Right action rail ─────────────────────────────────────────────────────────

class _RightRail extends StatelessWidget {
  final bool hasAudio;
  const _RightRail({required this.hasAudio});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RailBtn(icon: Icons.favorite_rounded),
        const SizedBox(height: 20),
        _RailBtn(icon: Icons.visibility_rounded),
        const SizedBox(height: 20),
        _RailBtn(
          icon: hasAudio
              ? Icons.volume_up_rounded
              : Icons.volume_off_rounded,
        ),
        const SizedBox(height: 20),
        _RailBtn(icon: Icons.share_rounded),
      ],
    );
  }
}

class _RailBtn extends StatelessWidget {
  final IconData icon;
  const _RailBtn({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.38),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 0.8),
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }
}

// ── Bottom info overlay ───────────────────────────────────────────────────────

class _BottomInfo extends StatelessWidget {
  final String name;
  const _BottomInfo({required this.name});

  @override
  Widget build(BuildContext context) {
    if (name.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '@$name',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 15,
            shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ── Frosted glass close pill — identical glass/blur style as the app's dock ───

class _CloseButton extends StatelessWidget {
  final VoidCallback onClose;
  const _CloseButton({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    return Positioned(
      bottom: bottomSafe + 16,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: onClose,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                    width: 0.9,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 15),
                    SizedBox(width: 7),
                    Text(
                      'Fermer',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
