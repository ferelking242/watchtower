import 'dart:async';

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:lottie/lottie.dart';
import 'package:share_plus/share_plus.dart';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/download.dart';
import 'package:watchtower/models/history.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/library/providers/library_filter_provider.dart';
import 'package:watchtower/modules/manga/detail/manga_detail_main.dart';
import 'package:watchtower/modules/manga/detail/providers/isar_providers.dart';
import 'package:watchtower/modules/manga/download/providers/download_provider.dart';
import 'package:watchtower/modules/more/settings/downloads/providers/downloads_state_provider.dart';
import 'package:watchtower/modules/watch/detail/download/watch_download_sheet.dart';
import 'package:watchtower/services/watch_comments_store.dart';
import 'package:watchtower/services/watch_local_recommendations.dart';
import 'package:watchtower/services/watch_resume_store.dart';
import 'package:watchtower/utils/arrow_popup_menu.dart';
import 'package:watchtower/utils/cached_network.dart';
import 'package:watchtower/utils/constant.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';
import 'package:watchtower/utils/extensions/string_extensions.dart';
import 'package:watchtower/modules/widgets/zoomable_image_viewer.dart';
import 'package:watchtower/utils/headers.dart';
import 'package:watchtower/utils/utils.dart';
import 'package:watchtower/utils/log/logger.dart';
import 'package:watchtower/modules/watch/detail/language_display.dart';
import 'package:watchtower/services/isolate_service.dart';
import 'package:watchtower/services/watch_resume_store.dart'
    show latestWatchResume;
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/anti_bot/cloudflare_bypass_panel.dart';
import 'package:watchtower/services/anti_bot/cloudflare_challenge_bus.dart';

import 'watch_player_stub.dart' if (dart.library.ffi) 'watch_player_io.dart';

// SVG icon — film (clapperboard)
const _kMovieSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none">
  <rect x="2" y="6" width="20" height="14" rx="2" stroke="currentColor" stroke-width="1.8"/>
  <path d="M2 10h20" stroke="currentColor" stroke-width="1.5"/>
  <path d="M7 6V2" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
  <path d="M12 6V2" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
  <path d="M17 6V2" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
  <path d="M2 7l5-3M9 7l5-3M16 7l5-3" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
</svg>''';

// SVG icon — série (écran TV)
const _kSerieSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none">
  <rect x="2" y="3" width="20" height="14" rx="2" stroke="currentColor" stroke-width="1.8"/>
  <path d="M8 21h8M12 17v4" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
  <circle cx="8" cy="10" r="2.5" stroke="currentColor" stroke-width="1.5"/>
  <path d="M13 8h4M13 12h3" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
</svg>''';

class WatchDetailView extends ConsumerStatefulWidget {
  final Manga manga;
  final bool sourceExist;
  final Function(bool) checkForUpdate;
  final bool isLoading;

  /// When opened from History, the episode to load and the position to
  /// resume from. When [resumeChapterId] is set the inline player loads that
  /// episode instead of the first one, and seeks to [resumePosition].
  final int? resumeChapterId;
  final Duration? resumePosition;

  const WatchDetailView({
    super.key,
    required this.manga,
    required this.sourceExist,
    required this.checkForUpdate,
    this.isLoading = false,
    this.resumeChapterId,
    this.resumePosition,
  });

  @override
  ConsumerState<WatchDetailView> createState() => _WatchDetailViewState();
}

class _WatchDetailViewState extends ConsumerState<WatchDetailView>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late final WatchInlinePlayer _player;

  String? _selectedSeason;
  String? _selectedLanguage;
  bool _isDescriptionExpanded = false;

  /// A Cloudflare refusal currently blocking this title. Non-null adds the
  /// "Cloudflare" tab to the tab bar and drives its inline bypass panel.
  CloudflareChallenge? _pendingChallenge;

  /// Index of the Cloudflare tab when it is present. The decorative tabs are
  /// fixed at 0/1, so the challenge tab is always last.
  int get _challengeTabIndex => 2;

  bool get _challengeTabVisible => _pendingChallenge != null;

  void _selectTab(int index) {
    if (!_tabController.indexIsChanging && _tabController.index == index) return;
    _tabController.animateTo(index);
  }

  void _dismissChallenge() {
    CloudflareChallengeBus.instance.clear();
    _rebuildTabController(length: 2, selectIndex: 0);
    setState(() {
      _pendingChallenge = null;
    });
  }

  /// Rebuilds [_tabController] with [length] pages, preserving the current tab
  /// unless [selectIndex] is given. Required whenever the Cloudflare tab is
  /// added or removed, because `TabController.length` is immutable.
  void _rebuildTabController({required int length, int? selectIndex}) {
    if (_tabController.length == length) return;
    final previous = _tabController;
    previous.removeListener(_onTabChanged);
    _tabController = TabController(
      length: length,
      vsync: this,
      initialIndex: selectIndex ?? previous.index.clamp(0, length - 1),
    );
    _tabController.addListener(_onTabChanged);
    // Dispose only after the rebuild has swapped the new controller into the
    // TabBar/TabBarView, so nothing animates against a disposed controller.
    WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
  }

  // In-player toast (bottom of the video surface). Kept here rather than in a
  // global overlay so it reads as part of the player, like MovieBox.
  String? _playerToastMsg;
  Timer? _playerToastTimer;
  final _headerTitleOpacity = ValueNotifier<double>(0.0);
  final _nestedScrollCtrl = ScrollController();

  // ── Theme helpers ────────────────────────────────────────────────────────────
  Color get _accent     => context.primaryColor;
  Color get _bg         => Theme.of(context).scaffoldBackgroundColor;
  Color get _card       => Theme.of(context).colorScheme.surfaceContainerHighest;
  Color get _surface    => Theme.of(context).colorScheme.surface;
  Color get _onSurface  => Theme.of(context).colorScheme.onSurface;
  Color get _grey       => _onSurface.withValues(alpha: 0.50);
  Color get _faint      => _onSurface.withValues(alpha: 0.30);
  Color get _textPrimary => _onSurface;
  bool  get _isLight    => context.isLight;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _player = WatchInlinePlayer();
    _player.onQualityChanged = () { if (mounted) setState(() {}); };
    _nestedScrollCtrl.addListener(_onScroll);
    // A Cloudflare refusal that reaches us while the user is on this screen
    // (typically the player resolving the stream) opens the bypass tab so the
    // challenge can be solved inline instead of leaving a silent failed load.
    CloudflareChallengeBus.instance.challenge.addListener(_onChallengeChanged);
    // A refusal raised before this screen mounted (e.g. the detail fetch itself)
    // is picked up here so the tab is present from the first frame.
    final pending = CloudflareChallengeBus.instance.challenge.value;
    if (pending != null && _challengeAppliesTo(pending)) {
      _rebuildTabController(length: _challengeTabIndex + 1);
      _pendingChallenge = pending;
    }
    // `Battre le challenge` reaches this page while it is on screen: the
    // challenge must show up here, over the video it blocks, instead of the
    // action pushing a different route (which looked like a dead button).
    CloudflareChallengeBus.instance.inlineHandler = _claimChallengeInline;
  }

  /// Selects the inline challenge surface for [challenge].
  ///
  /// Returns false when the refusal belongs to another extension, so the
  /// notification action falls back to its normal navigation.
  bool _claimChallengeInline(CloudflareChallenge challenge) {
    if (!mounted || !_challengeAppliesTo(challenge)) return false;
    _rebuildTabController(length: _challengeTabIndex + 1);
    setState(() {
      _pendingChallenge = challenge;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _challengeTabVisible) _selectTab(_challengeTabIndex);
    });
    return true;
  }

  /// True when [challenge] concerns the extension behind this title. A refusal
  /// with no source id is shown anyway: it is the only signal we have.
  bool _challengeAppliesTo(CloudflareChallenge challenge) {
    if (challenge.sourceId == null || widget.manga.sourceId == null) return true;
    return challenge.sourceId == widget.manga.sourceId;
  }

  void _onChallengeChanged() {
    final challenge = CloudflareChallengeBus.instance.challenge.value;
    if (!mounted || challenge == null || !_challengeAppliesTo(challenge)) return;
    // Grow the controller so the TabBar/TabBarView can host the extra page.
    _rebuildTabController(length: _challengeTabIndex + 1);
    setState(() {
      _pendingChallenge = challenge;
    });
    // Select the challenge tab only after the rebuild that added it, so the
    // TabBarView already has the third page when we move to index 2.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _challengeTabVisible) _selectTab(_challengeTabIndex);
    });
  }

  /// Les onglets décoratifs se chargent désormais en parallèle de la vidéo
  /// (gating retiré) ; le listener ne fait que tracer le changement d'onglet.
  void _onTabChanged() {
    if (!mounted) return;
    if (_tabController.index == 0 && !_recommendationsRequested) {
      _recommendationsRequested = true;
    } else if (_tabController.index == 1 && !_commentsRequested) {
      _commentsRequested = true;
    }
  }

  void _onScroll() {
    if (!_nestedScrollCtrl.hasClients) return;
    final pixels = _nestedScrollCtrl.position.pixels;
    _headerTitleOpacity.value = (pixels / 80.0).clamp(0.0, 1.0);
  }

  // Track last orientation so we only call SystemChrome when it changes
  bool _lastWasLandscape = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    if (isLandscape != _lastWasLandscape) {
      _lastWasLandscape = isLandscape;
      if (isLandscape) {
        // Hide system UI so there are no black bars from the nav bar or
        // status bar eating into the fullscreen video area.
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: SystemUiOverlay.values,
        );
      }
    }
  }

  @override
  void dispose() {
    // Restore system UI when leaving the page
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    _playerToastTimer?.cancel();
    CloudflareChallengeBus.instance.challenge
        .removeListener(_onChallengeChanged);
    // Only drop the handler if it is still ours: a newer detail page may have
    // replaced it before this one is disposed (push/pop ordering is not
    // guaranteed to be LIFO when the action opens a route on top).
    if (CloudflareChallengeBus.instance.inlineHandler == _claimChallengeInline) {
      CloudflareChallengeBus.instance.inlineHandler = null;
    }
    _nestedScrollCtrl.removeListener(_onScroll);
    _nestedScrollCtrl.dispose();
    _headerTitleOpacity.dispose();
    _tabController.dispose();
    _player.dispose();
    super.dispose();
  }

  // ─── VIDEO TRIGGER ──────────────────────────────────────────────────────────

  void _showPlayerToast(String message) {
    _playerToastTimer?.cancel();
    setState(() => _playerToastMsg = message);
    _playerToastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _playerToastMsg = null);
    });
  }

  static String _formatPlayerTime(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  /// Reloads the currently loaded episode (retry button after a failed load).
  void _retryLoadedEpisode(List<Chapter> chapters) {
    if (chapters.isEmpty) return;
    final target = chapters.firstWhere(
      (c) => c.id == _player.loadedChapterId,
      orElse: () => chapters.first,
    );
    _loadEpisodeInBanner(target);
  }

  void _maybeStartVideo(List<Chapter> chapters) {
    // On web the inline stub is replaced by AnimePlayerView — no auto-play.
    if (kIsWeb) return;
    if (chapters.isEmpty) return;
    _player.title = widget.manga.name ?? '';
    // Only auto-load the very first time (loadedChapterId == null).
    // Never override a chapter the user has explicitly chosen.
    if (_player.loadedChapterId != null) return;

    // `chapters` arrives newest-first (the Isar stream is reversed for the
    // recommendations feed), so `chapters.first` is the *last* episode. The
    // default episode must be the first one in playback order.
    final ordered = _sortedEpisodes(chapters);
    final firstEpisode = ordered.isNotEmpty ? ordered.first : chapters.first;

    // Opened from History → resume the exact episode at the saved position.
    if (widget.resumeChapterId != null) {
      final target = chapters.firstWhere(
        (c) => c.id == widget.resumeChapterId,
        orElse: () => firstEpisode,
      );
      _player.loadedChapterId = target.id;
      _player.startPosition = widget.resumePosition;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _player.load(ref: ref, chapter: target);
        if (mounted) setState(() {});
      });
      return;
    }

    // Opened from the Library (no explicit episode): resume the last episode
    // the user actually watched, at the saved position, instead of starting
    // over at episode 1. The resume store is per (title, chapter); pick the
    // most recently written record that is not finished.
    final title = widget.manga.name ?? '';
    if (title.isNotEmpty) {
      _player.loadedChapterId = firstEpisode.id; // optimistic; corrected below
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final latest = await latestWatchResume(title);
        Chapter target = firstEpisode;
        Duration? resumeAt;
        if (latest != null) {
          final match = chapters.where((c) => c.id == latest.chapterId).firstOrNull;
          if (match != null) {
            target = match;
            resumeAt = Duration(milliseconds: latest.ms);
          }
        }
        if (!mounted) return;
        _player.loadedChapterId = target.id;
        _player.startPosition = resumeAt;
        setState(() {});
        await _player.load(ref: ref, chapter: target);
        if (mounted) setState(() {});
      });
      return;
    }

    _player.loadedChapterId = firstEpisode.id;
    AppLogger.log(
      '[PLAYER] auto-load scheduled chapterId=${firstEpisode.id}'
      '  ← post-frame callback, runs after the current build',
      logLevel: LogLevel.debug,
      tag: LogTag.watch,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _player.load(ref: ref, chapter: firstEpisode);
      if (mounted) setState(() {});
    });
  }

  void _loadEpisodeInBanner(Chapter chapter) {
    // On web, open the real full-screen player (AnimePlayerView) instead
    // of the HTML5 inline stub.  AnimePlayerView reads chapter.url directly
    // from Isar — no extension call, no manga link needed.
    if (kIsWeb) {
      context.push('/animePlayerView', extra: chapter.id!);
      return;
    }
    _player.title = widget.manga.name ?? '';
    _player.reset();
    _player.loadedChapterId = chapter.id;
    // Drop the previous episode's start position immediately so it cannot leak
    // into this one; the post-frame callback fills in the resume target.
    _player.startPosition = null;
    if (mounted) setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Resume the episode where the user left it. Moving from a finished
      // episode to the next one (or picking any episode in the list) must land
      // on the saved timestamp, not at 00:00 — the user's "ep 2 at 30%".
      final chapterId = chapter.id;
      if (chapterId != null) {
        final resume = await readWatchResume(
          widget.manga.name ?? '',
          chapterId,
        );
        if (resume != null && resume.ms > 0 && !resume.completed) {
          _player.startPosition = Duration(milliseconds: resume.ms);
        }
      }
      if (!mounted) return;
      await _player.load(ref: ref, chapter: chapter);
      if (mounted) setState(() {});
    });
  }

  /// Jumps to the *next library entry* of the same medium — the following
  /// downloaded/added title — and resumes it where the user left off.
  ///
  /// Used when the current title has no further episode to play (the "next
  /// episode" button would otherwise be a dead end), and directly by the
  /// long-press on that button.
  Future<void> _openNextLibraryEntry() async {
    final currentId = widget.manga.id;
    final entries = isar.mangas
        .where()
        .findAllSync()
        .where(
          (m) =>
              m.favorite == true &&
              m.itemType == widget.manga.itemType &&
              m.id != null,
        )
        .toList()
      // Newest first, matching how a download-driven library reads.
      ..sort((a, b) => (b.dateAdded ?? 0).compareTo(a.dateAdded ?? 0));
    final idx = entries.indexWhere((m) => m.id == currentId);
    if (idx < 0 || idx >= entries.length - 1) {
      if (mounted) botToast(context.l10n.media_no_episode);
      return;
    }
    final next = entries[idx + 1];

    // Resume the next entry on the episode the user last watched there.
    int? resumeChapterId;
    Duration? resumePosition;
    final history = isar.historys
        .where()
        .mangaIdEqualTo(next.id!)
        .findAllSync()
      ..sort((a, b) => (b.updatedAt ?? 0).compareTo(a.updatedAt ?? 0));
    if (history.isNotEmpty) {
      final chapterId = history.first.chapterId;
      if (chapterId != null) {
        final resume = await readWatchResume(next.name ?? '', chapterId);
        if (resume != null && resume.ms > 0 && !resume.completed) {
          resumeChapterId = chapterId;
          resumePosition = Duration(milliseconds: resume.ms);
        }
      }
    }
    if (!mounted) return;
    context.push(
      '/manga-reader/detail',
      extra: MangaDetailArgs(
        next.id!,
        resumeChapterId: resumeChapterId,
        resumePosition: resumePosition,
      ),
    );
  }

  // ─── ACTIONS ────────────────────────────────────────────────────────────────

  void _toggleFavorite() {
    final manga = widget.manga;
    isar.writeTxnSync(() {
      manga.favorite = !(manga.favorite ?? false);
      if (manga.favorite!) manga.dateAdded = DateTime.now().millisecondsSinceEpoch;
      isar.mangas.putSync(manga);
    });
    setState(() {});
  }

  void _share(BuildContext ctx) {
    final source = getSource(widget.manga.lang!, widget.manga.source!, widget.manga.sourceId);
    if (source == null) return;
    final url = '${source.baseUrl}${widget.manga.link!.getUrlWithoutDomain}';
    SharePlus.instance.share(ShareParams(text: url));
  }

  Future<void> _downloadAll(List<Chapter> chapters) async {
    final l10n = context.l10n;
    try {
      for (final ch in chapters) {
        await ref.read(addDownloadToQueueProvider(chapter: ch).future);
        final id = ch.id;
        if (id != null) {
          ref.read(downloadQueueStateProvider.notifier).setPaused(id, false);
        }
      }
      botToast(l10n.media_all_episodes_queued);
    } catch (e) {
      botToast(l10n.media_start_failed(friendlyErrorMessage(e)));
    } finally {
      ref.read(processDownloadsProvider());
    }
  }

  // ─── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final chapters = ref
        .watch(getChaptersStreamProvider(mangaId: widget.manga.id!))
        .when(
          data: (list) => list.reversed.toList(),
          // Do NOT fall back to `widget.manga.chapters`: that lazy `IsarLinks`
          // backlink runs a synchronous Isar query on the UI isolate on the
          // first frame the route builds. The stream above fires immediately.
          loading: () => const <Chapter>[],
          error: (_, _) => <Chapter>[],
        );

    // ── Update episode navigation callbacks on every build ────────────────────
    final sorted = _sortedEpisodes(chapters);

    // Auto-load episode 1 (first of the first season) on first open — never the
    // last episode. The stream yields newest-first, so `chapters.first` is the
    // *latest* episode; the resume/auto-load logic must use the ascending order.
    _maybeStartVideo(sorted);

    final curIdx  = sorted.indexWhere((c) => c.id == _player.loadedChapterId);
    _player.onPrevEpisode = (curIdx > 0)
        ? () => _loadEpisodeInBanner(sorted[curIdx - 1])
        : null;
    // Only the episodes actually *downloaded* are playable when the user keeps
    // a partial library (e.g. 5 of Naruto's 250 episodes). "Next" must walk
    // those, never attempt a chapter whose video is not on disk. The sorted
    // list is ascending (ep 1 first), so the next playable episode is the first
    // downloaded index after the cursor; when there is none the button falls
    // back to the next library entry instead of a dead end.
    final downloaded = ref.watch(downloadedChapterIdsProvider);
    final playableIdx = _playableEpisodeIndices(sorted, downloaded);
    _player.onNextEpisode = _nextPlayableEpisode(sorted, curIdx, playableIdx);
    // Long-press → next library entry. Always available: the whole point is to
    // leave this title, even when it still has episodes left.
    _player.onNextEntry = _openNextLibraryEntry;
    _player.chapters     = sorted;
    _player.onEpisodeTap = _loadEpisodeInBanner;

    // In-player feedback: a failed load shows a toast + retry overlay; a
    // successful resume shows the "Reprise à …" toast. Both render inside the
    // player surface (bottom toast) rather than as a page-level SnackBar.
    _player.onLoadFailed = () {
      if (!mounted) return;
      _showPlayerToast(context.l10n.player_load_failed);
      setState(() {});
    };
    _player.onResumed = (position) {
      if (!mounted) return;
      _showPlayerToast(
        context.l10n.player_resume_at(_formatPlayerTime(position)),
      );
    };

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: isLandscape ? Colors.black : _bg,
      // In landscape the body must extend behind the bottom navigation bar
      // so the video fills edge-to-edge without a black gap at the bottom.
      extendBody: isLandscape,
      body: isLandscape
          ? _buildLandscape(chapters)
          : _buildPortrait(chapters),
    );
  }

  // ─── PORTRAIT ───────────────────────────────────────────────────────────────

  Widget _buildPortrait(List<Chapter> chapters) {
    final topPad = MediaQuery.of(context).padding.top;
    return Column(
      children: [
        // ── Player — toujours fixé, ne scrolle jamais ─────────────────────────
        SizedBox(
          height: 230 + topPad,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildBanner(chapters),
              Positioned(
                top: topPad,
                left: 0,
                right: 0,
                child: ValueListenableBuilder<bool>(
                  valueListenable: _player.controlsVisible,
                  builder: (_, controlsVis, _) => AnimatedOpacity(
                    opacity: controlsVis ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: IgnorePointer(
                      ignoring: !controlsVis,
                      child: Row(
                        children: [
                          IconButton(
                            // Même style que le bouton retour du lecteur paysage
                            // — "<" aplati du pack Broken demandé
                            icon: const Icon(Broken.arrow_left_2, color: Colors.white, size: 22),
                            onPressed: () => Navigator.of(context).pop(),
                            padding: const EdgeInsets.all(8),
                          ),
                          // IgnorePointer : la zone du titre laisse passer
                          // les touches jusqu'au bouton réglages de
                          // l'overlay (sinon il restait mort et grisé).
                          Expanded(
                            child: IgnorePointer(
                              child: ValueListenableBuilder<double>(
                                valueListenable: _headerTitleOpacity,
                                builder: (_, opacity, _) => Opacity(
                                  opacity: opacity,
                                  child: Text(
                                    widget.manga.name ?? '',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      shadows: [
                                        Shadow(
                                          blurRadius: 6,
                                          color: Colors.black54,
                                        ),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // ── Contenu scrollable ────────────────────────────────────────────────
        Expanded(
          child: NestedScrollView(
            controller: _nestedScrollCtrl,
            headerSliverBuilder: (ctx, innerBoxIsScrolled) => [
              SliverToBoxAdapter(child: _buildMetadataBlock(chapters)),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    indicatorColor: _accent,
                    indicatorWeight: 2.5,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: _AnimatedTabIndicator(color: _accent),
                    labelColor: _textPrimary,
                    unselectedLabelColor: _grey,
                    labelStyle: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600),
                    unselectedLabelStyle: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w400),
                    dividerColor: Colors.transparent,
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Broken.star, size: 15),
                            const SizedBox(width: 6),
                            Text(context.l10n.for_you),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Broken.messages_2, size: 15),
                            const SizedBox(width: 6),
                            Text(context.l10n.watch_home_reel_comments),
                          ],
                        ),
                      ),
                      // Only present while a Cloudflare refusal is pending:
                      // the tab hosts the inline bypass panel so the challenge
                      // is solved right here, next to the player.
                      if (_challengeTabVisible)
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Broken.shield_search,
                                  size: 15, color: Colors.orange),
                              const SizedBox(width: 6),
                              const Text('Cloudflare'),
                            ],
                          ),
                        ),
                    ],
                  ),
                  color: _bg,
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildRecommendationsTab(),
                _buildCommentsTab(),
                if (_challengeTabVisible) _buildChallengeTab(chapters),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── LANDSCAPE — fullscreen player ──────────────────────────────────────────

  Widget _buildLandscape(List<Chapter> chapters) {
    if (_player.hasVideoUrl) {
      return SizedBox.expand(child: _player.buildFullscreenPlayer());
    }
    return Stack(
      children: [
        SizedBox.expand(child: _buildBannerImageOnly()),
        // Failure feedback must also appear in landscape: a failed load used to
        // silently leave the cover on screen with no way to retry. A Cloudflare
        // refusal is handled in the "Cloudflare" tab, never over the video.
        if (_player.loadFailed)
          _PlayerFailureOverlay(
            message: context.l10n.player_load_failed,
            retryLabel: context.l10n.player_retry,
            onRetry: () => _retryLoadedEpisode(chapters),
            onChallenge: _challengeTabVisible ? () => _selectTab(_challengeTabIndex) : null,
          ),
        if (_playerToastMsg != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: _PlayerToast(message: _playerToastMsg!),
          ),
        SafeArea(
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Broken.arrow_left_2, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── BANNER ─────────────────────────────────────────────────────────────────

  Widget _buildBanner(List<Chapter> chapters) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildBannerImageOnly(),

        // Player fades in smoothly over cover when URL is ready
        AnimatedOpacity(
          opacity: _player.hasVideoUrl ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 480),
          curve: Curves.easeInOut,
          child: _player.buildBannerOverlay(context: context),
        ),

        // Loading pulse — visible while video URL is being resolved
        if (!_player.hasVideoUrl && !_player.loadFailed &&
            _player.loadedChapterId != null)
          const _LoadingBannerPulse(),

        // Load failure — retry overlay (Lottie error animation + button),
        // centered on the player surface.
        if (_player.loadFailed && !_player.hasVideoUrl)
          _PlayerFailureOverlay(
            message: context.l10n.player_load_failed,
            retryLabel: context.l10n.player_retry,
            onRetry: () => _retryLoadedEpisode(chapters),
            onChallenge: _challengeTabVisible ? () => _selectTab(_challengeTabIndex) : null,
          ),

        // A refused media CDN is solved *inside* the player box: the user asked
        // for the challenge there instead of in a tab they have to find, and it
        // is where the failed stream is. The panel replaces the cover on the
        // same surface, so clearing it retries playback in place.
        if (_player.loadFailed && !_player.hasVideoUrl && _challengeTabVisible)
          _buildInlinePlayerChallenge(chapters),

        // In-player toast — bottom of the surface, MovieBox style.
        if (_playerToastMsg != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: _PlayerToast(message: _playerToastMsg!),
          ),

        // Reel-mode button — appears once the loaded video is detected as
        // vertical/short-form content (e.g. MovieBox "TV courte").
        ValueListenableBuilder<bool>(
          valueListenable: _player.isPortraitFormat,
          builder: (_, isReel, _) {
            if (!isReel || !_player.hasVideoUrl) return const SizedBox.shrink();
            final chapter = chapters.firstWhere(
              (c) => c.id == _player.loadedChapterId,
              orElse: () => chapters.first,
            );
            return Positioned(
              right: 10,
              bottom: 10,
              child: GestureDetector(
                onTap: () => _player.launchReelPage(
                  context: context,
                  chapters: chapters,
                  currentChapter: chapter,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.smart_display_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        context.l10n.media_reel_mode,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        // Top shadow uniquement pour lisibilité des contrôles — bord bas net
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.40],
                colors: [Color(0xAA000000), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBannerImageOnly() {
    final manga = widget.manga;
    final headers = (manga.isLocalArchive ?? false)
        ? null
        : ref.watch(headersProvider(
            source: manga.source!,
            lang: manga.lang!,
            sourceId: manga.sourceId,
          ));
    final imgUrl = toImgUrl(manga.customCoverFromTracker ?? manga.imageUrl ?? '');

    if (manga.customCoverImage != null) {
      return Image.memory(
        manga.customCoverImage as Uint8List,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
    return cachedNetworkImage(
      headers: headers,
      imageUrl: imgUrl,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
    );
  }

  // ─── METADATA BLOCK ─────────────────────────────────────────────────────────

  Widget _buildMetadataBlock(List<Chapter> chapters) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitleRow(chapters),
          const SizedBox(height: 7),
          _buildMetaRow(chapters),
          const SizedBox(height: 14),
          _buildActionButtons(chapters),
          const SizedBox(height: 20),
          _buildRessourcesSection(chapters),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ─── TITLE ROW ──────────────────────────────────────────────────────────────
  // Title + "Info ›" plain text right next to title (not far right)

  Widget _buildTitleRow(List<Chapter> chapters) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: Text(
            widget.manga.name ?? '',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 21,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // "Info" pill with the Broken icon pack (matches the rest of the page)
        // instead of a bare text chevron.
        GestureDetector(
          onTap: () => _showInfoSheet(context, chapters: chapters),
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Broken.information, size: 15, color: _accent),
              const SizedBox(width: 4),
              Text(
                context.l10n.plugins_action_info,
                style: TextStyle(
                  color: _accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(Broken.arrow_right_3, size: 14, color: _accent),
            ],
          ),
        ),
      ],
    );
  }

  // ─── META ROW ───────────────────────────────────────────────────────────────
  // [SVG] | [★ score] | country | seasons

  Widget _buildMetaRow(List<Chapter> chapters) {
    final isMovie = _isMovie(chapters);
    final parts = <String>[];

    // Production country from ·-prefixed genres (provided by extensions)
    final productionCountry = (widget.manga.genre ?? [])
        .where((g) => g.startsWith('·'))
        .map((g) => g.substring(1).trim())
        .where((g) => g.isNotEmpty)
        .firstOrNull;
    // Fallback to lang when no country available (never display raw "MULTI")
    final lang = widget.manga.lang?.trim() ?? '';
    if (productionCountry != null && productionCountry.isNotEmpty) {
      parts.add(productionCountry);
    } else if (lang.isNotEmpty && lang.toLowerCase() != 'multi') {
      parts.add(lang.toUpperCase());
    }

    // Seasons count for series
    if (!isMovie) {
      final seasons = _detectSeasons(chapters);
      // Extensions that publish no season markers still describe a multi-episode
      // title as a single season, so the meta line always carries a season count
      // instead of dropping the field (the user expects "1 saison" there).
      parts.add(
        context.l10n.media_season_count(seasons.isEmpty ? 1 : seasons.length),
      );
    } else {
      parts.add(context.l10n.media_film);
    }

    Widget vbar() => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text('|', style: TextStyle(color: _faint, fontSize: 12)),
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SvgPicture.string(
          isMovie ? _kMovieSvg : _kSerieSvg,
          width: 14,
          height: 14,
          colorFilter: ColorFilter.mode(_grey, BlendMode.srcIn),
        ),
        vbar(),
        const Icon(Icons.star_rounded, color: Color(0xFFFFD700), size: 13),
        const SizedBox(width: 4),
        Builder(builder: (_) {
          final rating = _ratingLabel(widget.manga.description ?? '');
          return Text(
            rating ?? context.l10n.media_not_available,
            style: TextStyle(color: _grey, fontSize: 12),
          );
        }),
        if (parts.isNotEmpty) ...[
          vbar(),
          Expanded(
            child: Text(
              parts.join('  |  '),
              style: TextStyle(color: _grey, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ] else
          const Expanded(child: SizedBox.shrink()),
      ],
    );
  }

  /// Extracts a star rating from the extension-provided description.
  ///
  /// Accepts both the historical `IMDb 8.5` token and the generic `★ 4.96`
  /// token (MovieBox-style / hanime). Returns the bare number as text so the
  /// caller can render it next to the star icon, or `null` when absent.
  static String? _ratingLabel(String description) {
    final m = RegExp(r'(?:IMDb\s+|★\s*)([\d.]+)').firstMatch(description);
    return m?.group(1);
  }

  // ─── INFO SHEET ─────────────────────────────────────────────────────────────
  // Fixed bottom sheet — no drag handle, never overlaps player (230 px)

  void _showInfoSheet(BuildContext ctx, {List<Chapter> chapters = const []}) {
      final manga = widget.manga;
      showModalBottomSheet(
        context: ctx,
        isScrollControlled: true,
        barrierColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        builder: (sheetCtx) {
          final screen  = MediaQuery.of(ctx).size.height;
          final statusH = MediaQuery.of(ctx).padding.top;
          final maxH    = screen - 230 - statusH;

          // Synopsis — drop the extension's trailing meta token (e.g.
          // "★ 4.96 · 1 season") and any embedded gallery payload so the
          // synopsis text stays pure prose; those facts live in the info grid.
          final rawDesc = (manga.description ?? '').trim();
          final desc = rawDesc
              .replaceAll(RegExp(r'\n*★\s*[\d.]+\s*·\s*\d+\s*season.*$',
                  dotAll: true), '')
              .replaceAll(RegExp(r'\n*__GALLERY__:.*$', dotAll: true), '')
              .trim();
          final genres = (manga.genre ?? []).where((g) => !g.startsWith('·')).toList();
          final countrySheet = (manga.genre ?? []).where((g) => g.startsWith('·'))
              .map((g) => g.substring(1)).firstOrNull;
          final _aS = (manga.artist ?? '').split(',').map((s) => s.trim())
              .where((s) => s.isNotEmpty).toList();
          final dirSheet  = _aS.isNotEmpty ? _aS.first : null;
          final castSheet = _aS.length > 1 ? _aS.sublist(1).join(', ') : null;
          final lang   = (manga.lang ?? '').toUpperCase();

          return Container(
            height: maxH,
            decoration: BoxDecoration(color: _surface),
            child: Column(
              children: [
                // ── Header: title + close button, separator below ─────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
                  child: Row(
                    children: [
                      Text(
                        context.l10n.media_details,
                        style: TextStyle(
                            color: _textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.pop(sheetCtx),
                        child: Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                              color: _card, shape: BoxShape.circle),
                          child: Icon(Broken.close_circle, size: 16, color: _grey),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: _faint),
                // ── Scrollable IMDB-style content ─────────────────────────────
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    children: [
                      // ── Hero: cover + title + badges ─────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Poster. Tapping it opens a full-screen viewer:
                          // XNXX stills are only 600x337 on the card while the
                          // hero rendition is 2080x1170, so pinch-zoom is the
                          // only way to actually read the artwork.
                          GestureDetector(
                            onTap: () => _openCover(
                              context,
                              toImgUrl(
                                  manga.customCoverFromTracker ??
                                      manga.imageUrl ?? ''),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: cachedNetworkImage(
                                imageUrl: toImgUrl(
                                    manga.customCoverFromTracker ??
                                        manga.imageUrl ?? ''),
                                width: 96,
                                height: 140,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title
                                Text(
                                  manga.name ?? '',
                                  style: TextStyle(
                                    color: _textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                // Status badge
                                if ((manga.status?.toString() ?? '').isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _accent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: _accent.withValues(alpha: 0.35),
                                          width: 0.7),
                                    ),
                                    child: Text(
                                      _statusLabel(manga.status),
                                      style: TextStyle(
                                          color: _accent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                // Language + source pills (Broken icon pack,
                                // consistent with the rest of the detail page)
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    if (lang.isNotEmpty)
                                      _infoPill(Broken.language_circle, lang),
                                    if ((manga.source ?? '').isNotEmpty)
                                      _infoPill(Broken.folder, manga.source!),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── Synopsis ─────────────────────────────────────────
                      if (desc.isNotEmpty) ...[
                        _sheetSectionLabel(context.l10n.media_synopsis),
                        const SizedBox(height: 8),
                        StatefulBuilder(
                          builder: (c, setSt) => GestureDetector(
                            onTap: () => setSt(() =>
                                _isDescriptionExpanded =
                                    !_isDescriptionExpanded),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  desc,
                                  maxLines:
                                      _isDescriptionExpanded ? null : 5,
                                  overflow: _isDescriptionExpanded
                                      ? TextOverflow.visible
                                      : TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: _grey,
                                      fontSize: 13,
                                      height: 1.6),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _isDescriptionExpanded
                                      ? context.l10n.catalog_card_see_less
                                      : context.l10n.catalog_card_see_more,
                                  style: TextStyle(
                                      color: _accent, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                      ],

                      // ── Genres ───────────────────────────────────────────
                      if (genres.isNotEmpty) ...[
                        _sheetSectionLabel(context.l10n.media_genres),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final g in genres)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _card,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: _faint, width: 0.7),
                                ),
                                child: Text(g,
                                    style: TextStyle(
                                        color: _textPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 22),
                      ],

                      // ── Cast / Crew ───────────────────────────────────────
                      if (dirSheet != null || castSheet != null || countrySheet != null) ...[
                        _sheetSectionLabel(context.l10n.media_crew_info),
                        const SizedBox(height: 12),
                        if (countrySheet != null) ...[
                          _castRow(
                            Broken.global,
                            context.l10n.media_country,
                            countrySheet,
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (dirSheet != null) ...[
                          _castRow(
                            Broken.video_play,
                            context.l10n.media_director,
                            dirSheet,
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (castSheet != null)
                          _castRow(
                            Broken.people,
                            context.l10n.media_cast,
                            castSheet,
                          ),
                        const SizedBox(height: 22),
                      ],

                      // ── Info table — 3-col icon grid ─────────────────────
                      _sheetSectionLabel(context.l10n.media_information),
                      const SizedBox(height: 12),
                      _infoGrid3(context, chapters, lang, countrySheet),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    Widget _castRow(IconData icon, String role, String name) {
      return Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, size: 18, color: _accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                        color: _textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text(role,
                    style: TextStyle(color: _grey, fontSize: 11)),
              ],
            ),
          ),
        ],
      );
    }

    /// 3-column icon grid of the title's key facts, shown in the Info sheet.
    ///
    /// Everything is sourced from what the extension publishes (rating token,
    /// ·-prefixed country, season markers, year in author, …); fields the
    /// extension does not provide are simply omitted so the grid never shows
    /// placeholder dashes.
    Widget _infoGrid3(
      BuildContext context,
      List<Chapter> chapters,
      String lang,
      String? country,
    ) {
      final manga = widget.manga;
      final isMovie = _isMovie(chapters);

      final cells = <_SheetInfoCell>[];

      final rating = _ratingLabel(manga.description ?? '');
      if (rating != null) {
        cells.add(_SheetInfoCell(
          icon: Broken.star,
          label: context.l10n.media_rating,
          value: rating,
          accent: true,
          accentColor: const Color(0xFFF59E0B),
        ));
      }

      if (country != null && country.trim().isNotEmpty) {
        cells.add(_SheetInfoCell(
          icon: Broken.global,
          label: context.l10n.media_country,
          value: country.trim(),
        ));
      }

      if (!isMovie && chapters.isNotEmpty) {
        final seasons = _detectSeasons(chapters);
        cells.add(_SheetInfoCell(
          icon: Broken.monitor,
          label: context.l10n.media_seasons,
          value: '${seasons.isEmpty ? 1 : seasons.length}',
        ));
      }

      if (lang.isNotEmpty) {
        cells.add(_SheetInfoCell(
          icon: Broken.language_circle,
          label: context.l10n.media_language,
          value: lang,
        ));
      }

      // Director / studio — the extension publishes it in `artist`.
      final director = (manga.artist ?? '')
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .firstOrNull;
      if (director != null) {
        cells.add(_SheetInfoCell(
          icon: Broken.user,
          label: context.l10n.media_director,
          value: director,
        ));
      }

      final year = (manga.author ?? '').trim();
      if (RegExp(r'^\d{4}$').hasMatch(year)) {
        cells.add(_SheetInfoCell(
          icon: Broken.calendar,
          label: context.l10n.media_year,
          value: year,
        ));
      }

      if (chapters.isNotEmpty) {
        cells.add(_SheetInfoCell(
          icon: isMovie ? Broken.video_play : Broken.play_circle,
          label: isMovie ? context.l10n.media_type : context.l10n.media_episodes,
          value: isMovie ? context.l10n.media_film : '${chapters.length}',
          accent: true,
          accentColor: _accent,
        ));
      }

      cells.add(_SheetInfoCell(
        icon: Broken.verify,
        label: context.l10n.media_status,
        value: _statusLabel(manga.status),
      ));

      if ((manga.source ?? '').isNotEmpty) {
        cells.add(_SheetInfoCell(
          icon: Broken.folder,
          label: context.l10n.browse_create_source,
          value: manga.source!,
        ));
      }

      if (cells.isEmpty) return const SizedBox.shrink();

      const gap = 8.0;
      final rows = <Widget>[];
      for (var i = 0; i < cells.length; i += 3) {
        final rowCells = cells.sublist(i, (i + 3).clamp(0, cells.length));
        rows.add(Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var j = 0; j < 3; j++) ...[
              if (j > 0) const SizedBox(width: gap),
              Expanded(
                child: j < rowCells.length
                    ? _sheetInfoCell(context, rowCells[j])
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ));
        if (i + 3 < cells.length) rows.add(const SizedBox(height: gap));
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      );
    }

    Widget _sheetInfoCell(BuildContext context, _SheetInfoCell cell) {
      final tint = cell.accent ? cell.accentColor! : _accent;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: cell.accent
              ? cell.accentColor!.withValues(alpha: 0.09)
              : _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cell.accent
                ? cell.accentColor!.withValues(alpha: 0.30)
                : _faint.withValues(alpha: 0.45),
            width: 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(cell.icon, size: 15, color: tint),
            ),
            const SizedBox(height: 8),
            Text(
              cell.label,
              style: TextStyle(color: _grey, fontSize: 10.5),
            ),
            const SizedBox(height: 2),
            Text(
              cell.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cell.accent ? cell.accentColor! : _textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

  

  Widget _infoPill(IconData icon, String label) {
    if (label.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: _grey),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: _grey, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _sheetSectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
          color: _textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w700),
    );
  }

  String _statusLabel(dynamic status) {
    switch (status?.toString()) {
      case '0':
        return context.l10n.media_status_ongoing_label;
      case '1':
        return context.l10n.media_status_completed_label;
      case '2':
        return context.l10n.media_licenced;
      case '3':
        return context.l10n.media_status_cancelled_label;
      case '4':
        return context.l10n.media_status_on_hold_label;
      default:
        return context.l10n.media_unknown;
    }
  }

  // ─── ACTION BUTTONS ─────────────────────────────────────────────────────────

  Widget _buildActionButtons(List<Chapter> chapters) {
    final isFav = widget.manga.favorite ?? false;
    // Progression LIVE de la file : watch ciblé sur la map (un tick de
    // n'importe quel chapitre ne reconstruit que ce Consumer)
    ref.watch(downloadQueueStateProvider.select((s) => s.liveProgress));
    final dlProgress = _downloadChipProgress(chapters);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(
            icon: isFav ? Icons.bookmark : Icons.bookmark_border_outlined,
            label: isFav
                ? context.l10n.in_library
                : context.l10n.media_add_to_library,
            onTap: _toggleFavorite,
            active: isFav,
          ),
          const SizedBox(width: 8),
          _chip(
              icon: Icons.drive_file_move_outlined,
              label: context.l10n.migrate,
              onTap: () => context.pushNamed('migrate', extra: widget.manga)),
          const SizedBox(width: 8),
          _chip(
              icon: Icons.share_outlined,
              label: context.l10n.media_share,
              onTap: () => _share(context)),
          const SizedBox(width: 8),
          // Télécharger : affiche la progression quand un téléchargement de
          // cette page est actif, et ouvre toujours le sheet de téléchargement.
          _chip(
              icon: Icons.download_outlined,
              label: context.l10n.download,
              onTap: () => _showDownloadSheet(context, chapters),
              progress: dlProgress),
          const SizedBox(width: 8),
          _chip(
              icon: Icons.language_outlined,
              label: context.l10n.media_webview,
              onTap: _openInBrowser),
        ],
      ),
    );
  }

  /// Progression d'un téléchargement en lien avec cette page (0 → 1), ou
  /// `null` si rien n'est en cours. Sources combinées, la plus avancée gagne
  /// (l'anneau ne recule jamais) :
  ///   • progression live de la session ([DownloadLiveProgress]) — plus fraîche ;
  ///   • compteurs Isar (`succeeded/total`, offset d'une reprise).
  double? _downloadChipProgress(List<Chapter> chapters) {
    final state = ref.read(downloadQueueStateProvider);
    double? best;
    var any = false;
    for (final chapter in chapters) {
      final id = chapter.id;
      if (id == null) continue;

      final live = state.liveProgress[id];
      if (live != null) {
        any = true;
        double? liveFraction;
        if (!live.isIndeterminate &&
            live.downloadedBytes != null &&
            (live.totalBytes ?? 0) > 0) {
          liveFraction =
              (live.downloadedBytes! / live.totalBytes!).clamp(0.0, 1.0);
        } else if (!live.isIndeterminate && live.totalUnits > 0) {
          liveFraction =
              (live.completedUnits / live.totalUnits).clamp(0.0, 1.0);
        }
        if (liveFraction != null && liveFraction > (best ?? 0)) {
          best = liveFraction;
        }
      }

      final row = isar.downloads.getSync(id);
      if (row == null || row.isDownload == true) continue;
      if (row.status == 'failed' || row.status == 'cancelled') continue;
      if (row.isStartDownload != true) continue;
      any = true;
      final total = row.total ?? 0;
      if (total > 1) {
        final storedFraction =
            ((row.succeeded ?? 0) / total.toDouble()).clamp(0.0, 1.0);
        if (storedFraction > (best ?? 0)) best = storedFraction;
      }
    }
    // 0.0 = actif mais fraction pas encore connue → anneau indéterminé.
    return any ? (best ?? 0.0) : null;
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
    double? progress,
  }) {
    final tint = active ? _accent : _onSurface.withValues(alpha: 0.55);
    Widget leading;
    if (progress != null) {
      // Anneau de progression à la place de l'icône : la page reste utilisable,
      // un tap sur la chip ouvre toujours le sheet de téléchargement.
      leading = SizedBox(
        width: 18,
        height: 18,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                value: progress > 0.01 ? progress.clamp(0.0, 1.0) : null,
                strokeWidth: 2.2,
                color: active ? _accent : _accent,
                backgroundColor: tint.withValues(alpha: 0.2),
              ),
            ),
            if (progress > 0.02)
              Text(
                '${(progress * 100).round()}',
                style: TextStyle(
                  fontSize: 6.5,
                  fontWeight: FontWeight.w700,
                  color: _accent,
                ),
              ),
          ],
        ),
      );
    } else {
      leading = Icon(icon, size: 17, color: tint);
    }
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _accent.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: active ? _accent : _faint.withValues(alpha: 0.45),
              width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            leading,
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: tint,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // ─── MOVIE / SERIES DETECTION ───────────────────────────────────────────────

  bool _isMovie(List<Chapter> chapters) {
    if (widget.isLoading) return false;
    if (chapters.isEmpty) return false;
    // 1 episode → movie/single; 2+ → series
    return chapters.length == 1;
  }

  List<String> _detectSeasons(List<Chapter> chapters) {
    final seasonRegex = RegExp(
        r'(?:Saison|Season|Partie|Part)\s*(\d+)|S(\d{1,2})(?:E\d+)?',
        caseSensitive: false);
    final seen = <String>{};
    for (final ch in chapters) {
      final m = seasonRegex.firstMatch(ch.name ?? '');
      if (m != null) {
        final num = m.group(1) ?? m.group(2) ?? '1';
        // Locale-independent key: the raw season number is the only stable
        // identity, and the label is built at render time by _seasonLabel.
        seen.add('S$num');
      }
    }
    if (seen.isEmpty) return [];
    return seen.toList()
      ..sort((a, b) {
        final na =
            int.tryParse(a.replaceAll(RegExp(r'\D'), '')) ?? 0;
        final nb =
            int.tryParse(b.replaceAll(RegExp(r'\D'), '')) ?? 0;
        return na.compareTo(nb);
      });
  }

  String _seasonLabel(String key) {
    final num = int.tryParse(RegExp(r'\d+').firstMatch(key)?.group(0) ?? '');
    return num == null ? key : context.l10n.media_season_n(num);
  }

  // Clé interne utilisée pour le filtrage (code ISO en minuscule si connu,
  // sinon mot brut en majuscule pour compat avec les extensions historiques).
  String? _langKey(Chapter ch) {
    final code = extractLangCode(ch.scanlator);
    if (code != null) return code.toLowerCase();
    final langRx = RegExp(
        r'\b(VF|VOSTFR|VO|French|English|Français|Dub|Sub|MULTI|VOSTA|'
        r'Japanese|Chinese|Korean|Spanish|Portuguese|Russian|Arabic|German|'
        r'Italian|Polish|Turkish|Vietnamese|Thai|Indonesian|Hindi|Dutch|'
        r'Swedish|Finnish|Norwegian|Danish|Czech|Slovak|Romanian|Hungarian|'
        r'Bulgarian|Croatian|Serbian|Ukrainian|Hebrew|Persian)\b',
        caseSensitive: false);
    final m = langRx.firstMatch('${ch.scanlator ?? ''} ${ch.name ?? ''}');
    return m?.group(0)?.toUpperCase();
  }

  List<String> _detectLanguages(List<Chapter> chapters) {
    final seen = <String>{};
    for (final ch in chapters) {
      final key = _langKey(ch);
      if (key != null) seen.add(key);
    }
    return seen.toList();
  }

  List<Chapter> _filterChapters(List<Chapter> all) {
    List<Chapter> result = all;
    final season = _selectedSeason;
    if (season != null) {
      final num = RegExp(r'\d+').firstMatch(season)?.group(0) ?? '';
      // S0? matches both "S1" and "S01"; (?!\d) prevents "S1" matching "S10"
      final rx = RegExp(
          r'(?:Saison|Season|Partie|Part)\s*' +
              num +
              r'\b|S0?' + num + r'(?!\d)',
          caseSensitive: false);
      final filtered =
          result.where((ch) => rx.hasMatch(ch.name ?? '')).toList();
      if (filtered.isNotEmpty) result = filtered;
    }
    final lang = _selectedLanguage;
    if (lang != null) {
      final filtered = result.where((ch) => _langKey(ch) == lang).toList();
      if (filtered.isNotEmpty) result = filtered;
    }
    // Some extensions return duplicate entries for the same episode (e.g. one
    // per source/quality variant). Without deduping, the season+language
    // filter above can still leave far more entries than actual episodes,
    // which threw off the "+N more" count on the episode strip (it counted
    // duplicates from every season instead of just the remaining episodes of
    // the selected one). Keep one Chapter per distinct episode number.
    {
      final seen = <int>{};
      final deduped = <Chapter>[];
      for (int i = 0; i < result.length; i++) {
        if (seen.add(_epNum(result[i].name, i + 1))) deduped.add(result[i]);
      }
      result = deduped;
    }
    return result;
  }

  // ─── RESSOURCES SECTION ─────────────────────────────────────────────────────

  Widget _buildRessourcesSection(List<Chapter> chapters) {
    final isMovie  = _isMovie(chapters);
    final seasons  = isMovie ? <String>[] : _detectSeasons(chapters);
    // Auto-select first season when user hasn't picked one yet
    if (!isMovie && seasons.isNotEmpty && _selectedSeason == null) {
      _selectedSeason = seasons.first;
    }
    final languages = _detectLanguages(chapters);
    final filtered  = _filterChapters(chapters);

    final source = getSource(
        widget.manga.lang ?? '',
        widget.manga.source ?? '',
        widget.manga.sourceId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header: [icon] Ressources ······ [ext_icon] [ext_name] [⋮] ─────────
        Row(
          children: [
            Icon(Icons.video_library_outlined,
                size: 16, color: _textPrimary),
            const SizedBox(width: 6),
            Text(
              context.l10n.media_resources,
              style: TextStyle(
                  color: _textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            // "Fourni par <extension>" — the credit sits immediately before the
            // options icon so the two read as one group on the right. The group
            // is allowed to shrink: with a long extension name it used to push
            // the ⋯ past the right edge, where the Row clipped it and only the
            // first two dots stayed visible.
            if (source != null)
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        context.l10n.media_provided_by,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _grey, fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 4),
                    if ((source.iconUrl ?? '').isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: cachedNetworkImage(
                          imageUrl: source.iconUrl!,
                          width: 16,
                          height: 16,
                          fit: BoxFit.cover,
                        ),
                      ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        source.name?.trim().isNotEmpty == true
                            ? source.name!.trim()
                            : context.l10n.watch_home_extension,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _grey,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(width: 8),
            // Options button — opens the same bottom sheet as the season /
            // language / quality pills instead of an anchored popup menu, so
            // every selector on the page behaves identically. Three-dot "more"
            // glyph with no chip behind it: `more` is the horizontal ⋯, while
            // `more_2` is the triangular layout that read as a share icon.
            GestureDetector(
              onTap: () => _showResourceMenuSheet(
                context,
                chapters: chapters,
                source: source,
              ),
              behavior: HitTestBehavior.opaque,
              child: Icon(Broken.more, size: 22, color: _textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── 2 boxes : Saison (série) · Langue ────────────────────────────
        // Note: no background video-list fetch here — avoids Cloudflare triggers
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Skeleton pills during initial load
              if (widget.isLoading && chapters.isEmpty) ...[
                _SkeletonBox(radius: 8, w: 90, h: 36),
                const SizedBox(width: 8),
                _SkeletonBox(radius: 8, w: 70, h: 36),
              ] else ...[
              // Only offer a season picker when the episodes actually carry
              // season info. A multi-episode title with no seasons used to get
              // a phantom "Saison 1" box that filtered nothing.
              if (!isMovie && seasons.isNotEmpty) ...[
                _buildDropdownPill(
                  label: _selectedSeason ?? seasons.first,
                  items: seasons,
                  onSelect: (v) => setState(() => _selectedSeason = v),
                  sheetTitle: context.l10n.media_choose_season,
                  displayLabel: _seasonLabel,
                ),
                if (languages.isNotEmpty) const SizedBox(width: 8),
              ],
              if (languages.isNotEmpty)
                _buildDropdownPill(
                  label: _selectedLanguage ?? languages.first,
                  items: languages,
                  onSelect: (v) => setState(() => _selectedLanguage = v),
                  displayLabel: (key) => localizedLanguageLabel(
                      key, Localizations.localeOf(context).languageCode),
                  sheetTitle: context.l10n.media_choose_language,
                ),
              if (_player.loadedVideos.length > 1) ...[
                const SizedBox(width: 8),
                _buildDropdownPill(
                  label: _player.selectedQuality ?? _player.loadedVideos.first.quality,
                  items: _player.loadedVideos.map((v) => v.quality).toList(),
                  onSelect: (q) {
                    final video = _player.loadedVideos.firstWhere(
                      (v) => v.quality == q,
                      orElse: () => _player.loadedVideos.first,
                    );
                    _player.switchQuality(video).then((_) {
                      if (mounted) setState(() {});
                    });
                    setState(() {});
                  },
                  sheetTitle: context.l10n.media_choose_resolution,
                  selectedValue: _player.selectedQuality,
                ),
              ],
              ], // close else spread
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Content ───────────────────────────────────────────────────────────
        if (widget.isLoading && chapters.isEmpty)
          // Skeleton episode tiles — visible dès le début sans pop
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < 8; i++) ...[
                  _SkeletonBox(radius: 6, w: 48, h: 48),
                  if (i < 7) const SizedBox(width: 8),
                ],
              ],
            ),
          )
        else if (chapters.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Icon(Icons.video_library_outlined, color: _grey, size: 40),
                const SizedBox(height: 8),
                Text(context.l10n.media_no_episode_available,
                    style: TextStyle(color: _grey)),
              ],
            ),
          )
        else if (isMovie)
          _buildMovieBox(filtered.isNotEmpty ? filtered.first : chapters.first)
        else
          _buildEpisodeList(
            _sortedEpisodes(filtered),
            _sortedEpisodes(chapters),
          ),

        // The "Fourni par <extension>" credit now lives in the section header,
        // right before the options icon — see _buildRessourcesSection.
      ],
    );
  }

  // ── Dropdown pill (MovieBox style: "French dub ▼") ───────────────────────────
  Widget _buildDropdownPill({
    required String label,
    required List<String> items,
    required void Function(String) onSelect,
    String Function(String)? displayLabel,
    String? sheetTitle,
    String? selectedValue,
  }) {
    return GestureDetector(
      onTap: () => _showDropdownSheet(label, items, onSelect,
          displayLabel: displayLabel, sheetTitle: sheetTitle,
          selectedValue: selectedValue),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _faint, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayLabel?.call(label) ?? label,
              style: TextStyle(
                  color: _onSurface.withValues(alpha: 0.75), fontSize: 13),
            ),
            const SizedBox(width: 6),
            Icon(Icons.keyboard_arrow_down_rounded, color: _grey, size: 18),
          ],
        ),
      ),
    );
  }

    void _showDropdownSheet(
        String label, List<String> items, void Function(String) onSelect,
        {String Function(String)? displayLabel, String? sheetTitle,
        String? selectedValue}) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        barrierColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        builder: (ctx) {
          final screen  = MediaQuery.of(context).size.height;
          final statusH = MediaQuery.of(context).padding.top;
          final maxH    = screen - 230 - statusH;
          return Container(
            height: maxH,
            decoration: BoxDecoration(color: _surface),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
                  child: Row(
                    children: [
                      Text(sheetTitle ?? displayLabel?.call(label) ?? label,
                          style: TextStyle(
                              color: _textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                              color: _card, shape: BoxShape.circle),
                          child: Icon(Broken.close_circle, size: 16, color: _grey),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: _faint),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: items.map((item) {
                      // Use explicit selectedValue when provided (e.g. quality);
                      // fall back to comparing against language/season state.
                      final isSel = selectedValue != null
                          ? item == selectedValue
                          : item == _selectedLanguage || item == _selectedSeason;
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          onSelect(item);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            gradient: isSel
                                ? LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      _accent.withValues(alpha: 0.30),
                                      _accent.withValues(alpha: 0.10),
                                    ],
                                  )
                                : null,
                            color: isSel ? null : _card,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSel
                                  ? _accent.withValues(alpha: 0.55)
                                  : Colors.transparent,
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            displayLabel?.call(item) ?? item,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isSel ? _accent : _textPrimary,
                              fontSize: 14,
                              fontWeight: isSel
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

  // _buildSelectorRow replaced by _buildDropdownPill + _showDropdownSheet above

  // ── Options menu (bottom sheet) ──────────────────────────────────────────────
  // Same surface, header and row styling as the season / language / quality
  // sheets, so the "⋮" button no longer opens an anchored popup.
  void _showResourceMenuSheet(
    BuildContext ctx, {
    required List<Chapter> chapters,
    required Source? source,
  }) {
    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      barrierColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (sheetCtx) {
        final screen = MediaQuery.of(ctx).size.height;
        final statusH = MediaQuery.of(ctx).padding.top;
        final maxH = screen - 230 - statusH;

        final actions = <({IconData icon, String label, VoidCallback onTap})>[
          (
            icon: Broken.refresh,
            label: context.l10n.media_refresh,
            onTap: () => widget.checkForUpdate(true),
          ),
          (
            icon: Broken.export,
            label: context.l10n.open_in_browser,
            onTap: _openInBrowser,
          ),
          if (source != null)
            (
              icon: Broken.setting_2,
              label: context.l10n.extension_settings,
              onTap: () =>
                  context.pushNamed('extension_detail', extra: source),
            ),
          (
            icon: Broken.share,
            label: context.l10n.media_share,
            onTap: () => _share(context),
          ),
          (
            icon: Broken.document_download,
            label: context.l10n.media_download_all,
            onTap: () => _downloadAll(chapters),
          ),
        ];

        return Container(
          height: maxH,
          decoration: BoxDecoration(color: _surface),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
                child: Row(
                  children: [
                    Text(
                      context.l10n.media_source_options,
                      style: TextStyle(
                          color: _textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(sheetCtx),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                            color: _card, shape: BoxShape.circle),
                        child: Icon(Broken.close_circle, size: 16, color: _grey),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: _faint),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    for (final action in actions)
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          action.onTap();
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: _card,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(action.icon, size: 18, color: _accent),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  action.label,
                                  style: TextStyle(
                                    color: _textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── MOVIE BOX — small rectangle, title only ─────────────────────────────────

  Widget _buildMovieBox(Chapter chapter) {
      final title = widget.manga.name ?? '';
      return GestureDetector(
        onTap: () => _loadEpisodeInBanner(chapter),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                _accent.withValues(alpha: 0.20),
                _accent.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _accent.withValues(alpha: 0.30), width: 0.8),
          ),
          child: Text(
            title.isNotEmpty ? title : context.l10n.media_watch_now,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _accent,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    static const int    _kMaxVisibleEps = 5;
  static const double _kEpThumbW      = 108.0;

  List<Chapter> _sortedEpisodes(List<Chapter> chapters) {
    final indexed = chapters.asMap().entries.toList();
    indexed.sort((a, b) {
      final na = _epNum(a.value.name, a.key);
      final nb = _epNum(b.value.name, b.key);
      return na.compareTo(nb); // ascending — ep 1 first
    });
    final result = <Chapter>[];
    final positionByEpisode = <String, int>{};
    for (final entry in indexed) {
      final chapter = entry.value;
      final key =
          '${chapter.mangaId}\u0000${chapter.name}\u0000${chapter.url}\u0000${chapter.scanlator}';
      final existingIndex = positionByEpisode[key];
      if (existingIndex == null) {
        positionByEpisode[key] = result.length;
        result.add(chapter);
      } else if (chapter.id == _player.loadedChapterId) {
        // A completed quality clone may be the chapter opened from Downloads.
        // Keep it selected without listing every resolution as another episode.
        result[existingIndex] = chapter;
      }
    }
    return result;
  }

  /// Indices in [sorted] whose episode has a downloaded video on disk.
  ///
  /// When *nothing* is downloaded the title is streamed, so every episode is
  /// playable and the whole list is returned — "next" then simply walks the
  /// episodes in order.
  List<int> _playableEpisodeIndices(List<Chapter> sorted, Set<int> downloaded) {
    final indices = <int>[];
    for (var i = 0; i < sorted.length; i++) {
      final id = sorted[i].id;
      if (id != null && downloaded.contains(id)) indices.add(i);
    }
    if (indices.isEmpty) {
      return [for (var i = 0; i < sorted.length; i++) i];
    }
    return indices;
  }

  /// The "next" action for the currently loaded episode.
  ///
  /// Walks to the next *playable* (downloaded) episode. When the current title
  /// has no further playable episode left — the user finished the last one they
  /// downloaded — it jumps to the next library entry rather than trying to
  /// stream an episode that is not on disk.
  VoidCallback? _nextPlayableEpisode(
    List<Chapter> sorted,
    int curIdx,
    List<int> playableIdx,
  ) {
    if (curIdx < 0) return null;
    for (final i in playableIdx) {
      if (i > curIdx) return () => _loadEpisodeInBanner(sorted[i]);
    }
    return _openNextLibraryEntry;
  }

  int _epNum(String? name, int fallback) {
    if (name == null || name.isEmpty) return fallback;
    // Try "Ep. N" / "Ep N" / "Episode N" pattern first
    final epMatch = RegExp(r'(?:Ep\.?|Episode)\s*(\d+)', caseSensitive: false)
        .firstMatch(name);
    if (epMatch != null) return int.tryParse(epMatch.group(1)!) ?? fallback;
    // Fall back to the LAST number in the name (avoids matching season number first)
    final all = RegExp(r'\d+').allMatches(name);
    if (all.isEmpty) return fallback;
    return int.tryParse(all.last.group(0)!) ?? fallback;
  }

  // ─── EPISODE LIST (card style with cover + shimmer) ─────────────────────────

  Widget _buildEpisodeList(List<Chapter> chapters, List<Chapter> allChapters) {
      if (chapters.isEmpty) return const SizedBox.shrink();
      const int maxVisible = 14;
      final display   = chapters.take(maxVisible).toList();
      final remaining = chapters.length - display.length;

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // "Tous" tile
            GestureDetector(
              onTap: () => _showAllEpisodesSheet(context, allChapters),
              child: Container(
                width: 48, height: 48,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _faint, width: 0.6),
                ),
                child: Center(
                  child: Text(context.l10n.media_all,
                      style: TextStyle(
                          color: _textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
                ),
              ),
            ),
            // Episode tiles
            for (int i = 0; i < display.length; i++) ...[
              _buildEpTile(display[i], fallbackIndex: i + 1),
              if (i < display.length - 1) const SizedBox(width: 8),
            ],
            // "+N more" tile
            if (remaining > 0) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showAllEpisodesSheet(context, allChapters),
                child: Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text('+$remaining',
                        style: TextStyle(
                            color: _accent, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    Widget _buildEpTile(Chapter chapter, {required int fallbackIndex}) {
      final isPlaying = _player.loadedChapterId == chapter.id;
      // Use fallbackIndex directly (sorted order) for display — avoids always showing "01"
      final epNum = fallbackIndex.toString().padLeft(2, '0');

      return GestureDetector(
        onTap: () => _loadEpisodeInBanner(chapter),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 48, height: 48,
          decoration: BoxDecoration(
            gradient: isPlaying
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _accent.withValues(alpha: 0.45),
                      _accent.withValues(alpha: 0.15),
                    ],
                  )
                : null,
            color: isPlaying ? null : _card,
            borderRadius: BorderRadius.circular(6),
            border: isPlaying
                ? Border.all(color: _accent.withValues(alpha: 0.55), width: 0.8)
                : null,
          ),
          child: Center(
            child: Text(
              epNum,
              style: TextStyle(
                color: isPlaying ? _accent : _textPrimary,
                fontSize: 15,
                fontWeight: isPlaying ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    void _showAllEpisodesSheet(BuildContext ctx, List<Chapter> allChapters) {
    final seasons = _detectSeasons(allChapters);
    // Start on the currently-selected season so the sheet matches the active filter.
    String? sheetSeason =
        (_selectedSeason != null && seasons.contains(_selectedSeason))
            ? _selectedSeason
            : (seasons.isNotEmpty ? seasons.first : null);

    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      barrierColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (sheetCtx) {
        final screen  = MediaQuery.of(ctx).size.height;
        final statusH = MediaQuery.of(ctx).padding.top;
        final maxH    = screen - 230 - statusH;
        return StatefulBuilder(
          builder: (_, setSt) {
            // Filter by selected season if any
            List<Chapter> display;
            if (sheetSeason != null) {
              final num = RegExp(r'\d+').firstMatch(sheetSeason!)?.group(0) ?? '';
              // S0? matches both "S1" and "S01"; (?!\d) prevents "S1" matching "S10"
              final rx = RegExp(
                r'(?:Saison|Season|Partie|Part)\s*' +
                    num +
                    r'\b|S0?' + num + r'(?!\d)',
                caseSensitive: false,
              );
              final filtered =
                  allChapters.where((ch) => rx.hasMatch(ch.name ?? '')).toList();
              display = filtered.isNotEmpty ? filtered : allChapters;
            } else {
              display = allChapters;
            }
            // Also filter by the currently-selected language to avoid showing
            // duplicates when the extension returns multiple language variants.
            if (_selectedLanguage != null) {
              final langFiltered =
                  display.where((ch) => _langKey(ch) == _selectedLanguage).toList();
              if (langFiltered.isNotEmpty) display = langFiltered;
            }
            // Deduplicate by episode number within the current view so that
            // remaining variants (no language selected) don't appear multiple times.
            {
              final seen = <int>{};
              final deduped = <Chapter>[];
              for (int i = 0; i < display.length; i++) {
                if (seen.add(_epNum(display[i].name, i + 1))) deduped.add(display[i]);
              }
              display = deduped;
            }

            return Container(
              height: maxH,
              decoration: BoxDecoration(color: _surface),
              child: Column(
                children: [
                  // ── Header: title + close button, separator below ──────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
                    child: Row(
                      children: [
                        Text(
                          context.l10n.media_episodes_label(display.length),
                          style: TextStyle(
                              color: _textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        if (seasons.length > 1)
                          GestureDetector(
                            onTap: () => _showDropdownSheet(
                              sheetSeason ?? seasons.first,
                              seasons,
                              (v) => setSt(() => sheetSeason = v),
                              sheetTitle: context.l10n.media_choose_season,
                              displayLabel: _seasonLabel,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: _card,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _seasonLabel(sheetSeason ?? seasons.first),
                                    style: TextStyle(
                                      color: _textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.keyboard_arrow_down_rounded,
                                      size: 18, color: _grey),
                                ],
                              ),
                            ),
                          ),
                        GestureDetector(
                          onTap: () => Navigator.pop(sheetCtx),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                                color: _card, shape: BoxShape.circle),
                            child: Icon(Broken.close_circle, size: 16, color: _grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: _faint),
                  // ── Episode grid ───────────────────────────────────────────
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        // 5 columns on narrow phones (≤ 390 pt, e.g. iPhone 7/SE),
                        // 6 on wider devices — keeps cells readable.
                        crossAxisCount:
                            MediaQuery.of(sheetCtx).size.width <= 390 ? 5 : 6,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.05,
                      ),
                      itemCount: display.length,
                      itemBuilder: (_, i) {
                        final ch = display[i];
                        final epNum = _epNum(ch.name, i + 1);
                        final label = epNum.toString().padLeft(2, '0');
                        final isWatched = ch.isRead ?? false;
                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(sheetCtx);
                            _loadEpisodeInBanner(ch);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isWatched
                                  ? _accent.withValues(alpha: 0.85)
                                  : _card,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              label,
                              style: TextStyle(
                                color: isWatched ? Colors.white : _textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── TABS ────────────────────────────────────────────────────────────────────

  Widget _buildDetailsTab(List<Chapter> chapters) {
    final manga = widget.manga;

    // ── Parse gallery images embedded in description ───────────────────────
    final rawDesc = manga.description ?? '';
    const galleryMark = '\n__GALLERY__:';
    final gIdx = rawDesc.indexOf(galleryMark);
    final description =
        gIdx >= 0 ? rawDesc.substring(0, gIdx) : rawDesc;
    final galleryUrls = gIdx >= 0
        ? rawDesc
            .substring(gIdx + galleryMark.length)
            .split('||')
            .where((u) => u.trim().isNotEmpty)
            .toList()
        : <String>[];

    // ── Cast / director from artist (extension: "Director, Actor1, Actor2, …") ──
    final _artistParts = (manga.artist ?? '').split(',')
        .map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final director  = _artistParts.isNotEmpty ? _artistParts.first : null;
    final castNames = _artistParts.length > 1 ? _artistParts.sublist(1) : <String>[];

    // ── Year from author (extension sets author = releaseYear) ───────────────
    final year = (manga.author ?? '').trim();

    // ── Country from genre list (·-prefixed by extension) ────────────────────
    final country = (manga.genre ?? []).where((g) => g.startsWith('·'))
        .map((g) => g.substring(1)).firstOrNull;

    // ── IMDb rating from description ("IMDb X.X") ────────────────────────────
    final _imdbM = RegExp(r'IMDb\s+([\d.]+)').firstMatch(description);
    final imdbRating = _imdbM?.group(1);

    // ── Status label + colour ──────────────────────────────────────────────
    String statusLabel = '';
    Color statusColor = _grey;
    switch (manga.status) {
      case Status.ongoing:
        statusLabel = context.l10n.media_status_ongoing_label;
        statusColor = const Color(0xFF22C55E);
        break;
      case Status.completed:
      case Status.publishingFinished:
        statusLabel = context.l10n.media_status_completed_label;
        statusColor = _accent;
        break;
      case Status.canceled:
        statusLabel = context.l10n.media_status_cancelled_label;
        statusColor = const Color(0xFFEF4444);
        break;
      case Status.onHiatus:
        statusLabel = context.l10n.media_status_on_hold_label;
        statusColor = const Color(0xFFF59E0B);
        break;
      default:
        break;
    }

    // ── Type keyword + clean genre list ───────────────────────────────────
    const typeKws = ['TV', 'Movie', 'Film', 'OVA', 'ONA', 'Special', 'Music'];
    final typeTag = (manga.genre ?? [])
        .where((g) => typeKws.any((k) => g.toLowerCase() == k.toLowerCase()))
        .firstOrNull;
    final genres = (manga.genre ?? [])
        .where((g) =>
            !typeKws.any((k) => g.toLowerCase() == k.toLowerCase()) &&
            !g.startsWith('·'))
        .toList();

    final isMovie = _isMovie(chapters);

    // ── Build structured info rows ─────────────────────────────────────────
    final infoRows = <_DetailInfoRow>[];
    // Année (uniquement si c'est vraiment une année numérique)
    if (year.isNotEmpty && RegExp(r'^\d{4}$').hasMatch(year)) {
      infoRows.add(
        _DetailInfoRow(
          label: context.l10n.media_year,
          value: year,
          icon: Broken.calendar,
        ),
      );
    }
    if (country != null && country.isNotEmpty) {
      infoRows.add(
        _DetailInfoRow(
          label: context.l10n.media_country,
          value: country,
          icon: Broken.global,
        ),
      );
    }
    if (imdbRating != null) {
      infoRows.add(_DetailInfoRow(
        label: context.l10n.media_rating,
        value: imdbRating,
        icon: Broken.star,
        accent: true,
        accentColor: const Color(0xFFF59E0B),
      ));
    }
    if (director != null && director.isNotEmpty) {
      infoRows.add(
        _DetailInfoRow(
          label: context.l10n.media_director,
          value: director,
          icon: Broken.user,
        ),
      );
    }
    // Nb épisodes / type
    if (chapters.isNotEmpty) {
      infoRows.add(_DetailInfoRow(
        label: isMovie ? context.l10n.media_type : context.l10n.media_episodes,
        value: isMovie ? context.l10n.media_film : '${chapters.length}',
        icon: isMovie ? Broken.video_play : Broken.play_circle,
        accent: true,
        accentColor: _accent,
      ));
    }
    // Nombre de saisons (série)
    if (!isMovie && chapters.isNotEmpty) {
      final seasons = _detectSeasons(chapters);
      infoRows.add(_DetailInfoRow(
        label: context.l10n.media_seasons,
        value: '${seasons.isEmpty ? 1 : seasons.length}',
        icon: Broken.monitor,
      ));
    }
    // Statut
    if (statusLabel.isNotEmpty) {
      infoRows.add(_DetailInfoRow(
        label: context.l10n.media_status,
        value: statusLabel,
        icon: Broken.verify,
        accent: true,
        accentColor: statusColor,
      ));
    }
    // Langue
    if (manga.lang?.isNotEmpty ?? false) {
      infoRows.add(
        _DetailInfoRow(
          label: context.l10n.media_language,
          value: manga.lang!.toUpperCase(),
          icon: Broken.global,
        ),
      );
    }
    // Format
    if (typeTag != null) {
      infoRows.add(
        _DetailInfoRow(
          label: context.l10n.media_format,
          value: typeTag,
          icon: Broken.category,
        ),
      );
    }
    // Source
    if (manga.source?.isNotEmpty ?? false) {
      infoRows.add(
        _DetailInfoRow(
          label: context.l10n.browse_create_source,
          value: manga.source!,
          icon: Broken.folder,
        ),
      );
    }


    // ── Check if truly empty ───────────────────────────────────────────────
    final hasAnyContent = description.isNotEmpty ||
        galleryUrls.isNotEmpty ||
        infoRows.isNotEmpty ||
        genres.isNotEmpty ||
        castNames.isNotEmpty;

    if (!hasAnyContent) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _card,
                  shape: BoxShape.circle,
                  border: Border.all(color: _faint, width: 1.5),
                ),
                child: Icon(Icons.info_outline_rounded, size: 30, color: _grey),
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.media_no_details,
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.l10n.media_info_pending,
                style: TextStyle(color: _grey, fontSize: 13, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 52),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Synopsis ──────────────────────────────────────────────────────
          if (description.isNotEmpty) ...[
            _sectionLabel(context.l10n.media_synopsis),
            const SizedBox(height: 10),
            StatefulBuilder(
              builder: (ctx, setSt) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSize(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeInOut,
                    child: ConstrainedBox(
                      constraints: _isDescriptionExpanded
                          ? const BoxConstraints()
                          : const BoxConstraints(maxHeight: 80),
                      child: Text(
                        description,
                        overflow: _isDescriptionExpanded
                            ? TextOverflow.visible
                            : TextOverflow.clip,
                        style: TextStyle(
                            color: _grey, fontSize: 13.5, height: 1.65),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => setSt(() =>
                        _isDescriptionExpanded = !_isDescriptionExpanded),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isDescriptionExpanded
                              ? context.l10n.catalog_card_see_less
                              : context.l10n.catalog_card_see_more,
                          style: TextStyle(
                            color: _accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 3),
                        AnimatedRotation(
                          turns: _isDescriptionExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 260),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: _accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
          ],

          // ── Aperçus / galerie ─────────────────────────────────────────────
          if (galleryUrls.isNotEmpty) ...[
            _sectionLabel(context.l10n.media_previews),
            const SizedBox(height: 10),
            SizedBox(
              height: 148,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: galleryUrls.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: cachedNetworkImage(
                    imageUrl: toImgUrl(galleryUrls[i]),
                    width: 230,
                    height: 148,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 26),
          ],

          // ── Informations — grid 2 colonnes ────────────────────────────────
          if (infoRows.isNotEmpty) ...[
            _sectionLabel(context.l10n.media_information),
            const SizedBox(height: 12),
            _buildInfoGrid(infoRows),
            const SizedBox(height: 26),
          ],

          // ── Genres ────────────────────────────────────────────────────────
          if (genres.isNotEmpty) ...[
            _sectionLabel(context.l10n.media_genres),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final g in genres)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 13, vertical: 6),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _accent.withValues(alpha: 0.25),
                          width: 0.8),
                    ),
                    child: Text(
                      g,
                      style: TextStyle(
                          color: _onSurface.withValues(alpha: 0.75),
                          fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 26),
          ],

          // ── Casting ───────────────────────────────────────────────────────
          if (castNames.isNotEmpty) ...[
            _sectionLabel(context.l10n.media_casting),
            const SizedBox(height: 12),
            SizedBox(
              height: 102,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: castNames.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (ctx, i) {
                  final name = castNames[i];
                  final initials = name
                      .split(' ')
                      .take(2)
                      .map((w) => w.isNotEmpty ? w[0] : '')
                      .join()
                      .toUpperCase();
                  final col = _castColor(i);
                  return SizedBox(
                    width: 70,
                    child: Column(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: col.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: col.withValues(alpha: 0.38),
                                width: 1.5),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initials,
                            style: TextStyle(
                              color: col,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          name,
                          style: TextStyle(
                              color: _grey,
                              fontSize: 10.5,
                              height: 1.3),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  // ── Info grid 2 colonnes ───────────────────────────────────────────────────

  Widget _buildInfoGrid(List<_DetailInfoRow> rows) {
    const hGap = 10.0;
    const vGap = 10.0;
    const cellH = 62.0;

    final rowWidgets = <Widget>[];
    for (int i = 0; i < rows.length; i += 2) {
      final left = rows[i];
      final hasRight = i + 1 < rows.length;
      final right = hasRight ? rows[i + 1] : null;

      rowWidgets.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _infoCell(left, cellH)),
            if (hasRight && right != null) ...[
              const SizedBox(width: hGap),
              Expanded(child: _infoCell(right, cellH)),
            ],
          ],
        ),
      );

      if (i + 2 < rows.length) {
        rowWidgets.add(const SizedBox(height: vGap));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rowWidgets,
    );
  }

  Widget _infoCell(_DetailInfoRow row, double h) {
    final Color bg = row.accent
        ? row.accentColor!.withValues(alpha: 0.09)
        : _card;
    final Color borderColor = row.accent
        ? row.accentColor!.withValues(alpha: 0.30)
        : _faint.withValues(alpha: 0.45);
    final Color valueColor = row.accent ? row.accentColor! : _textPrimary;
    return Container(
      height: h,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (row.icon != null) ...[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: (row.accent ? row.accentColor! : _accent)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(
                row.icon,
                size: 15,
                color: row.accent ? row.accentColor! : _accent,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  row.label,
                  style: TextStyle(
                    color: _grey,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  row.value,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _castColor(int index) {
    const colors = [
      Color(0xFF6366F1),
      Color(0xFFEC4899),
      Color(0xFF14B8A6),
      Color(0xFFF59E0B),
      Color(0xFF10B981),
      Color(0xFFEF4444),
      Color(0xFF8B5CF6),
      Color(0xFF3B82F6),
      Color(0xFFF97316),
    ];
    return colors[index % colors.length];
  }

  Widget _infoChip(IconData icon, String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withValues(alpha: 0.20), width: 0.7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon == Icons.circle)
            Container(
              width: 7,
              height: 7,
              decoration:
                  BoxDecoration(shape: BoxShape.circle, color: fg),
            )
          else
            Icon(icon, size: 12, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: TextStyle(
            color: _textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700),
      );

  Widget _detailRow(IconData icon, String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: _grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style:
                  TextStyle(color: _grey, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      );

  /// Latch kept so a manual un-gate from the tab listener (legacy builds)
  /// can never stall an already-fired request.
  bool _recommendationsRequested = false;

  /// Latched when the user opens the "Commentaires" tab, kept for parity
  /// with the manual un-gate path.
  bool _commentsRequested = false;

  Widget _buildRecommendationsTab() {
    // "Pour vous" is computed from the library, not from the network: the
    // titles the user already keeps offline share genres (thriller, adventure,
    // …) with this one, and those are what get suggested. Downloaded titles
    // rank first, so the shelf always offers something watchable.
    final recs = localRecommendationsFor(widget.manga);

    Widget _empty() => Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: _card, shape: BoxShape.circle,
                    border: Border.all(color: _faint, width: 1.5),
                  ),
                  child: Icon(Icons.movie_filter_outlined, color: _grey, size: 26),
                ),
                const SizedBox(height: 14),
                Text(context.l10n.media_no_recommendation,
                    style: TextStyle(color: _onSurface.withValues(alpha: 0.7),
                        fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Text(context.l10n.media_suggestions_here,
                    style: TextStyle(color: _grey, fontSize: 12),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        );

    if (recs.isEmpty) return _empty();

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.62,
      ),
      itemCount: recs.length,
      itemBuilder: (_, i) {
        final rec = recs[i];
        final entry = rec.manga;
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _openRecommendation(entry),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _recommendationCover(entry),
                      if (rec.downloadedEpisodes > 0)
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Broken.document_download,
                                    size: 9, color: Colors.white),
                                const SizedBox(width: 2),
                                Text(
                                  '${rec.downloadedEpisodes}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                entry.name ?? '',
                style: TextStyle(
                    color: _textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  /// The challenge panel, rendered directly over the player surface.
  ///
  /// [CloudflareBypassPanel.bounded] is set so the panel takes the height the
  /// player box gives it instead of its default 300 px, which overflowed the
  /// banner on small screens. Solving the challenge retries the same episode
  /// without leaving the screen.
  Widget _buildInlinePlayerChallenge(List<Chapter> chapters) {
    final challenge = _pendingChallenge!;
    final ordered = _sortedEpisodes(chapters);
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.72),
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Broken.shield_search, size: 16, color: Colors.orange),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Cloudflare',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _dismissChallenge,
                  behavior: HitTestBehavior.opaque,
                  child: const Icon(Icons.close_rounded,
                      size: 18, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: CloudflareBypassPanel(
                url: challenge.url,
                sourceId: challenge.sourceId ?? widget.manga.sourceId,
                compact: true,
                bounded: true,
                onResolved: () {
                  _dismissChallenge();
                  _retryLoadedEpisode(ordered);
                },
                onPageHealthy: () {
                  _dismissChallenge();
                  _retryLoadedEpisode(ordered);
                },
                onRetry: () => _retryLoadedEpisode(ordered),
                onClose: _dismissChallenge,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Inline Cloudflare bypass tab.
  ///
  /// Appears only while a refusal is pending. The panel loads the refused URL
  /// (the extension page, or the media playlist for a stream) in a real browser
  /// session, lets the user clear the challenge, persists the clearance, and
  /// then retries the current episode so playback resumes without leaving the
  /// screen.
  Widget _buildChallengeTab(List<Chapter> allChapters) {
    final challenge = _pendingChallenge!;
    final chapters = _sortedEpisodes(_filterChapters(allChapters));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Row(
          children: [
            const Icon(Broken.shield_search, size: 18, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Challenge Cloudflare',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            GestureDetector(
              onTap: _dismissChallenge,
              behavior: HitTestBehavior.opaque,
              child: Icon(Icons.close_rounded, size: 20, color: _grey),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Le site s’affiche ci-dessous : résous le défi, puis relance la '
          'lecture. Le lecteur reprendra automatiquement.',
          style: TextStyle(color: _grey, fontSize: 12, height: 1.35),
        ),
        const SizedBox(height: 12),
        CloudflareBypassPanel(
          url: challenge.url,
          sourceId: challenge.sourceId ?? widget.manga.sourceId,
          onResolved: () {
            // The challenge is beaten: drop the tab and retry the stream so the
            // player resumes on the page the user is already looking at.
            _dismissChallenge();
            _retryLoadedEpisode(chapters);
          },
          // The page loaded but no cookie was needed (MissAV's case): the tab
          // has served its purpose, close it and let the player try again.
          onPageHealthy: () {
            _dismissChallenge();
            _retryLoadedEpisode(chapters);
          },
          onRetry: () => _retryLoadedEpisode(chapters),
        ),
      ],
    );
  }


  Widget _recommendationCover(Manga entry) {
    final custom = entry.customCoverImage;
    if (custom != null && custom.isNotEmpty) {
      return Image.memory(
        Uint8List.fromList(custom),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
      );
    }
    final imageUrl = entry.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return cachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
    return Container(
      color: _card,
      child: Icon(Icons.movie_outlined, color: _grey, size: 28),
    );
  }

  /// Opens a suggested title on the episode the user last watched there.
  void _openRecommendation(Manga entry) {
    if (entry.id == null) return;
    final history = isar.historys
        .where()
        .mangaIdEqualTo(entry.id!)
        .findAllSync()
      ..sort((a, b) => (b.updatedAt ?? 0).compareTo(a.updatedAt ?? 0));
    final chapterId = history.isEmpty ? null : history.first.chapterId;
    context.push(
      '/manga-reader/detail',
      extra: MangaDetailArgs(entry.id!, resumeChapterId: chapterId),
    );
  }

  Widget _buildCommentsTab() {
    final source = getSource(
      widget.manga.lang ?? '',
      widget.manga.source ?? '',
      widget.manga.sourceId,
    );
    return _CommentsSection(
      url: widget.manga.link ?? '',
      title: widget.manga.name ?? '',
      source: source,
      accent: _accent,
      bg: _bg,
      card: _card,
      onSurface: _onSurface,
      grey: _grey,
      faint: _faint,
      textPrimary: _textPrimary,
      chapterId: _player.loadedChapterId,
      // Chargé en parallèle de la vidéo (même runtime priorisé) : pas de
      // gating sur l'état du lecteur.
      autoLoad: true,
    );
  }
  // ─── DOWNLOAD SHEET ─────────────────────────────────────────────────────────

  void _showDownloadSheet(BuildContext ctx, List<Chapter> chapters) {
    showWatchDownloadSheet(
      context: ctx,
      manga: widget.manga,
      chapters: chapters,
      onDownload: (selected) async {
        if (selected.isEmpty) return;
        // Ajout direct à la file : aucune box intermédiaire (préparation /
        // récap), la file de téléchargement affiche déjà la progression.
        try {
          for (final ch in selected) {
            await ref.read(addDownloadToQueueProvider(chapter: ch).future);
            final id = ch.id;
            if (id != null) {
              ref
                  .read(downloadQueueStateProvider.notifier)
                  .setPaused(id, false);
            }
          }
        } finally {
          ref.read(processDownloadsProvider());
        }
      },
    );
  }

  void _openInBrowser() {
    final source = getSource(
        widget.manga.lang ?? '',
        widget.manga.source ?? '',
        widget.manga.sourceId);
    if (source == null || (widget.manga.link ?? '').isEmpty) return;
    final raw = '${source.baseUrl}${widget.manga.link!.getUrlWithoutDomain}';
    context.push("/mangawebview",
        extra: {'url': raw, 'title': widget.manga.name ?? ''});
  }

  /// Full-screen, pinch-to-zoom viewer for the page artwork.
  ///
  /// The hero only allocates a 96x140 slot, so a cover whose details are worth
  /// inspecting (a pornstar portrait, a scene still) is unreadable there.
  /// [showZoomableImage] gives continuous zoom (8x), a double-tap cycle that
  /// reaches the native 1:1 rendition, and a tap-outside dismiss — matching the
  /// gallery viewer used on the reading side.
  void _openCover(BuildContext ctx, String url) {
    if (url.trim().isEmpty) return;
    final headers = ref.read(
      headersProvider(
        source: widget.manga.source ?? '',
        lang: widget.manga.lang ?? '',
        sourceId: widget.manga.sourceId,
      ),
    );
    showZoomableImage(
      ctx,
      imageProvider: ExtendedNetworkImageProvider(url, headers: headers),
      title: widget.manga.name,
    );
  }
}


// ─── COMMENT MODEL ──────────────────────────────────────────────────────────

/// One media attachment inside a comment body (image or short video). The
/// extension hands these over as plain URLs plus an optional type hint.
/// Sentinel stored when an extension comment carries no author. Kept as a
/// marker (not a word) so the fallback label is localized at render time.
const _anonymousAuthor = '\u0000anonymous';

class _CommentMedia {
  final String url;
  /// `image` or `video`; anything else falls back to `image`.
  final String kind;
  final String? thumb;

  const _CommentMedia({required this.url, this.kind = 'image', this.thumb});

  bool get isVideo => kind == 'video';
}

class _Comment {
  final String id;
  final String author;
  final String? avatarUrl;
  final String timeAgo;
  final String body;
  final List<_CommentMedia> media;
  int likes;
  bool liked;
  bool collapsed;
  final List<_Comment> replies;

  _Comment({
    required this.id,
    required this.author,
    this.avatarUrl,
    required this.timeAgo,
    required this.body,
    this.media = const [],
    this.likes = 0,
    this.liked = false,
    this.collapsed = false,
    List<_Comment>? replies,
  }) : replies = replies ?? [];

  /// Builds a comment (and its replies, recursively) from the raw map returned
  /// by an extension `getComments()`. Accepts the common key spellings so a
  /// source that names its fields differently still renders fully.
  factory _Comment.fromJson(Map<String, dynamic> m, {int depth = 0}) {
    final author = (m['author'] ?? m['name'] ?? m['user'] ?? '')
        .toString()
        .trim();
    final avatar = (m['avatar'] ?? m['avatarUrl'] ?? m['image'] ?? m['userImage'])
        ?.toString()
        .trim();
    final date = (m['date'] ?? m['time_diff'] ?? m['timeAgo'] ?? '').toString();
    final scoreVal = m['score'] ?? m['votes'] ?? m['likes'];
    final score = scoreVal is num ? scoreVal.toInt() : 0;

    final media = <_CommentMedia>[];
    void addMedia(Object? raw, [String? kind, String? thumb]) {
      if (raw is String && raw.trim().isNotEmpty) {
        media.add(_CommentMedia(
          url: raw.trim(),
          kind: kind ?? 'image',
          thumb: thumb,
        ));
      }
    }

    for (final key in const ['images', 'medias', 'attachments']) {
      final list = m[key];
      if (list is List) {
        for (final e in list) {
          if (e is Map) {
            addMedia(e['url'] ?? e['src'] ?? e['image'], e['type']?.toString());
          } else {
            addMedia(e);
          }
        }
      }
    }
    addMedia(m['imageUrl'], 'image', m['thumb']?.toString());
    addMedia(m['videoUrl'] ?? m['video'], 'video', m['thumb']?.toString());

    final replies = <_Comment>[];
    final rawReplies = m['replies'] ?? m['children'];
    if (depth < 8 && rawReplies is List) {
      for (final r in rawReplies) {
        if (r is Map) {
          replies.add(_Comment.fromJson(
            Map<String, dynamic>.from(r),
            depth: depth + 1,
          ));
        }
      }
    }

    return _Comment(
      id: '$author$date${m['id'] ?? ''}',
      author: author.isEmpty ? _anonymousAuthor : author,
      avatarUrl: (avatar == null || avatar.isEmpty) ? null : avatar,
      timeAgo: date,
      body: (m['content'] ?? m['message'] ?? m['body'] ?? '').toString().trim(),
      media: media,
      likes: score,
      replies: replies,
    );
  }
}

// ─── COMMENTS SECTION ────────────────────────────────────────────────────────

class _CommentsSection extends StatefulWidget {
  final String url;
  final String title;
  final Source? source;
  final Color accent;
  final Color bg;
  final Color card;
  final Color onSurface;
  final Color grey;
  final Color faint;
  final Color textPrimary;

  /// Episode whose comments are shown, used to read the offline cache written
  /// when the episode was downloaded.
  final int? chapterId;

  /// The comments tab is built eagerly by the TabBarView even while hidden.
  /// Fetching immediately made `getComments` occupy the source's single
  /// non-reentrant runtime before `getVideoList` could start. When false the
  /// section stays idle until the user opens the tab (or playback is ready).
  final bool autoLoad;

  const _CommentsSection({
    required this.url,
    required this.title,
    this.source,
    required this.accent,
    required this.bg,
    required this.card,
    required this.onSurface,
    required this.grey,
    required this.faint,
    required this.textPrimary,
    this.chapterId,
    this.autoLoad = true,
  });

  @override
  State<_CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<_CommentsSection> {
  List<_Comment> _comments = [];
  bool _loading = true;
  String? _replyingToId;
  final _replyController = TextEditingController();
  final _commentController = TextEditingController();
  bool _sortByBest = true;
  @override
  void initState() {
    super.initState();
    if (widget.autoLoad) _loadComments();
  }

  @override
  void didUpdateWidget(_CommentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoLoad && !oldWidget.autoLoad && _comments.isEmpty) {
      _loadComments();
    }
  }

  @override
  void dispose() {
    _replyController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() { _loading = true; });
    final src = widget.source;
    if (src == null) {
      if (!mounted) return;
      setState(() { _comments = []; _loading = false; });
      return;
    }
    final cached = widget.chapterId == null
        ? null
        : await readWatchComments(widget.title, widget.chapterId!);
    try {
      final raw = await getIsolateService.get<List<dynamic>>(
        url: widget.url, source: src,
        serviceType: 'getComments',
      );
      if (!mounted) return;
      final mapped = raw
          .whereType<Map>()
          .map((e) => _Comment.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      setState(() {
        _comments = mapped.isEmpty ? _fromCache(cached) : mapped;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        // Offline: a downloaded episode carries the comments captured at
        // download time, so the tab is not empty for content on disk.
        _comments = _fromCache(cached);
        _loading = false;
      });
    }
  }

  List<_Comment> _fromCache(List<dynamic>? cached) => (cached ?? const [])
      .whereType<Map>()
      .map((e) => _Comment.fromJson(Map<String, dynamic>.from(e)))
      .toList();


  void _toggleLike(_Comment comment) {
    setState(() {
      if (comment.liked) {
        comment.likes--;
        comment.liked = false;
      } else {
        comment.likes++;
        comment.liked = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              strokeWidth: 2,
              color: widget.accent,
            ),
            const SizedBox(height: 12),
            Text(context.l10n.media_loading_comments,
                style: TextStyle(color: widget.grey, fontSize: 13)),
          ],
        ),
      );
    }

    final total = _comments.fold<int>(
      0, (sum, c) => sum + 1 + c.replies.fold<int>(0, (s, r) => s + 1 + r.replies.length));

    return Column(
      children: [
        // Header bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Text(
                context.l10n.media_comments_count(total),
                style: TextStyle(
                  color: widget.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _sortByBest = !_sortByBest;
                    if (_sortByBest) {
                      _comments.sort((a, b) => b.likes.compareTo(a.likes));
                    } else {
                      _comments.sort((a, b) => b.timeAgo.compareTo(a.timeAgo));
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.card,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: widget.faint, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sort_rounded, size: 13, color: widget.grey),
                      const SizedBox(width: 4),
                      Text(
                        _sortByBest
                            ? context.l10n.media_best
                            : context.l10n.media_recent,
                        style: TextStyle(color: widget.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Write comment bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: GestureDetector(
            onTap: () => _showWriteCommentSheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: widget.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: widget.faint, width: 0.8),
              ),
              child: Row(
                children: [
                  _CommentAvatar(
                    author: context.l10n.media_me,
                    size: 26,
                    accent: widget.accent,
                    isLight: false,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    context.l10n.media_add_comment,
                    style: TextStyle(color: widget.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
        Divider(height: 1, color: widget.faint),
        // Comment list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: _comments.length,
            itemBuilder: (ctx, i) => _CommentTile(
              comment: _comments[i],
              depth: 0,
              accent: widget.accent,
              bg: widget.bg,
              card: widget.card,
              grey: widget.grey,
              faint: widget.faint,
              textPrimary: widget.textPrimary,
              onLike: _toggleLike,
              onReply: (c) => _showWriteCommentSheet(context, replyTo: c),
              onCollapse: (_) => setState(() {}),
            ),
          ),
        ),
      ],
    );
  }

  void _showWriteCommentSheet(BuildContext ctx, {_Comment? replyTo}) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          decoration: BoxDecoration(
            color: widget.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: widget.faint,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (replyTo != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: widget.card,
                      borderRadius: BorderRadius.circular(8),
                      border: Border(left: BorderSide(color: widget.accent, width: 3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          replyTo.author,
                          style: TextStyle(
                            color: widget.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          replyTo.body,
                          style: TextStyle(color: widget.grey, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _CommentAvatar(
                      author: context.l10n.media_me,
                      size: 32,
                      accent: widget.accent,
                      isLight: false,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: ctrl,
                        autofocus: true,
                        maxLines: 4,
                        minLines: 1,
                        style: TextStyle(color: widget.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: replyTo != null
                              ? context.l10n.media_reply_to(replyTo.author)
                              : context.l10n.media_your_comment,
                          hintStyle: TextStyle(color: widget.grey),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        final text = ctrl.text.trim();
                        if (text.isEmpty) return;
                        setState(() {
                          if (replyTo != null) {
                            replyTo.replies.add(_Comment(
                              id: 'new_${DateTime.now().millisecondsSinceEpoch}',
                              author: context.l10n.media_me,
                              timeAgo: context.l10n.media_just_now,
                              body: text,
                            ));
                          } else {
                            _comments.insert(0, _Comment(
                              id: 'new_${DateTime.now().millisecondsSinceEpoch}',
                              author: context.l10n.media_me,
                              timeAgo: context.l10n.media_just_now,
                              body: text,
                            ));
                          }
                        });
                        Navigator.pop(sheetCtx);
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: widget.accent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── COMMENT TILE (recursive) ────────────────────────────────────────────────

class _CommentTile extends StatelessWidget {
  final _Comment comment;
  final int depth;
  final Color accent;
  final Color bg;
  final Color card;
  final Color grey;
  final Color faint;
  final Color textPrimary;
  final void Function(_Comment) onLike;
  final void Function(_Comment) onReply;
  final void Function(_Comment) onCollapse;

  static const _kDepthColors = [
    Color(0xFF6366F1),
    Color(0xFF14B8A6),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
    Color(0xFF10B981),
  ];

  const _CommentTile({
    required this.comment,
    required this.depth,
    required this.accent,
    required this.bg,
    required this.card,
    required this.grey,
    required this.faint,
    required this.textPrimary,
    required this.onLike,
    required this.onReply,
    required this.onCollapse,
  });

  Color get _threadColor => _kDepthColors[depth % _kDepthColors.length];

  @override
  Widget build(BuildContext context) {
    final indent = depth * 16.0;
    final authorName = comment.author == _anonymousAuthor
        ? context.l10n.media_anonymous
        : comment.author;
    return Padding(
      padding: EdgeInsets.only(left: indent, top: depth == 0 ? 12 : 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thread line + content
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Thread line (only for replies)
                if (depth > 0) ...[
                  GestureDetector(
                    onTap: () {
                      comment.collapsed = !comment.collapsed;
                      onCollapse(comment);
                    },
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: _threadColor.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(width: 16),
                ],
                // Comment body
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: 16, bottom: depth == 0 ? 0 : 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Author row
                        Row(
                          children: [
                            _CommentAvatar(
                              author: authorName,
                              avatarUrl: comment.avatarUrl,
                              size: depth == 0 ? 30 : 24,
                              accent: _threadColor,
                              isLight: false,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Row(
                                children: [
                                  Text(
                                    authorName,
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: depth == 0 ? 13 : 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    comment.timeAgo,
                                    style: TextStyle(color: grey, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            // Collapse toggle
                            GestureDetector(
                              onTap: () {
                                comment.collapsed = !comment.collapsed;
                                onCollapse(comment);
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  comment.collapsed
                                      ? Icons.expand_more_rounded
                                      : Icons.expand_less_rounded,
                                  color: grey,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!comment.collapsed) ...[
                          const SizedBox(height: 6),
                          // Body
                          if (comment.body.isNotEmpty)
                            Text(
                              comment.body,
                              style: TextStyle(
                                color: textPrimary.withValues(alpha: 0.88),
                                fontSize: 13.5,
                                height: 1.45,
                              ),
                            ),
                          // Attached images / videos
                          if (comment.media.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _CommentMediaGrid(
                              media: comment.media,
                              accent: _threadColor,
                              faint: faint,
                            ),
                          ],
                          const SizedBox(height: 8),
                          // Action bar
                          Row(
                            children: [
                              // Like
                              GestureDetector(
                                onTap: () => onLike(comment),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      comment.liked
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      color: comment.liked ? const Color(0xFFEF4444) : grey,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${comment.likes}',
                                      style: TextStyle(
                                        color: comment.liked ? const Color(0xFFEF4444) : grey,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Reply
                              GestureDetector(
                                onTap: () => onReply(comment),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.reply_rounded, color: grey, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      context.l10n.media_reply,
                                      style: TextStyle(color: grey, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Replies count badge
                              if (comment.replies.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _threadColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: _threadColor.withValues(alpha: 0.30), width: 0.7),
                                  ),
                                  child: Text(
                                    context.l10n.media_replies_count(
                                      comment.replies.length,
                                    ),
                                    style: TextStyle(
                                      color: _threadColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          // Divider for top-level comments
                          if (depth == 0 && comment.replies.isEmpty) ...[
                            const SizedBox(height: 12),
                            Divider(height: 1, color: faint),
                          ],
                        ] else ...[
                          const SizedBox(height: 4),
                          Text(
                            context.l10n.media_replies_hidden(
                              comment.replies.length,
                            ),
                            style: TextStyle(color: grey, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Nested replies
          if (!comment.collapsed)
            for (final reply in comment.replies)
              _CommentTile(
                comment: reply,
                depth: depth + 1,
                accent: accent,
                bg: bg,
                card: card,
                grey: grey,
                faint: faint,
                textPrimary: textPrimary,
                onLike: onLike,
                onReply: onReply,
                onCollapse: onCollapse,
              ),
          // Separator for top-level with replies
          if (depth == 0 && comment.replies.isNotEmpty && !comment.collapsed)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Divider(height: 1, color: faint),
            ),
        ],
      ),
    );
  }
}

// ─── COMMENT MEDIA ───────────────────────────────────────────────────────────

/// Renders the images/videos attached to a comment. A single item shows as a
/// large preview; several show as a compact two-column grid, mirroring the
/// Reddit comment layout.
class _CommentMediaGrid extends StatelessWidget {
  final List<_CommentMedia> media;
  final Color accent;
  final Color faint;

  const _CommentMediaGrid({
    required this.media,
    required this.accent,
    required this.faint,
  });

  @override
  Widget build(BuildContext context) {
    final single = media.length == 1;
    return LayoutBuilder(
      builder: (context, constraints) {
        final fullWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width - 80;
        final itemWidth = single ? fullWidth : (fullWidth - 6) / 2;
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final m in single ? media : media.take(4))
              SizedBox(
                width: itemWidth,
                child: _CommentMediaThumb(media: m, accent: accent, faint: faint),
              ),
          ],
        );
      },
    );
  }
}

class _CommentMediaThumb extends StatelessWidget {
  final _CommentMedia media;
  final Color accent;
  final Color faint;

  const _CommentMediaThumb({
    required this.media,
    required this.accent,
    required this.faint,
  });

  @override
  Widget build(BuildContext context) {
    final previewUrl =
        media.thumb != null && media.thumb!.isNotEmpty ? media.thumb! : media.url;
    return GestureDetector(
      onTap: () => _open(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              cachedNetworkImage(
                imageUrl: previewUrl,
                width: null,
                height: null,
                fit: BoxFit.cover,
                errorWidget: Container(
                  color: faint,
                  child: Icon(
                    media.isVideo
                        ? Icons.videocam_off_outlined
                        : Icons.image_not_supported_outlined,
                    color: accent,
                    size: 22,
                  ),
                ),
              ),
              if (media.isVideo)
                Center(
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    if (media.isVideo) {
      showDialog<void>(
        context: context,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        builder: (dialogContext) => GestureDetector(
          onTap: () => Navigator.of(dialogContext).pop(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_circle_outline_rounded,
                      color: Colors.white, size: 64),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.media_comment_video,
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    media.url,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return;
    }
    // Same continuous zoom as the page artwork: `InteractiveViewer` capped the
    // scale at 5x with no double-tap shortcut, which felt stiff on a still.
    showZoomableImage(
      context,
      imageProvider: ExtendedNetworkImageProvider(media.url),
    );
  }
}

// ─── COMMENT AVATAR ──────────────────────────────────────────────────────────

class _CommentAvatar extends StatelessWidget {
  final String author;
  final String? avatarUrl;
  final double size;
  final Color accent;
  final bool isLight;

  const _CommentAvatar({
    required this.author,
    this.avatarUrl,
    required this.size,
    required this.accent,
    required this.isLight,
  });

  @override
  Widget build(BuildContext context) {
    final border = Border.all(color: accent.withValues(alpha: 0.40), width: 1.5);
    final url = avatarUrl;
    if (url != null && url.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: accent.withValues(alpha: 0.18),
          border: border,
        ),
        clipBehavior: Clip.antiAlias,
        child: cachedNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorWidget: _initials(),
        ),
      );
    }
    return _initials(border);
  }

  Widget _initials([BoxBorder? border]) {
    final initials = author.isEmpty
        ? '?'
        : author.trim().split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').take(2).join();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withValues(alpha: 0.18),
        border: border ?? Border.all(color: accent.withValues(alpha: 0.40), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: accent,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─── ANIMATED TAB INDICATOR ─────────────────────────────────────────────────

class _AnimatedTabIndicator extends Decoration {
  final Color color;
  const _AnimatedTabIndicator({required this.color});

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _AnimatedTabIndicatorPainter(color: color, onChanged: onChanged);
}

class _AnimatedTabIndicatorPainter extends BoxPainter {
  final Color color;
  _AnimatedTabIndicatorPainter({required this.color, VoidCallback? onChanged})
      : super(onChanged);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration cfg) {
    if (cfg.size == null) return;
    final rect = offset & cfg.size!;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    const h = 3.0;
    const r = 1.5;
    final bar = Rect.fromLTWH(
      rect.left + 4,
      rect.bottom - h,
      rect.width - 8,
      h,
    );
    canvas.drawRRect(
        RRect.fromRectAndRadius(bar, const Radius.circular(r)), paint);
  }
}

// ─── SLIVER TAB BAR DELEGATE ────────────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color color;

  const _TabBarDelegate(this.tabBar, {this.color = Colors.black});

  @override
  double get minExtent => tabBar.preferredSize.height + 1;
  @override
  double get maxExtent => tabBar.preferredSize.height + 1;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) =>
      ColoredBox(
        color: color,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            tabBar,
            Container(height: 1, color: const Color(0xFF2a2a2a)),
          ],
        ),
      );

  @override
  bool shouldRebuild(_TabBarDelegate old) =>
      old.tabBar != tabBar || old.color != color;
}

// ─── Generic shimmer skeleton box ─────────────────────────────────────────────

class _SkeletonBox extends StatefulWidget {
  final double radius;
  final double? w;
  final double? h;
  final double? aspect;   // aspect ratio when w/h are null

  const _SkeletonBox({this.radius = 8, this.w, this.h, this.aspect});

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.06, end: 0.18).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white : Colors.black;

    Widget box = AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => Container(
        width: widget.w,
        height: widget.h,
        decoration: BoxDecoration(
          color: baseColor.withValues(alpha: _anim.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );

    if (widget.aspect != null) {
      box = AspectRatio(aspectRatio: widget.aspect!, child: box);
    }
    return box;
  }
}

// ─── Pulsing loading overlay for the banner ────────────────────────────────────

class _LoadingBannerPulse extends StatelessWidget {
  const _LoadingBannerPulse();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: _ThreeDotsAnimation(),
          ),
        ),
      ),
    );
  }
}

// ─── 3 jumping dots animation ─────────────────────────────────────────────────

class _ThreeDotsAnimation extends StatefulWidget {
  const _ThreeDotsAnimation();

  @override
  State<_ThreeDotsAnimation> createState() => _ThreeDotsAnimationState();
}

class _ThreeDotsAnimationState extends State<_ThreeDotsAnimation>
    with TickerProviderStateMixin {
  final List<AnimationController> _ctrls = [];
  final List<Animation<double>> _anims = [];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 3; i++) {
      final c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      );
      _ctrls.add(c);
      _anims.add(Tween<double>(begin: 0, end: -9).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      ));
      Future.delayed(Duration(milliseconds: i * 140), () {
        if (mounted) c.repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _anims[i],
          builder: (_, _) => Transform.translate(
            offset: Offset(0, _anims[i].value),
            child: Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }),
    );
  }

}
// ── Data class for detail info grid rows ─────────────────────────────────────

class _DetailInfoRow {
  final String label;
  final String value;
  final IconData? icon;
  final bool accent;
  final Color? accentColor;

  const _DetailInfoRow({
    required this.label,
    required this.value,
    this.icon,
    this.accent = false,
    this.accentColor,
  });
}

/// A single fact shown in the Info sheet's 3-column grid.
class _SheetInfoCell {
  final IconData icon;
  final String label;
  final String value;
  final bool accent;
  final Color? accentColor;

  const _SheetInfoCell({
    required this.icon,
    required this.label,
    required this.value,
    this.accent = false,
    this.accentColor,
  });
}

// ─── In-player toast (bottom of the video surface) ───────────────────────────

class _PlayerToast extends StatelessWidget {
  final String message;

  const _PlayerToast({required this.message});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Broken.info_circle, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Player failure overlay (Lottie error + retry) ───────────────────────────

class _PlayerFailureOverlay extends StatelessWidget {
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  /// When set, an extra "Battre le challenge" action is offered: the load
  /// failure is a Cloudflare refusal, so the user is taken straight to the
  /// inline bypass panel instead of only being told the load failed.
  final VoidCallback? onChallenge;

  const _PlayerFailureOverlay({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
    this.onChallenge,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                'assets/animations/error.json',
                width: 96,
                height: 96,
                fit: BoxFit.contain,
                repeat: true,
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              if (onChallenge != null) ...[
                GestureDetector(
                  onTap: onChallenge,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade700,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Broken.shield_search,
                            color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Battre le challenge',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Broken.refresh, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        retryLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
