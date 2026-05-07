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

// ─── Data ────────────────────────────────────────────────────────────────────

class _MediaItem {
  final String title;
  final String label;
  final Color color;
  const _MediaItem(this.title, this.label, this.color);
}

const _animeItems = [
  _MediaItem('Naruto', 'Anime', Color(0xFFFF6B00)),
  _MediaItem('Dragon Ball Z', 'Anime', Color(0xFFFFB703)),
  _MediaItem('Hunter × Hunter', 'Anime', Color(0xFF06D6A0)),
  _MediaItem('One Piece', 'Anime', Color(0xFF3A86FF)),
  _MediaItem('Attack on Titan', 'Anime', Color(0xFFFF4D6D)),
  _MediaItem('Demon Slayer', 'Anime', Color(0xFF8338EC)),
  _MediaItem('Jujutsu Kaisen', 'Anime', Color(0xFF0077B6)),
  _MediaItem('Bleach', 'Anime', Color(0xFF48CAE4)),
];

const _mangaItems = [
  _MediaItem('Berserk', 'Manga', Color(0xFF6C757D)),
  _MediaItem('Vagabond', 'Manga', Color(0xFF495057)),
  _MediaItem('Vinland Saga', 'Manga', Color(0xFF2D6A4F)),
  _MediaItem('Tokyo Ghoul', 'Manga', Color(0xFF9D4EDD)),
  _MediaItem('Chainsaw Man', 'Manga', Color(0xFFD62828)),
  _MediaItem('Blue Period', 'Manga', Color(0xFF1D3557)),
  _MediaItem('Goodnight PunPun', 'Manga', Color(0xFF457B9D)),
];

const _showItems = [
  _MediaItem('Breaking Bad', 'Série', Color(0xFF2DC653)),
  _MediaItem('Arcane', 'Série', Color(0xFF7B2FBE)),
  _MediaItem('The Bear', 'Film/Série', Color(0xFFE63946)),
  _MediaItem('Oppenheimer', 'Film', Color(0xFFFF9F1C)),
  _MediaItem('Dune', 'Film', Color(0xFFD4A017)),
  _MediaItem('Shogun', 'Série', Color(0xFFBC4749)),
  _MediaItem('Severance', 'Série', Color(0xFF0077B6)),
];

// ─── Main Screen ─────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
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
    _refreshPermissionStatus();
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
    bool granted = false;
    if (!kIsWeb && Platform.isAndroid) {
      final perm = Permission.manageExternalStorage;
      final status = await perm.status;
      if (status.isGranted) {
        granted = true;
      } else if (status.isPermanentlyDenied) {
        await openAppSettings();
        granted = (await perm.status).isGranted;
      } else {
        granted = (await perm.request()).isGranted;
        if (!granted && (await perm.status).isPermanentlyDenied) {
          await openAppSettings();
          granted = (await perm.status).isGranted;
        }
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
  }

  Future<void> _requestNotifications() async {
    if (_requestingNotifications) return;
    setState(() => _requestingNotifications = true);
    final status = await Permission.notification.request();
    if (mounted) {
      setState(() {
        _notificationsGranted = status.isGranted;
        _requestingNotifications = false;
      });
    }
  }

  Future<void> _requestInstall() async {
    if (_requestingInstall) return;
    setState(() => _requestingInstall = true);
    final status = await Permission.requestInstallPackages.request();
    if (mounted) {
      setState(() {
        _installGranted = status.isGranted;
        _requestingInstall = false;
      });
    }
  }

  Future<void> _finish() async {
    await markOnboardingComplete();
    if (mounted) context.go('/MangaLibrary');
  }

  void _nextPage() {
    if (_currentPage < 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
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
                    children: List.generate(2, (i) {
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

// ─── Page 1 : Showcase ───────────────────────────────────────────────────────

class _ShowcasePage extends StatelessWidget {
  final VoidCallback onNext;
  const _ShowcasePage({required this.onNext});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Stack(
      children: [
        // Animated lanes
        Positioned.fill(
          child: Row(
            children: [
              _AnimatedLane(
                items: _animeItems,
                direction: 1,
                width: size.width / 3,
              ),
              _AnimatedLane(
                items: _mangaItems,
                direction: -1,
                width: size.width / 3,
              ),
              _AnimatedLane(
                items: _showItems,
                direction: 1,
                width: size.width / 3,
              ),
            ],
          ),
        ),

        // Gradient overlay — fades top & bottom for depth
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
                    'Anime · Manga · Films · Séries',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tout ce que vous regardez et lisez,\nau même endroit.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onNext,
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
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Animated Lane ───────────────────────────────────────────────────────────

class _AnimatedLane extends StatefulWidget {
  final List<_MediaItem> items;
  final int direction;
  final double width;

  const _AnimatedLane({
    required this.items,
    required this.direction,
    required this.width,
  });

  @override
  State<_AnimatedLane> createState() => _AnimatedLaneState();
}

class _AnimatedLaneState extends State<_AnimatedLane>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 18 + math.Random().nextInt(8)),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const cardH = 160.0;
    const gap = 10.0;
    final totalH = (cardH + gap) * widget.items.length;

    return SizedBox(
      width: widget.width,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final offset = widget.direction == 1
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
        children: widget.items.map((item) {
          return _MediaCard(item: item, width: widget.width - 8);
        }).toList(),
      ),
    );
  }
}

// ─── Media Card ──────────────────────────────────────────────────────────────

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
      decoration: BoxDecoration(
        color: item.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.color.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.20),
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
            const SizedBox(height: 6),
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
    );
  }
}

// ─── Page 2 : Permissions ────────────────────────────────────────────────────

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
              'Watchtower a besoin de quelques accès\npour fonctionner correctement.',
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
              subtitle: 'Sauvegarder téléchargements, covers et bibliothèque.',
              granted: storageGranted,
              busy: requestingStorage,
              onTap: onRequestStorage,
            ),
            const SizedBox(height: 16),
            _PermissionRow(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              subtitle:
                  'Progression des téléchargements, mises à jour de la bibliothèque.',
              granted: notificationsGranted,
              busy: requestingNotifications,
              onTap: onRequestNotifications,
            ),
            const SizedBox(height: 16),
            _PermissionRow(
              icon: Icons.system_update_alt_rounded,
              title: 'Installation d\'apps',
              subtitle:
                  'Installer les mises à jour APK directement depuis l\'application.',
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
                child: Text(allGranted ? 'Accéder à l\'app' : 'Passer pour l\'instant'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Permission Row ───────────────────────────────────────────────────────────

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
