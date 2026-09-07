import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:extended_image/extended_image.dart';
import 'package:watchtower/providers/storage_provider.dart';

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
// Data  (no imageUrl — all cards are rendered locally via gradient)
// ─────────────────────────────────────────────────────────────────────────────

class _MediaItem {
  final String title;
  final String label;
  final Color color;
  final String imageUrl;
  const _MediaItem(this.title, this.label, this.color, this.imageUrl);
}

const _animeItems = [
  _MediaItem('Naruto', 'Anime', Color(0xFFFF6B00), 'https://cdn.myanimelist.net/images/anime/1141/142503l.jpg'),
  _MediaItem('Dragon Ball Z', 'Anime', Color(0xFFFFB703), 'https://cdn.myanimelist.net/images/anime/1277/142022l.jpg'),
  _MediaItem('Hunter x Hunter', 'Anime', Color(0xFF06D6A0), 'https://cdn.myanimelist.net/images/anime/1305/132237l.jpg'),
  _MediaItem('One Piece', 'Anime', Color(0xFF3A86FF), 'https://cdn.myanimelist.net/images/anime/1770/97704l.jpg'),
  _MediaItem('Attack on Titan', 'Anime', Color(0xFFFF4D6D), 'https://cdn.myanimelist.net/images/anime/10/47347l.jpg'),
  _MediaItem('Demon Slayer', 'Anime', Color(0xFF8338EC), 'https://cdn.myanimelist.net/images/anime/1286/99889l.jpg'),
  _MediaItem('Jujutsu Kaisen', 'Anime', Color(0xFF0077B6), 'https://cdn.myanimelist.net/images/anime/1171/109222l.jpg'),
  _MediaItem('Bleach', 'Anime', Color(0xFF48CAE4), 'https://cdn.myanimelist.net/images/anime/1541/147774l.jpg'),
];

const _mangaItems = [
  _MediaItem('Berserk', 'Manga', Color(0xFF6C757D), 'https://cdn.myanimelist.net/images/manga/1/157897l.jpg'),
  _MediaItem('Vagabond', 'Manga', Color(0xFF495057), 'https://cdn.myanimelist.net/images/manga/1/259070l.jpg'),
  _MediaItem('Vinland Saga', 'Manga', Color(0xFF2D6A4F), 'https://cdn.myanimelist.net/images/manga/2/188925l.jpg'),
  _MediaItem('Tokyo Ghoul', 'Manga', Color(0xFF9D4EDD), 'https://cdn.myanimelist.net/images/manga/3/194456l.jpg'),
  _MediaItem('Chainsaw Man', 'Manga', Color(0xFFD62828), 'https://cdn.myanimelist.net/images/manga/3/216464l.jpg'),
  _MediaItem('Blue Period', 'Manga', Color(0xFF1D3557), 'https://cdn.myanimelist.net/images/manga/2/204827l.jpg'),
  _MediaItem('Goodnight PunPun', 'Manga', Color(0xFF457B9D), 'https://cdn.myanimelist.net/images/manga/3/266834l.jpg'),
];

const _showItems = [
  _MediaItem('Breaking Bad', 'Serie', Color(0xFF2DC653), 'https://image.tmdb.org/t/p/w500/ztkUQFLlC19CCMYHW9o1zWhJRNq.jpg'),
  _MediaItem('Arcane', 'Serie', Color(0xFF7B2FBE), 'https://image.tmdb.org/t/p/w500/abf8tHznhSvl9BAElD2cQeRr7do.jpg'),
  _MediaItem('The Bear', 'Serie', Color(0xFFE63946), 'https://image.tmdb.org/t/p/w500/4fVddnbhcmzRZE14NJY03GKS6Fn.jpg'),
  _MediaItem('Oppenheimer', 'Film', Color(0xFFFF9F1C), 'https://image.tmdb.org/t/p/w500/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg'),
  _MediaItem('Dune', 'Film', Color(0xFFD4A017), 'https://image.tmdb.org/t/p/w500/gDzOcq0pfeCeqMBwKIJlSmQpjkZ.jpg'),
  _MediaItem('Shogun', 'Serie', Color(0xFFBC4749), 'https://image.tmdb.org/t/p/w500/7O4iVfOMQmdCSxhOg1WnzG1AgYT.jpg'),
  _MediaItem('Severance', 'Serie', Color(0xFF0077B6), 'https://image.tmdb.org/t/p/w500/pPHpeI2X1qEd1CS1SeyrdhZ4qnT.jpg'),
];

// ─────────────────────────────────────────────────────────────────────────────
// OnboardingScreen  (3 pages: showcase → slogan → permissions)
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
    final n = await Permission.notification.status;
    final i = await Permission.requestInstallPackages.status;
    final o = await Permission.systemAlertWindow.status;
    final b = await Permission.ignoreBatteryOptimizations.status;
    if (!mounted) return;
    setState(() {
      _storageGranted = s.isGranted;
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
      if (!kIsWeb && Platform.isAndroid) {
        final status = await Permission.manageExternalStorage.status;
        if (status.isPermanentlyDenied) {
          // User tapped "Ne plus demander" — send them to system settings.
          await openAppSettings();
          final updated = await Permission.manageExternalStorage.status;
          granted = updated.isGranted;
        } else {
          final result = await Permission.manageExternalStorage.request();
          granted = result.isGranted;
        }
      } else {
        granted = await StorageProvider().requestPermission();
      }
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
        final result = await Permission.systemAlertWindow.request();
        granted = result.isGranted;
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
    if (_currentPage < 3) {
      _page.nextPage(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeInOut);
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
                _ShowcasePage(onNext: _next),
                _SloganPage(onNext: _next),
                _LanguagePage(onNext: _next),
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
                    children: List.generate(4, (i) {
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
// Page 1 — Showcase
// ONE shared AnimationController → all 3 lanes are frame-perfectly synced.
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

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final lw = w / 3;

    return Stack(
      children: [
        // ── 3 card lanes, ALL share _ctrl → strictly synchronized ──────
        Positioned.fill(
          child: Row(
            children: [
              RepaintBoundary(child: _Lane(animation: _ctrl, items: _animeItems, goUp: true, width: lw)),
              RepaintBoundary(child: _Lane(animation: _ctrl, items: _mangaItems, goUp: false, width: lw)),
              RepaintBoundary(child: _Lane(animation: _ctrl, items: _showItems, goUp: true, width: lw)),
            ],
          ),
        ),

        // ── Gradient vignette — top & bottom fade ───────────────────────
        Positioned.fill(
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

        // ── Bottom text + button ────────────────────────────────────────
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: SafeArea(
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
                  const SizedBox(height: 6),
                  Text(
                    'Anime · Manga · Films · Series',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tout ce que tu regardes et lis,\nau meme endroit.',
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
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page 2 — Slogan
// Diagonal lanes (top-right → bottom-left) with slogan text overlay.
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

  static const _pool = [..._animeItems, ..._mangaItems, ..._showItems];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<_MediaItem> _stagger(int lane) {
    final n = _pool.length;
    final start = (lane * 4) % n;
    return [..._pool.sublist(start), ..._pool.sublist(0, start)];
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // Wider + taller than screen to fill after rotation
    final diagonal = math.sqrt(
            size.width * size.width + size.height * size.height)
        .ceil()
        .toDouble();
    const laneW = 130.0;
    const laneCount = 5;

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
                          items: _stagger(i),
                          goUp: i.isEven,
                          width: laneW,
                          cardHeight: 130,
                          gap: 6,
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

        // ── Slogan ──────────────────────────────────────────────────────
        Positioned.fill(
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

        // ── Button ──────────────────────────────────────────────────────
        Positioned(
          left: 28, right: 28, bottom: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 60),
              child: _WhiteButton(label: 'Commencer', onTap: widget.onNext),
            ),
          ),
        ),
      ],
    );
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
// _Lane — pure stateless, receives an external Animation<double>.
//
// Animation math:
//   progress = (t * totalH) % totalH  → always in [0, totalH), no negative
//   goUp  → offset = -progress         (cards scroll upward)
//   !goUp → offset = +progress         (cards scroll downward)
//   Second copy fills the gap seamlessly.
// ─────────────────────────────────────────────────────────────────────────────

class _Lane extends StatefulWidget {
  final Animation<double> animation;
  final List<_MediaItem> items;
  final bool goUp;
  final double width;
  final double cardHeight;
  final double gap;

  const _Lane({
    required this.animation,
    required this.items,
    required this.goUp,
    required this.width,
    this.cardHeight = 160,
    this.gap = 10,
  });

  @override
  State<_Lane> createState() => _LaneState();
}

class _LaneState extends State<_Lane> {
  late Widget _col1;
  late Widget _col2;

  @override
  void initState() {
    super.initState();
    _col1 = _buildCol(0);
    _col2 = _buildCol(1);
  }

  @override
  void didUpdateWidget(_Lane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.width != widget.width ||
        oldWidget.cardHeight != widget.cardHeight ||
        oldWidget.gap != widget.gap ||
        oldWidget.items != widget.items) {
      _col1 = _buildCol(0);
      _col2 = _buildCol(1);
    }
  }

  Widget _buildCol(int copyIdx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: widget.items
              .map((item) => _Card(
                    key: ValueKey('$copyIdx/${item.title}'),
                    item: item,
                    width: widget.width - 8,
                    height: widget.cardHeight,
                    gap: widget.gap,
                  ))
              .toList(),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final totalH = (widget.cardHeight + widget.gap) * widget.items.length;
    return SizedBox(
      width: widget.width,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: widget.animation,
          builder: (_, __) {
            final progress = (widget.animation.value * totalH) % totalH;
            final double off1, off2;
            if (widget.goUp) {
              off1 = -progress;
              off2 = -progress + totalH;
            } else {
              off1 = progress;
              off2 = progress - totalH;
            }
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Transform.translate(offset: Offset(0, off1), child: _col1),
                Transform.translate(offset: Offset(0, off2), child: _col2),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _Card — 100% local gradient card, zero network calls.
// Each card gets a cinematic two-tone gradient from its accent color +
// a subtle diagonal sheen painted on top.
// ─────────────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final _MediaItem item;
  final double width;
  final double height;
  final double gap;
  const _Card({
    super.key,
    required this.item,
    required this.width,
    required this.height,
    required this.gap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: EdgeInsets.only(bottom: gap),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        color: item.color.withValues(alpha: 0.25),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Cover image with accent color fallback while loading
          ExtendedImage.network(
            item.imageUrl,
            fit: BoxFit.cover,
            cache: true,
            loadStateChanged: (state) {
              if (state.extendedImageLoadState != LoadState.completed) {
                return DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        item.color.withValues(alpha: 0.90),
                        item.color.withValues(alpha: 0.52),
                        item.color.withValues(alpha: 0.18),
                      ],
                      stops: const [0.0, 0.52, 1.0],
                    ),
                  ),
                );
              }
              return null;
            },
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
                    Colors.black.withValues(alpha: 0.72),
                  ],
                  stops: const [0.35, 1.0],
                ),
              ),
            ),
          ),

          // Label + title
          Positioned(
            left: 9,
            right: 9,
            bottom: 9,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: item.color,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
// Page 3 — Permissions
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
                  : 'Sauvegarder telechargements, covers et bibliotheque.',
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
    final dimmed = optional && !granted;
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: dimmed ? 0.04 : 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon,
              color: Colors.white.withValues(alpha: dimmed ? 0.35 : 0.7), size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: dimmed ? 0.5 : 1.0),
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: dimmed ? 0.25 : 0.42),
                      fontSize: 12,
                      height: 1.4)),
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
            child: const Icon(Icons.check_rounded,
                color: Color(0xFF06D6A0), size: 18),
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
                    Colors.white.withValues(alpha: busy ? 0.04 : (dimmed ? 0.05 : 0.10)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.white.withValues(alpha: dimmed ? 0.08 : 0.15),
                    width: 1),
              ),
              child: busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text('Autoriser',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: dimmed ? 0.4 : 1.0),
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page 3 — Language & Preferences
// Auto-detects device locale; lets the user pick audio mode and bilingual opt.
// ─────────────────────────────────────────────────────────────────────────────

class _LanguagePage extends StatefulWidget {
  final VoidCallback onNext;
  const _LanguagePage({required this.onNext});

  @override
  State<_LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<_LanguagePage> {
  late List<Locale> _locales;
  late String _primaryCode;
  bool _bilingualDetected = false;
  String _audioMode = 'vf';   // 'vf' | 'vo' | 'both'

  @override
  void initState() {
    super.initState();
    _locales = PlatformDispatcher.instance.locales.take(5).toList();
    _primaryCode = _locales.isNotEmpty ? _locales.first.languageCode : 'fr';
    _bilingualDetected = _locales.length > 1 &&
        _locales[1].languageCode != _primaryCode;
  }

  String _name(String code) => switch (code) {
    'fr' => 'Français',
    'en' => 'English',
    'ja' => '日本語',
    'zh' => '中文',
    'ko' => '한국어',
    'es' => 'Español',
    'pt' => 'Português',
    'de' => 'Deutsch',
    'it' => 'Italiano',
    'ar' => 'العربية',
    _ => code.toUpperCase(),
  };

  @override
  Widget build(BuildContext context) {
    final primary = _name(_primaryCode);
    final isFr = _primaryCode == 'fr';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 52, 24, 72),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title ──────────────────────────────────────────────────
            Text(
              isFr ? 'Langue & Préférences' : 'Language & Preferences',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.0,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isFr
                  ? 'Nous avons détecté que votre appareil est en $primary. '
                    'Vous pouvez affiner ci-dessous.'
                  : 'We detected your device language as $primary. '
                    'Fine-tune your preferences below.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.58),
                fontSize: 15,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 28),

            // ── Primary language card ──────────────────────────────────
            _LangCard(
              icon: Icons.language_rounded,
              label: isFr ? 'Langue principale' : 'Primary language',
              value: primary,
            ),

            // ── Bilingual card ─────────────────────────────────────────
            if (_bilingualDetected) ...[
              const SizedBox(height: 12),
              _LangCard(
                icon: Icons.translate_rounded,
                label: isFr
                    ? 'Langue secondaire détectée'
                    : 'Secondary language detected',
                value: _name(_locales[1].languageCode),
                subtitle: isFr
                    ? 'Watchtower vous proposera aussi du contenu en '
                      '${_name(_locales[1].languageCode)}.'
                    : 'Watchtower will also suggest content in '
                      '${_name(_locales[1].languageCode)}.',
              ),
            ],

            const SizedBox(height: 32),

            // ── Audio preference ───────────────────────────────────────
            Text(
              isFr ? 'Préférence audio' : 'Audio preference',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isFr
                  ? 'Pour les anime et films avec traduction disponible.'
                  : 'For anime and movies with available translations.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.42),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              children: [
                _AudioPill(
                  label: isFr ? 'VF — Doublé' : 'Dubbed',
                  selected: _audioMode == 'vf',
                  onTap: () => setState(() => _audioMode = 'vf'),
                ),
                _AudioPill(
                  label: isFr ? 'VO — Sous-titré' : 'Subbed',
                  selected: _audioMode == 'vo',
                  onTap: () => setState(() => _audioMode = 'vo'),
                ),
                _AudioPill(
                  label: isFr ? 'Les deux' : 'Both',
                  selected: _audioMode == 'both',
                  onTap: () => setState(() => _audioMode = 'both'),
                ),
              ],
            ),

            const SizedBox(height: 40),

            _WhiteButton(
              label: isFr ? 'Continuer' : 'Continue',
              onTap: widget.onNext,
            ),
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.10), width: 1),
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

class _AudioPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _AudioPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.10),
            width: selected ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white.withValues(alpha: 0.45),
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
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
              borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }
}
