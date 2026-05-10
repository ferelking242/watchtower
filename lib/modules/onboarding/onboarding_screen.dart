import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
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

// ─── Data ─────────────────────────────────────────────────────────────────

class _MediaItem {
  final String title;
  final String label;
  final Color color;
  final String imageUrl;
  const _MediaItem(this.title, this.label, this.color, this.imageUrl);
}

const _animeItems = [
  _MediaItem('Naruto', 'Anime', Color(0xFFFF6B00),
      'https://cdn.myanimelist.net/images/anime/1141/142503.jpg'),
  _MediaItem('Dragon Ball Z', 'Anime', Color(0xFFFFB703),
      'https://cdn.myanimelist.net/images/anime/1277/142240.jpg'),
  _MediaItem('Hunter x Hunter', 'Anime', Color(0xFF06D6A0),
      'https://cdn.myanimelist.net/images/anime/1337/99013.jpg'),
  _MediaItem('One Piece', 'Anime', Color(0xFF3A86FF),
      'https://cdn.myanimelist.net/images/anime/6/73245.jpg'),
  _MediaItem('Attack on Titan', 'Anime', Color(0xFFFF4D6D),
      'https://cdn.myanimelist.net/images/anime/10/47347.jpg'),
  _MediaItem('Demon Slayer', 'Anime', Color(0xFF8338EC),
      'https://cdn.myanimelist.net/images/anime/1286/99889.jpg'),
  _MediaItem('Jujutsu Kaisen', 'Anime', Color(0xFF0077B6),
      'https://cdn.myanimelist.net/images/anime/1171/109222.jpg'),
  _MediaItem('Bleach', 'Anime', Color(0xFF48CAE4),
      'https://cdn.myanimelist.net/images/anime/3/40451.jpg'),
];

const _mangaItems = [
  _MediaItem('Berserk', 'Manga', Color(0xFF6C757D),
      'https://cdn.myanimelist.net/images/manga/1/157931.jpg'),
  _MediaItem('Vagabond', 'Manga', Color(0xFF495057),
      'https://cdn.myanimelist.net/images/manga/2/286785.jpg'),
  _MediaItem('Vinland Saga', 'Manga', Color(0xFF2D6A4F),
      'https://cdn.myanimelist.net/images/manga/2/188925.jpg'),
  _MediaItem('Tokyo Ghoul', 'Manga', Color(0xFF9D4EDD),
      'https://cdn.myanimelist.net/images/manga/3/214566.jpg'),
  _MediaItem('Chainsaw Man', 'Manga', Color(0xFFD62828),
      'https://cdn.myanimelist.net/images/manga/3/216464.jpg'),
  _MediaItem('Blue Period', 'Manga', Color(0xFF1D3557),
      'https://cdn.myanimelist.net/images/manga/3/208225.jpg'),
  _MediaItem('Goodnight PunPun', 'Manga', Color(0xFF457B9D),
      'https://cdn.myanimelist.net/images/manga/3/117681.jpg'),
];

const _showItems = [
  _MediaItem('Breaking Bad', 'Serie', Color(0xFF2DC653),
      'https://image.tmdb.org/t/p/w342/ggFHVNu6YYI5L9pCfOacjizRGt.jpg'),
  _MediaItem('Arcane', 'Serie', Color(0xFF7B2FBE),
      'https://image.tmdb.org/t/p/w342/fqldf2t8ztc9aiwn3k6mlX3tvRT.jpg'),
  _MediaItem('The Bear', 'Serie', Color(0xFFE63946),
      'https://image.tmdb.org/t/p/w342/sHFlbKS3WLqMnp9t2ghADIJFnuQ.jpg'),
  _MediaItem('Oppenheimer', 'Film', Color(0xFFFF9F1C),
      'https://image.tmdb.org/t/p/w342/8Gxv8giaFIelhEDznpaHCT4OMWJ.jpg'),
  _MediaItem('Dune', 'Film', Color(0xFFD4A017),
      'https://image.tmdb.org/t/p/w342/d5NXSklXo0qyIYkgV61Dis7BXj5.jpg'),
  _MediaItem('Shogun', 'Serie', Color(0xFFBC4749),
      'https://image.tmdb.org/t/p/w342/7O4iVfOMQmdCSXhopOlTXVQ6tRF.jpg'),
  _MediaItem('Severance', 'Serie', Color(0xFF0077B6),
      'https://image.tmdb.org/t/p/w342/gBsPCDW0HjWtqO1f2D4GjZETZ2n.jpg'),
];

// ─── Main Screen ───────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  bool _storageGranted = false;
  bool _notificationsGranted = false;
  bool _installGranted = false;
  bool _requestingStorage = false;
  bool _requestingNotifications = false;
  bool _requestingInstall = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPermissionStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPermissionStatus();
    }
  }

  Future<void> _refreshPermissionStatus() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      if (mounted) {
        setState(() {
          _storageGranted = true;
          _notificationsGranted = true;
          _installGranted = true;
        });
      }
      return;
    }
    final storage = await Permission.manageExternalStorage.status;
    final notif = await Permission.notification.status;
    final install = await Permission.requestInstallPackages.status;
    if (mounted) {
      setState(() {
        _storageGranted = storage.isGranted;
        _notificationsGranted = notif.isGranted;
        _installGranted = install.isGranted;
      });
    }
  }

  Future<void> _requestStorage() async {
    if (_requestingStorage) return;
    setState(() => _requestingStorage = true);
    try {
      bool granted = false;
      if (!kIsWeb && Platform.isAndroid) {
        final perm = Permission.manageExternalStorage;
        final status = await perm.status;
        if (status.isGranted) {
          granted = true;
        } else {
          // MANAGE_EXTERNAL_STORAGE requires Settings on Android 11+
          await openAppSettings();
          // Status will be refreshed when the user returns via didChangeAppLifecycleState
          granted = (await perm.status).isGranted;
        }
      } else {
        granted = await StorageProvider().requestPermission();
      }
      if (mounted) {
        setState(() {
          _storageGranted = granted;
          _requestingStorage = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _requestingStorage = false);
    }
  }

  Future<void> _requestNotifications() async {
    if (_requestingNotifications) return;
    setState(() => _requestingNotifications = true);
    try {
      final status = await Permission.notification.request();
      if (mounted) {
        setState(() {
          _notificationsGranted = status.isGranted;
          _requestingNotifications = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _requestingNotifications = false);
    }
  }

  Future<void> _requestInstall() async {
    if (_requestingInstall) return;
    setState(() => _requestingInstall = true);
    try {
      final status = await Permission.requestInstallPackages.request();
      if (mounted) {
        setState(() {
          _installGranted = status.isGranted;
          _requestingInstall = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _requestingInstall = false);
    }
  }

  Future<void> _finish() async {
    await markOnboardingComplete();
    if (mounted) context.go('/MangaLibrary');
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
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
              controller: _pageController,
              onPageChanged: (i) => setState(() => _currentPage = i),
              children: [
                _ShowcasePage(onNext: _nextPage),
                _SloganPage(onNext: _nextPage),
                _PermissionsPage(
                  storageGranted: _storageGranted,
                  notificationsGranted: _notificationsGranted,
                  installGranted: _installGranted,
                  requestingStorage: _requestingStorage,
                  requestingNotifications: _requestingNotifications,
                  requestingInstall: _requestingInstall,
                  onRequestStorage: _requestStorage,
                  onRequestNotifications: _requestNotifications,
                  onRequestInstall: _requestInstall,
                  onFinish: _finish,
                ),
              ],
            ),
            // Page dots
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _currentPage ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _currentPage
                              ? Colors.white
                              : Colors.white.withOpacity(0.3),
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

// ─── Page 1 : Showcase ────────────────────────────────────────────────────
// Shared single AnimationController → all 3 lanes strictly synchronized.

class _ShowcasePage extends StatefulWidget {
  final VoidCallback onNext;
  const _ShowcasePage({required this.onNext});

  @override
  State<_ShowcasePage> createState() => _ShowcasePageState();
}

class _ShowcasePageState extends State<_ShowcasePage>
    with TickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Stack(
      children: [
        // Animated lanes — ALL share the SAME controller → perfectly synced
        Positioned.fill(
          child: Row(
            children: [
              _Lane(
                animation: _controller,
                items: _animeItems,
                direction: 1,
                width: size.width / 3,
              ),
              _Lane(
                animation: _controller,
                items: _mangaItems,
                direction: -1,
                width: size.width / 3,
              ),
              _Lane(
                animation: _controller,
                items: _showItems,
                direction: 1,
                width: size.width / 3,
              ),
            ],
          ),
        ),

        // Gradient overlay — top & bottom fade
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black,
                  Colors.black.withOpacity(0.0),
                  Colors.black.withOpacity(0.0),
                  Colors.black.withOpacity(0.85),
                  Colors.black,
                ],
                stops: const [0.0, 0.18, 0.55, 0.82, 1.0],
              ),
            ),
          ),
        ),

        // Bottom content
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 56),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Watchtower',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.5,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Anime · Manga · Films · Series',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tout ce que tu regardes et lis,\nau meme endroit.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: widget.onNext,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('Suivant'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Page 2 : Slogan ──────────────────────────────────────────────────────
// Diagonal animated card lanes (top-right → bottom-left) + slogan overlay.

class _SloganPage extends StatefulWidget {
  final VoidCallback onNext;
  const _SloganPage({required this.onNext});

  @override
  State<_SloganPage> createState() => _SloganPageState();
}

class _SloganPageState extends State<_SloganPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Merge all items for diagonal lanes
  static const _allItems = [..._animeItems, ..._mangaItems, ..._showItems];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    // We tile the full item list across 5 diagonal lanes
    final laneWidth = size.width / 3.5;
    const laneCount = 5;
    final totalWidth = laneWidth * laneCount;

    return Stack(
      children: [
        // ── Diagonal card lanes ──────────────────────────────────────────
        Positioned.fill(
          child: ClipRect(
            child: OverflowBox(
              maxWidth: totalWidth + size.height,
              maxHeight: size.height + totalWidth,
              child: Transform.rotate(
                angle: -math.pi / 7, // ~-25 degrees: top-right → bottom-left
                child: SizedBox(
                  width: totalWidth + size.height,
                  height: size.height + totalWidth,
                  child: Row(
                    children: List.generate(laneCount, (i) {
                      // Stagger item offsets per lane so they don't all show
                      // the same card at the same height
                      final itemCount = _allItems.length;
                      final staggeredItems = [
                        ..._allItems.sublist(
                            (i * 3) % itemCount, itemCount),
                        ..._allItems.sublist(0, (i * 3) % itemCount),
                      ];
                      return _Lane(
                        animation: _controller,
                        items: staggeredItems,
                        direction: 1, // all go up together
                        width: laneWidth,
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── Dark gradient overlay ────────────────────────────────────────
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.9,
                colors: [
                  Colors.black.withOpacity(0.55),
                  Colors.black.withOpacity(0.88),
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.75),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.75),
                ],
                stops: const [0.0, 0.2, 0.8, 1.0],
              ),
            ),
          ),
        ),

        // ── Slogan text ──────────────────────────────────────────────────
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSloganWord('Regarde.'),
                const SizedBox(height: 4),
                _buildSloganWord('Lis.'),
                const SizedBox(height: 4),
                _buildSloganWord('Ecoute.'),
                const SizedBox(height: 16),
                Text(
                  'Tout.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.95),
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2.5,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Next button ──────────────────────────────────────────────────
        Positioned(
          left: 28,
          right: 28,
          bottom: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 56),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: widget.onNext,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Commencer'),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSloganWord(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withOpacity(0.45),
        fontSize: 48,
        fontWeight: FontWeight.w800,
        letterSpacing: -2,
        height: 1.05,
      ),
    );
  }
}

// ─── Shared Lane widget ────────────────────────────────────────────────────
// Receives an external Animation<double> — does NOT own a controller.
// This guarantees multiple lanes are frame-perfectly synchronized.

class _Lane extends StatelessWidget {
  final Animation<double> animation;
  final List<_MediaItem> items;
  final int direction; // 1 = scroll up, -1 = scroll down
  final double width;

  const _Lane({
    required this.animation,
    required this.items,
    required this.direction,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    const cardH = 160.0;
    const gap = 10.0;
    final totalH = (cardH + gap) * items.length;

    return SizedBox(
      width: width,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = animation.value;
          final offset = direction == 1
              ? -(t * totalH) % totalH
              : -((1 - t) * totalH) % totalH;

          return ClipRect(
            child: Stack(
              children: [
                Positioned(
                  top: offset,
                  left: 0,
                  right: 0,
                  child: _buildColumn(),
                ),
                Positioned(
                  top: offset + totalH,
                  left: 0,
                  right: 0,
                  child: _buildColumn(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildColumn() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: items.map((item) {
          return _MediaCard(item: item, width: width - 8);
        }).toList(),
      ),
    );
  }
}

// ─── Media Card ────────────────────────────────────────────────────────────
// Full-bleed cover image with gradient overlay + label/title at bottom.

class _MediaCard extends StatelessWidget {
  final _MediaItem item;
  final double width;
  const _MediaCard({required this.item, required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 160,
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: item.color.withOpacity(0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.color.withOpacity(0.20),
          width: 1,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Cover image
          Image.network(
            item.imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: item.color.withOpacity(0.15),
            ),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(color: item.color.withOpacity(0.15));
            },
          ),

          // Gradient overlay so text is always readable
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.75),
                  ],
                  stops: const [0.3, 1.0],
                ),
              ),
            ),
          ),

          // Label + title
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.30),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: item.color,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
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

// ─── Page 3 : Permissions ──────────────────────────────────────────────────

class _PermissionsPage extends StatelessWidget {
  final bool storageGranted;
  final bool notificationsGranted;
  final bool installGranted;
  final bool requestingStorage;
  final bool requestingNotifications;
  final bool requestingInstall;
  final VoidCallback onRequestStorage;
  final VoidCallback onRequestNotifications;
  final VoidCallback onRequestInstall;
  final VoidCallback onFinish;

  const _PermissionsPage({
    required this.storageGranted,
    required this.notificationsGranted,
    required this.installGranted,
    required this.requestingStorage,
    required this.requestingNotifications,
    required this.requestingInstall,
    required this.onRequestStorage,
    required this.onRequestNotifications,
    required this.onRequestInstall,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final allGranted =
        storageGranted && notificationsGranted && installGranted;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 48, 24, 56),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Autorisations',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Watchtower a besoin de quelques acces\npour fonctionner correctement.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),

            _PermissionRow(
              icon: Icons.folder_open_rounded,
              title: 'Stockage',
              subtitle:
                  'Sauvegarder telechargements, covers et bibliotheque.',
              granted: storageGranted,
              busy: requestingStorage,
              onTap: onRequestStorage,
            ),
            const SizedBox(height: 16),
            _PermissionRow(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              subtitle:
                  'Progression des telechargements, mises a jour.',
              granted: notificationsGranted,
              busy: requestingNotifications,
              onTap: onRequestNotifications,
            ),
            const SizedBox(height: 16),
            _PermissionRow(
              icon: Icons.system_update_alt_rounded,
              title: "Installation d'apps",
              subtitle:
                  "Installer les mises a jour APK depuis l'application.",
              granted: installGranted,
              busy: requestingInstall,
              onTap: onRequestInstall,
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onFinish,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(
                    allGranted ? "Acceder a l'app" : 'Passer pour l\'instant'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Permission Row ────────────────────────────────────────────────────────

class _PermissionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool granted;
  final bool busy;
  final VoidCallback onTap;

  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Colors.white.withOpacity(0.75),
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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
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
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF06D6A0).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Color(0xFF06D6A0),
              size: 18,
            ),
          )
        else
          GestureDetector(
            onTap: busy ? null : onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(busy ? 0.05 : 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
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
                  : const Text(
                      'Autoriser',
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
