import 'dart:async';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:watchtower/modules/onboarding/onboarding_fallback_catalog.dart';
import 'package:watchtower/modules/onboarding/onboarding_media_service.dart';
import 'package:watchtower/modules/onboarding/onboarding_showcase_config.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:watchtower/services/device_capabilities.dart';
import 'package:watchtower/services/onboarding_dependency_service.dart';
import 'package:watchtower/utils/cached_network.dart';

const String _onboardingMarkerFileName = '.onboarding_complete';

Future<File> _markerFile() async {
  final dir = await getApplicationSupportDirectory();
  return File('${dir.path}/$_onboardingMarkerFileName');
}

Future<bool> onboardingIsComplete() async {
  if (kIsWeb) return true;
  try {
    return (await _markerFile()).existsSync();
  } catch (_) {
    return false;
  }
}

Future<void> markOnboardingComplete() async {
  try {
    final f = await _markerFile();
    await f.create(recursive: true);
    await f.writeAsString('done');
  } catch (_) {}
}

// ─────────────────────────────────────────────────────────────────────────────
// OnboardingScreen (showcase → slogan → automatic language → dependencies → permissions)
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with WidgetsBindingObserver {
  final _page = PageController();
  int _currentPage = 0;

  // ── Required permissions ──────────────────────────────────────────────────
  bool _storageGranted = false;
  bool _notifGranted = false;
  bool _installGranted = false;
  bool _busyStorage = false;
  bool _busyNotif = false;
  bool _busyInstall = false;

  // ── Optional permissions ──────────────────────────────────────────────────
  bool _overlayGranted  = false; // PiP / draw-over-other-apps
  bool _busyOverlay     = false;
  bool _batteryGranted  = false; // Exempt from battery optimisation (Android)
  bool _busyBattery     = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    if (kIsWeb) {
      return;
    }
    if (!Platform.isAndroid && !Platform.isIOS) {
      if (mounted) {
        setState(() {
          _storageGranted = true;
          _notifGranted = true;
          _installGranted = true;
          _overlayGranted = true;
        });
      }
      return;
    }
    if (Platform.isIOS) {
      // iOS: storage is always accessible via sandbox; install & overlay are N/A.
      final n = await Permission.notification.status;
      if (!mounted) return;
      setState(() {
        _storageGranted = true;
        _notifGranted = n.isGranted;
        _installGranted = true;
        _overlayGranted = true;
      });
      return;
    }
    // Android
    final s = await Permission.manageExternalStorage.status;
    final legacyStorage = await Permission.storage.status;
    final n = await Permission.notification.status;
    final i = await Permission.requestInstallPackages.status;
    final o = await Permission.systemAlertWindow.status;
    final b = await Permission.ignoreBatteryOptimizations.status;
    if (!mounted) return;
    setState(() {
      _storageGranted = s.isGranted || legacyStorage.isGranted;
      _notifGranted   = n.isGranted;
      _installGranted = i.isGranted;
      _overlayGranted = o.isGranted;
      _batteryGranted = b.isGranted;
    });
  }

  // ── Permission requests ──────────────────────────────────────────────────

  Future<void> _reqStorage() async {
    if (_busyStorage) return;
    setState(() => _busyStorage = true);
    bool granted = false;
    try {
      granted = await StorageProvider().requestPermission();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _storageGranted = granted;
      _busyStorage = false;
    });
  }

  Future<void> _reqNotif() async {
    if (_busyNotif) return;
    setState(() => _busyNotif = true);
    bool granted = false;
    try {
      if (kIsWeb) {
        granted = true;
      } else {
        final status = await Permission.notification.status;
        if (status.isPermanentlyDenied) {
          await openAppSettings();
          final updated = await Permission.notification.status;
          granted = updated.isGranted;
        } else {
          final result = await Permission.notification.request();
          granted = result.isGranted;
        }
      }
    } catch (_) {
      granted = kIsWeb;
    }
    if (!mounted) return;
    setState(() {
      _notifGranted = granted;
      _busyNotif = false;
    });
  }

  Future<void> _reqInstall() async {
    if (_busyInstall) return;
    setState(() => _busyInstall = true);
    bool granted = false;
    try {
      if (kIsWeb) {
        granted = true;
      } else if (!kIsWeb && Platform.isAndroid) {
        final status = await Permission.requestInstallPackages.status;
        if (status.isPermanentlyDenied) {
          await openAppSettings();
          final updated = await Permission.requestInstallPackages.status;
          granted = updated.isGranted;
        } else {
          final result = await Permission.requestInstallPackages.request();
          granted = result.isGranted;
        }
      } else {
        granted = true;
      }
    } catch (_) {
      granted = kIsWeb;
    }
    if (!mounted) return;
    setState(() {
      _installGranted = granted;
      _busyInstall = false;
    });
  }

  Future<void> _reqOverlay() async {
    if (_busyOverlay) return;
    setState(() => _busyOverlay = true);
    bool granted = false;
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final status = await Permission.systemAlertWindow.status;
        if (status.isPermanentlyDenied) {
          await openAppSettings();
          granted = (await Permission.systemAlertWindow.status).isGranted;
        } else {
          final result = await Permission.systemAlertWindow.request();
          granted = result.isGranted;
        }
      } else {
        granted = true;
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _overlayGranted = granted;
      _busyOverlay = false;
    });
  }

  Future<void> _reqBattery() async {
    if (_busyBattery) return;
    setState(() => _busyBattery = true);
    bool granted = false;
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final status = await Permission.ignoreBatteryOptimizations.status;
        if (status.isPermanentlyDenied) {
          await openAppSettings();
          final updated = await Permission.ignoreBatteryOptimizations.status;
          granted = updated.isGranted;
        } else {
          final result = await Permission.ignoreBatteryOptimizations.request();
          granted = result.isGranted;
        }
      } else {
        granted = true;
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _batteryGranted = granted;
      _busyBattery = false;
    });
  }

  // ── Navigation ───────────────────────────────────────────────────────────

  void _next() {
    if (_currentPage < 2) {
      _page.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finish() async {
    await markOnboardingComplete();
    if (mounted) context.go('/MangaLibrary');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            PageView(
              controller: _page,
              onPageChanged: (i) => setState(() => _currentPage = i),
              children: [
                // Only the visible page animates. A `PageView` builds and keeps
                // its neighbours, so without this the slogan backdrop kept
                // ticking behind the showcase (and vice versa), doubling the
                // per-frame cost of a screen that only ever shows one page.
                TickerMode(
                  enabled: _currentPage == 0,
                  child: _ShowcasePage(onNext: _next),
                ),
                TickerMode(
                  enabled: _currentPage == 1,
                  child: _SloganPage(onNext: _next),
                ),
                _PermissionsPage(
                  storageGranted: _storageGranted,
                  notifGranted: _notifGranted,
                  installGranted: _installGranted,
                  overlayGranted: _overlayGranted,
                  batteryGranted: _batteryGranted,
                  busyStorage: _busyStorage,
                  busyNotif: _busyNotif,
                  busyInstall: _busyInstall,
                  busyOverlay: _busyOverlay,
                  busyBattery: _busyBattery,
                  onStorage: _reqStorage,
                  onNotif: _reqNotif,
                  onInstall: _reqInstall,
                  onOverlay: _reqOverlay,
                  onBattery: _reqBattery,
                  onFinish: _finish,
                ),
              ],
            ),
            // Page indicator dots
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) {
                      final active = i == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: active ? 22 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data — the lanes below are filled by `OnboardingMediaService` from the real
// catalogues (AniList, TMDB, Apple Music, Steam) and fall back to
// `OnboardingFallbackCatalog` posters until — or if — a source answers. Every
// card therefore shows a real cover and the real figure the source publishes.
// ─────────────────────────────────────────────────────────────────────────────

/// One category lane: its label, its accent colour, its icon and its content.
class ShowcaseLaneSpec {
  const ShowcaseLaneSpec({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.items,
  });

  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final List<ShowcaseItem> items;

  ShowcaseLaneSpec withItems(List<ShowcaseItem> value) => ShowcaseLaneSpec(
    id: id,
    label: label,
    icon: icon,
    color: color,
    items: value,
  );
}

/// The seven lanes, wired to the live catalogues.
///
/// Built once: the label, icon and colour are fixed, only [items] changes when
/// a source lands.
final List<ShowcaseLaneSpec> _laneSpecs = [
  ShowcaseLaneSpec(
    id: 'anime',
    label: 'Anime',
    icon: Icons.live_tv_rounded,
    color: const Color(0xFFFF6B00),
    items: OnboardingFallbackCatalog.anime,
  ),
  ShowcaseLaneSpec(
    id: 'manga',
    label: 'Manga',
    icon: Icons.menu_book_rounded,
    color: const Color(0xFF9D4EDD),
    items: OnboardingFallbackCatalog.manga,
  ),
  ShowcaseLaneSpec(
    id: 'novels',
    label: 'Novels',
    icon: Icons.auto_stories_rounded,
    color: const Color(0xFF06D6A0),
    items: OnboardingFallbackCatalog.novels,
  ),
  ShowcaseLaneSpec(
    id: 'music',
    label: 'Musique',
    icon: Icons.music_note_rounded,
    color: const Color(0xFF3A86FF),
    items: OnboardingFallbackCatalog.music,
  ),
  ShowcaseLaneSpec(
    id: 'series',
    label: 'Séries',
    icon: Icons.theaters_rounded,
    color: const Color(0xFFE63946),
    items: OnboardingFallbackCatalog.series,
  ),
  ShowcaseLaneSpec(
    id: 'films',
    label: 'Films',
    icon: Icons.movie_rounded,
    color: const Color(0xFFFF9F1C),
    items: OnboardingFallbackCatalog.films,
  ),
  ShowcaseLaneSpec(
    id: 'games',
    label: 'Jeux',
    icon: Icons.sports_esports_rounded,
    color: const Color(0xFF00C2A8),
    items: OnboardingFallbackCatalog.games,
  ),
];

/// The lanes the media service is asked to fill.
List<ShowcaseLane> get _laneRequests => [
  for (final spec in _laneSpecs)
    ShowcaseLane(id: spec.id, label: spec.label, fallback: spec.items),
];

/// The content a lane currently has: the live result once cached, else the
/// curated posters.
List<ShowcaseItem> _itemsFor(ShowcaseLaneSpec spec) =>
    OnboardingMediaService.cached(spec.id) ?? spec.items;

/// Flat pool for the slogan page, capped so the diagonal backdrop never builds
/// more than the configured budget of cards.
List<ShowcaseItem> _poolFor(int limit) {
  final out = <ShowcaseItem>[];
  // Interleave categories so a capped pool still shows every kind of content
  // instead of eight anime posters.
  for (var i = 0; out.length < limit; i++) {
    var added = false;
    for (final spec in _laneSpecs) {
      final items = _itemsFor(spec);
      if (i < items.length) {
        out.add(items[i]);
        added = true;
        if (out.length >= limit) break;
      }
    }
    if (!added) break;
  }
  return out;
}

// ─────────────────────────────────────────────────────────────────────────────
// Page 1 — Showcase
// Three columns of poster cards drift continuously; the window slides one lane
// at a time so all seven categories pass through. ONE shared AnimationController
// keeps all three lanes frame-perfectly in sync.
// ─────────────────────────────────────────────────────────────────────────────

class _ShowcasePage extends StatefulWidget {
  final VoidCallback onNext;
  const _ShowcasePage({required this.onNext});
  @override
  State<_ShowcasePage> createState() => _ShowcasePageState();
}

class _ShowcasePageState extends State<_ShowcasePage>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _service = OnboardingMediaService();
  Timer? _rotate;
  int _window = 0;

  /// Live lane content, keyed by lane id. Falls back to the curated posters
  /// for any lane the catalogues have not answered for yet.
  late List<ShowcaseLaneSpec> _lanes;

  @override
  void initState() {
    super.initState();
    _lanes = _laneSpecs;
    _ctrl = AnimationController(
      vsync: this,
      duration: OnboardingShowcaseConfig.laneCycle,
    );
    _ctrl.repeat();
    _loadLiveContent();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honour the platform's "reduce motion" setting: a user who asked for
    // stillness gets a still showcase, and a slow phone gets a page that stops
    // driving frames instead of one that keeps a ticker alive forever.
    final reduce = showcaseMotionDisabled(context);
    if (reduce) {
      _rotate?.cancel();
      if (_ctrl.isAnimating) _ctrl.stop();
    } else {
      if (!_ctrl.isAnimating) _ctrl.repeat();
      _rotate ??= Timer.periodic(OnboardingShowcaseConfig.windowRotate, (_) {
        if (!mounted) return;
        setState(() => _window = (_window + 1) % _lanes.length);
      });
    }
  }

  Future<void> _loadLiveContent() async {
    await _service.loadAll(
      _laneRequests,
      onLane: (laneId, items) {
        if (!mounted) return;
        setState(() {
          _lanes = [
            for (final spec in _lanes)
              spec.id == laneId ? spec.withItems(items) : spec,
          ];
        });
      },
    );
  }

  @override
  void dispose() {
    _rotate?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  List<ShowcaseLaneSpec> _visible() => [
    for (var i = 0; i < _lanesOnScreen; i++)
      _lanes[(_window + i) % _lanes.length],
  ];

  /// How many lanes fit the current screen. Computed from the width so a
  /// tablet or a desktop window shows more columns instead of stretching
  /// three of them across the whole window.
  int get _lanesOnScreen =>
      OnboardingShowcaseConfig.laneCountFor(MediaQuery.sizeOf(context).width);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final lanes = _visible();
    final laneWidth = OnboardingShowcaseConfig.laneWidthFor(width);
    final contentWidth = OnboardingShowcaseConfig.contentWidthFor(width);
    final cardHeight = OnboardingShowcaseConfig.cardHeightFor(laneWidth);

    // A low-RAM phone builds fewer cards, and shadows are dropped there and on
    // the slogan page where the gradient hides them anyway.
    final ramTier = deviceRamTierFromMB(DeviceCapabilities.physicalMemoryMB);
    final constrained = ramTier == DeviceRamTier.low;
    final itemsPerLane = OnboardingShowcaseConfig.itemsPerLaneFor(ramTier);
    final shadows = OnboardingShowcaseConfig.shadowsEnabled(
      ramConstrained: constrained,
      covered: false,
    );

    return Stack(
      children: [
        // ── Card lanes, ALL sharing _ctrl → strictly synchronized ───────
        Positioned.fill(
          child: Center(
            child: SizedBox(
              width: contentWidth,
              child: AnimatedSwitcher(
                duration: OnboardingShowcaseConfig.windowSwitch,
                child: Row(
                  key: ValueKey(_window),
                  children: [
                    for (var i = 0; i < lanes.length; i++)
                      RepaintBoundary(
                        child: _Lane(
                          animation: _ctrl,
                          lane: lanes[i],
                          goUp: i.isEven,
                          width: laneWidth,
                          cardHeight: cardHeight,
                          maxItems: itemsPerLane,
                          shadows: shadows,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Gradient vignette — top & bottom fade ───────────────────────
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black,
                    Colors.black.withValues(alpha: 0),
                    Colors.black.withValues(alpha: 0),
                    Colors.black.withValues(alpha: 0.88),
                    Colors.black,
                  ],
                  stops: const [0.0, 0.15, 0.52, 0.80, 1.0],
                ),
              ),
            ),
          ),
        ),

        // ── Bottom text + button ────────────────────────────────────────
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: OnboardingShowcaseConfig.maxContentWidth,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 60),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Watchtower',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.8,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Category chips — the whole point: the app is not only
                      // films and series, every category below lives in it.
                      _CategoryChips(active: lanes.map((l) => l.label).toSet()),
                      const SizedBox(height: 12),
                      Text(
                        'Anime, manga, novels, musique,\nfilms, séries et jeux — au même endroit.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 16,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _WhiteButton(label: 'Suivant', onTap: widget.onNext),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Row of pills for every category, highlighting the ones currently on screen.
class _CategoryChips extends StatelessWidget {
  final Set<String> active;
  const _CategoryChips({required this.active});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: _laneSpecs.map((lane) {
        final on = active.contains(lane.label);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: on
                ? lane.color.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: on
                  ? lane.color.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                lane.icon,
                size: 13,
                color: on ? lane.color : Colors.white.withValues(alpha: 0.45),
              ),
              const SizedBox(width: 5),
              Text(
                lane.label,
                style: TextStyle(
                  color: on ? Colors.white : Colors.white.withValues(alpha: 0.45),
                  fontSize: 11.5,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page 2 — Slogan
// Diagonal lanes (top-right → bottom-left) with slogan text overlay. Lanes are
// taken from `_lanes` with a per-column offset so a column keeps one category
// while its content differs from its neighbour.
// ─────────────────────────────────────────────────────────────────────────────

class _SloganPage extends StatefulWidget {
  final VoidCallback onNext;
  const _SloganPage({required this.onNext});
  @override
  State<_SloganPage> createState() => _SloganPageState();
}

class _SloganPageState extends State<_SloganPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: OnboardingShowcaseConfig.sloganCycle,
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = showcaseMotionDisabled(context);
    if (reduce && _ctrl.isAnimating) {
      _ctrl.stop();
    } else if (!reduce && !_ctrl.isAnimating) {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // Wider + taller than screen so the rotated block still covers it.
    final diagonal = math.sqrt(
            size.width * size.width + size.height * size.height)
        .ceil()
        .toDouble();

    final laneCount = OnboardingShowcaseConfig.sloganLaneCountFor(size.width);
    final itemsPerLane = OnboardingShowcaseConfig.sloganItemsPerLaneFor(
      size.width,
    );
    final laneW = OnboardingShowcaseConfig.laneWidthFor(size.width);
    final cardHeight = OnboardingShowcaseConfig.cardHeightFor(laneW);

    // The pool is capped: this page rotates dozens of cards behind the text
    // where they are decorative and largely covered by the overlay, and an
    // uncapped pool is what made it drop frames on a phone.
    final pool = _poolFor(itemsPerLane * laneCount);

    return Stack(
      children: [
        // ── Diagonal lanes ──────────────────────────────────────────────
        Positioned.fill(
          child: ClipRect(
            child: OverflowBox(
              maxWidth: diagonal * 1.6,
              maxHeight: diagonal * 1.6,
              child: Center(
                child: Transform.rotate(
                  angle: -math.pi / 7, // ~-25.7 deg: top-right → bottom-left
                  child: SizedBox(
                    width: laneCount * laneW,
                    height: diagonal * 1.6,
                    child: Row(
                      children: List.generate(
                        laneCount,
                        (i) => _Lane(
                          animation: _ctrl,
                          lane: _laneSpecs[i % _laneSpecs.length],
                          items: _stagger(pool, i),
                          goUp: i.isEven,
                          width: laneW,
                          cardHeight: cardHeight,
                          gap: OnboardingShowcaseConfig.sloganCardGap,
                          maxItems: itemsPerLane,
                          // Shadows are invisible under the dark overlay here
                          // and are the most expensive part of a card.
                          shadows: false,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── Dark overlay ────────────────────────────────────────────────
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.72),
                    Colors.black.withValues(alpha: 0.54),
                    Colors.black.withValues(alpha: 0.72),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
        ),

        // ── Slogan ──────────────────────────────────────────────────────
        Positioned.fill(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: OnboardingShowcaseConfig.maxContentWidth,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sloganLine('Regarde.', dim: true),
                    const SizedBox(height: 4),
                    _sloganLine('Lis.', dim: true),
                    const SizedBox(height: 4),
                    _sloganLine('Ecoute.', dim: true),
                    const SizedBox(height: 20),
                    _sloganLine('Tout.', dim: false),
                    const SizedBox(height: 16),
                    Text(
                      'Un seul endroit pour tout ce\nque tu aimes.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 17,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Button ──────────────────────────────────────────────────────
        Positioned(
          left: 28, right: 28, bottom: 0,
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: OnboardingShowcaseConfig.maxContentWidth,
                ),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 60),
                  child: _WhiteButton(label: 'Commencer', onTap: widget.onNext),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Rotates [pool] so a column starts at a different title than its
  /// neighbour, without ever building more cards than the budget allows.
  List<ShowcaseItem> _stagger(List<ShowcaseItem> pool, int lane) {
    if (pool.isEmpty) return pool;
    final start = (lane * 4) % pool.length;
    return [...pool.sublist(start), ...pool.sublist(0, start)];
  }

  Widget _sloganLine(String text, {required bool dim}) {
    return Text(
      text,
      style: TextStyle(
        color: dim
            ? Colors.white.withValues(alpha: 0.28)
            : Colors.white,
        fontSize: dim ? 52 : 72,
        fontWeight: FontWeight.w900,
        letterSpacing: -3.0,
        height: 1.0,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _Lane — one vertically scrolling column of cards.
//
// Animation math:
//   progress = (t * totalH) % totalH  → always in [0, totalH), no negative
//   goUp  → offset = -progress         (cards scroll upward)
//   !goUp → offset = +progress         (cards scroll downward)
//   Second copy fills the gap seamlessly.
//
// The lane is rebuilt only when its identity or geometry changes, so the
// duplicated column is not re-created on every animation tick.
// ─────────────────────────────────────────────────────────────────────────────

class _Lane extends StatefulWidget {
  final Animation<double> animation;
  final ShowcaseLaneSpec lane;
  final List<ShowcaseItem>? items;
  final bool goUp;
  final double width;
  final double cardHeight;
  final double gap;
  final int maxItems;
  final bool shadows;

  const _Lane({
    required this.animation,
    required this.lane,
    required this.goUp,
    required this.width,
    this.items,
    this.cardHeight = 160,
    this.gap = OnboardingShowcaseConfig.cardGap,
    this.maxItems = OnboardingShowcaseConfig.itemsPerLaneDesktop,
    this.shadows = true,
  });

  @override
  State<_Lane> createState() => _LaneState();
}

class _LaneState extends State<_Lane> {
  late Widget _col1;
  late Widget _col2;

  /// The cards this lane actually builds.
  ///
  /// Capped at [maxItems]: the lane duplicates its column to scroll
  /// seamlessly, so an unbounded list is paid for twice, on every lane.
  List<ShowcaseItem> get _resolved {
    final all = widget.items ?? widget.lane.items;
    if (all.length <= widget.maxItems) return all;
    return all.sublist(0, widget.maxItems);
  }

  @override
  void initState() {
    super.initState();
    _rebuild();
  }

  @override
  void didUpdateWidget(_Lane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.width != widget.width ||
        oldWidget.cardHeight != widget.cardHeight ||
        oldWidget.gap != widget.gap ||
        oldWidget.lane != widget.lane ||
        oldWidget.items != widget.items ||
        oldWidget.maxItems != widget.maxItems ||
        oldWidget.shadows != widget.shadows) {
      _rebuild();
    }
  }

  void _rebuild() {
    _col1 = _buildCol(0);
    _col2 = _buildCol(1);
  }

  Widget _buildCol(int copyIdx) {
    final items = _resolved;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: OnboardingShowcaseConfig.lanePadding,
      ),
      child: Column(
        // Natural height: the column is deliberately taller than the viewport
        // and is clipped by the `ClipRect` above. Forcing it to the incoming
        // height makes the flex overflow on every frame.
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++)
            _Card(
              key: ValueKey('$copyIdx/${items[i].title}'),
              item: items[i],
              lane: widget.lane,
              width: widget.width - 2 * OnboardingShowcaseConfig.lanePadding,
              height: widget.cardHeight,
              gap: widget.gap,
              number: i + 1,
              shadows: widget.shadows,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _resolved;
    final totalH = (widget.cardHeight + widget.gap) * items.length;
    return SizedBox(
      width: widget.width,
      child: ClipRect(
        // The column of cards is deliberately taller than the viewport and is
        // scrolled through it, so it must be allowed its natural height instead
        // of being squeezed into the incoming constraints (which overflows).
        child: OverflowBox(
          alignment: Alignment.topCenter,
          maxHeight: double.infinity,
          child: AnimatedBuilder(
            animation: widget.animation,
            builder: (_, _) {
              final progress = (widget.animation.value * totalH) % totalH;
              final double off1, off2;
              if (widget.goUp) {
                off1 = -progress;
                off2 = -progress + totalH;
              } else {
                off1 = progress;
                off2 = progress - totalH;
              }
              return SizedBox(
                width: widget.width,
                height: totalH * 2,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Transform.translate(offset: Offset(0, off1), child: _col1),
                    Transform.translate(offset: Offset(0, off2), child: _col2),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _Card — a real poster with the real figure the source publishes.
//
// The cover comes from the same CDNs the rest of the app uses (AniList, TMDB,
// Apple, Steam) and is served through the shared image cache, so a card that
// has already been seen costs nothing to paint again. A colour gradient sits
// behind the image and shows through until it lands, so the first frame is
// never an empty box.
// ─────────────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final ShowcaseItem item;
  final ShowcaseLaneSpec lane;
  final double width;
  final double height;
  final double gap;
  final int number;
  final bool shadows;
  const _Card({
    super.key,
    required this.item,
    required this.lane,
    required this.width,
    required this.height,
    required this.gap,
    required this.number,
    this.shadows = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: EdgeInsets.only(bottom: gap),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          OnboardingShowcaseConfig.cardRadius,
        ),
        color: lane.color.withValues(alpha: 0.25),
        // The blur is the most expensive part of a card and dozens are stacked,
        // so it is dropped on constrained devices.
        boxShadow: shadows
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Base colour gradient — also the placeholder until the poster lands.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  lane.color.withValues(alpha: 0.95),
                  lane.color.withValues(alpha: 0.55),
                  lane.color.withValues(alpha: 0.16),
                ],
                stops: const [0.0, 0.52, 1.0],
              ),
            ),
          ),

          // The real cover. `errorWidget` is transparent so a dead image leaves
          // the gradient visible instead of a broken-image icon, and the loading
          // placeholder is static: the card already paints its own gradient, and
          // the default shimmer would add one animation controller per card —
          // dozens of them, all ticking until every poster has landed.
          cachedNetworkImage(
            imageUrl: item.imageUrl,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorWidget: const SizedBox.shrink(),
            loadingWidget: const SizedBox.shrink(),
          ),

          // Bottom gradient for text legibility
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.82),
                  ],
                  stops: const [0.34, 1.0],
                ),
              ),
            ),
          ),

          // Ranking number — top-left
          Positioned(
            left: 8,
            top: 6,
            child: Text(
              '$number',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 15,
                fontWeight: FontWeight.w900,
                height: 1.0,
                shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
            ),
          ),

          // Real figure — top-right. This is the source's own number: an
          // AniList score, a TMDB rating, an album artist or a Steam price.
          if (item.badge != null)
            Positioned(
              right: 7,
              top: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                    width: 1,
                  ),
                ),
                child: Text(
                  item.badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ),
            ),

          // Category pill + title
          Positioned(
            left: 9,
            right: 9,
            bottom: 9,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: lane.color.withValues(alpha: 0.85),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(lane.icon, size: 10, color: lane.color),
                      const SizedBox(width: 4),
                      Text(
                        lane.label,
                        style: TextStyle(
                          color: lane.color,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 10,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page 5 — Permissions
// ─────────────────────────────────────────────────────────────────────────────

class _PermissionsPage extends StatelessWidget {
  final bool storageGranted, notifGranted, installGranted, overlayGranted, batteryGranted;
  final bool busyStorage, busyNotif, busyInstall, busyOverlay, busyBattery;
  final VoidCallback onStorage, onNotif, onInstall, onOverlay, onBattery, onFinish;

  const _PermissionsPage({
    required this.storageGranted,
    required this.notifGranted,
    required this.installGranted,
    required this.overlayGranted,
    required this.batteryGranted,
    required this.busyStorage,
    required this.busyNotif,
    required this.busyInstall,
    required this.busyOverlay,
    required this.busyBattery,
    required this.onStorage,
    required this.onNotif,
    required this.onInstall,
    required this.onOverlay,
    required this.onBattery,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final isIOS = !kIsWeb && Platform.isIOS;
    // install est maintenant optionnel — ne bloque plus le bouton principal
    final all = storageGranted && notifGranted;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 52, 24, 72),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Autorisations',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Watchtower a besoin de quelques acces\npour fonctionner correctement.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.52),
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 44),

            // ── Required ────────────────────────────────────────────────
            _PermRow(
              icon: Icons.folder_open_rounded,
              title: 'Stockage',
              subtitle: isIOS
                  ? 'Acces sandbox iOS — aucune action requise.'
                  : 'Autoriser « accès à tous les fichiers » pour les téléchargements et Smart Library.',
              granted: storageGranted,
              busy: busyStorage,
              onTap: onStorage,
            ),
            const SizedBox(height: 18),
            _PermRow(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              subtitle: 'Telechargements, mises a jour de la bibliotheque.',
              granted: notifGranted,
              busy: busyNotif,
              onTap: onNotif,
            ),

            // ── Android-only: Optional (install APK + overlay/PiP) ──────
            if (!isIOS) ...[
              const SizedBox(height: 40),
              Row(
                children: [
                  Expanded(
                    child: Divider(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'OPTIONNEL',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.28),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _PermRow(
                icon: Icons.system_update_alt_rounded,
                title: "Installation d'apps",
                subtitle: "Installer les mises a jour APK directement depuis l'app.",
                granted: installGranted,
                busy: busyInstall,
                onTap: onInstall,
                optional: true,
              ),
              const SizedBox(height: 16),
              _PermRow(
                icon: Icons.picture_in_picture_rounded,
                title: 'Overlay / PiP',
                subtitle: "Afficher la video en flottant par-dessus d'autres apps.",
                granted: overlayGranted,
                busy: busyOverlay,
                onTap: onOverlay,
                optional: true,
              ),
              const SizedBox(height: 16),
              _PermRow(
                icon: Icons.battery_saver_rounded,
                title: 'Pas de restriction batterie',
                subtitle:
                    'Empêche Android de tuer les téléchargements en arrière-plan (Doze, veille).',
                granted: batteryGranted,
                busy: busyBattery,
                onTap: onBattery,
                optional: true,
              ),
            ],

            const SizedBox(height: 52),
            _WhiteButton(
              label: all ? "Acceder a Watchtower" : "Passer pour l'instant",
              onTap: onFinish,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page 4 — Optional dependencies
// ─────────────────────────────────────────────────────────────────────────────

class _DependenciesPage extends StatelessWidget {
  final Map<OnboardingDependencyId, bool> installed;
  final OnboardingDependencyId? busy;
  final String? error;
  final Future<void> Function(OnboardingDependencyId) onInstall;
  final VoidCallback onNext;

  const _DependenciesPage({
    required this.installed,
    required this.busy,
    required this.error,
    required this.onInstall,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 52, 24, 72),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dépendances',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.0,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'L’application garde son APK léger. Les composants optionnels '
              's’installent après l’installation et peuvent être reportés.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.58),
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 26),
            ...OnboardingDependencyService.catalog.map(
              (dependency) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _DependencyCard(
                  dependency: dependency,
                  installed: installed[dependency.id] ?? false,
                  busy: busy == dependency.id,
                  onInstall: () => onInstall(dependency.id),
                ),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 2),
              Text(
                error!,
                style: const TextStyle(
                  color: Color(0xFFFF8A80),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 26),
            _WhiteButton(label: 'Continuer', onTap: onNext),
          ],
        ),
      ),
    );
  }
}

class _DependencyCard extends StatelessWidget {
  final OnboardingDependencyInfo dependency;
  final bool installed;
  final bool busy;
  final VoidCallback onInstall;

  const _DependencyCard({
    required this.dependency,
    required this.installed,
    required this.busy,
    required this.onInstall,
  });

  IconData get _icon => switch (dependency.id) {
        OnboardingDependencyId.ffmpeg => Icons.movie_filter_rounded,
        OnboardingDependencyId.mpv => Icons.play_circle_outline_rounded,
        OnboardingDependencyId.aria2 => Icons.speed_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final isOptional = !dependency.required;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.065),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_icon, color: Colors.white70, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        dependency.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      dependency.required ? 'OBLIGATOIRE' : 'FACULTATIF',
                      style: TextStyle(
                        color: dependency.required
                            ? const Color(0xFFFFD166)
                            : Colors.white.withValues(alpha: 0.40),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  dependency.purpose,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.52),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Alternative : ${dependency.alternative}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.30),
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (installed)
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF06D6A0),
                            size: 16,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Disponible',
                            style: TextStyle(
                              color: Color(0xFF06D6A0),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      )
                    else
                      InkWell(
                        onTap: busy ? null : onInstall,
                        borderRadius: BorderRadius.circular(9),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: busy
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Installer',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    if (isOptional && !installed) ...[
                      const SizedBox(width: 10),
                      Text(
                        'Vous pouvez continuer sans',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.28),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PermRow
// ─────────────────────────────────────────────────────────────────────────────

class _PermRow extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool granted, busy;
  final bool optional;
  final VoidCallback onTap;

  const _PermRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.busy,
    required this.onTap,
    this.optional = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.7),
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.42),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (granted)
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF06D6A0).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Color(0xFF06D6A0),
              size: 18,
            ),
          )
        else
          InkWell(
            onTap: busy ? null : onTap,
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color:
                    Colors.white.withValues(alpha: busy ? 0.04 : 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text('Autoriser',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page 3 — Automatic language detection
// The app language and user language are never manually selected.
// ─────────────────────────────────────────────────────────────────────────────

class _LanguagePage extends StatelessWidget {
  final VoidCallback onNext;
  const _LanguagePage({required this.onNext});

  @override
  Widget build(BuildContext context) {
    final locale = PlatformDispatcher.instance.locale;
    final primary = locale.languageCode.toUpperCase();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 52, 24, 72),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Détection automatique',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.0,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Watchtower suit la langue de votre appareil et choisit '
              'automatiquement le doublage le plus adapté.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.58),
                fontSize: 15,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 28),

            _LangCard(
              icon: Icons.language_rounded,
              label: 'Langue de l’appareil',
              value: primary,
              subtitle: 'Aucun choix manuel. La langue reste synchronisée '
                  'avec le système.',
            ),
            const SizedBox(height: 14),
            Text(
              'Doublage et sous-titres',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'La langue audio et les sous-titres suivent automatiquement '
              'la langue détectée. Vous pourrez changer la piste pendant '
              'la lecture.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.42),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 14),
            _LangCard(
              icon: Icons.record_voice_over_rounded,
              label: 'Préférence audio',
              value: 'Automatique',
              subtitle: 'VF si disponible, sinon VO avec sous-titres.',
            ),

            const SizedBox(height: 40),

            _WhiteButton(label: 'Continuer', onTap: onNext),
          ],
        ),
      ),
    );
  }
}

class _LangCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  const _LangCard({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white70, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.42),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _WhiteButton — shared CTA button
// ─────────────────────────────────────────────────────────────────────────────

class _WhiteButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _WhiteButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }
}
