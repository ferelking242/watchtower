import 'dart:io';
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

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Per-permission state.
  bool _storageGranted = false;
  bool _notificationsGranted = false;
  bool _installGranted = false;
  bool _requestingStorage = false;
  bool _requestingNotifications = false;
  bool _requestingInstall = false;

  static const _pages = [
    _OnboardingPage(
      icon: Icons.play_circle_outline_rounded,
      color: Color(0xFF6C63FF),
      title: 'Welcome to Watchtower',
      subtitle: 'Watch. Read. Everything.',
      description:
          'Your all-in-one media hub for anime, manga, and light novels — powered by hundreds of community sources.',
    ),
    _OnboardingPage(
      icon: Icons.movie_filter_outlined,
      color: Color(0xFF00B4D8),
      title: 'Anime & Manga',
      subtitle: 'Thousands of sources',
      description:
          'Stream anime and read manga from hundreds of free sources worldwide, with offline download support.',
    ),
    _OnboardingPage(
      icon: Icons.menu_book_outlined,
      color: Color(0xFF06D6A0),
      title: 'Light Novels',
      subtitle: 'Read without limits',
      description:
          'A dedicated text reader for light novels with custom fonts, themes, and offline support.',
    ),
    _OnboardingPage(
      icon: Icons.shield_outlined,
      color: Color(0xFFFF6B6B),
      title: 'Permissions',
      subtitle: 'Two quick approvals',
      description:
          'Watchtower needs storage to download and store your library, and notifications to keep you updated on downloads, the video player, app updates and more.',
      isPermissionPage: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _refreshPermissionStatus();
  }

  Future<void> _refreshPermissionStatus() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      // Desktop: nothing to ask for; treat as granted so the user can continue.
      setState(() {
        _storageGranted = true;
        _notificationsGranted = true;
      });
      return;
    }
    final notif = await Permission.notification.status;
    final install = await Permission.requestInstallPackages.status;
    if (mounted) {
      setState(() {
        _notificationsGranted = notif.isGranted;
        _installGranted = install.isGranted;
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

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _requestStorage() async {
    if (_requestingStorage) return;
    setState(() => _requestingStorage = true);
    final granted = await StorageProvider().requestPermission();
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

  Future<void> _finish() async {
    await markOnboardingComplete();
    if (mounted) {
      context.go('/MangaLibrary');
    }
  }

  bool get _isLastPage => _currentPage == _pages.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final page = _pages[_currentPage];

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemCount: _pages.length,
                  itemBuilder: (context, i) =>
                      _OnboardingPageView(page: _pages[i]),
                ),
              ),
              _buildBottom(theme, colorScheme, page),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottom(
    ThemeData theme,
    ColorScheme colorScheme,
    _OnboardingPage page,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _pages.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == _currentPage ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == _currentPage
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_isLastPage) ...[
            _PermissionTile(
              icon: Icons.folder_open_rounded,
              title: 'Storage access',
              description:
                  'Save downloads, covers and your library to disk.',
              granted: _storageGranted,
              busy: _requestingStorage,
              accent: page.color,
              onRequest: _requestStorage,
            ),
            const SizedBox(height: 12),
            _PermissionTile(
              icon: Icons.notifications_active_outlined,
              title: 'Notifications',
              description:
                  'Download progress, video playback controls, library updates and app updates.',
              granted: _notificationsGranted,
              busy: _requestingNotifications,
              accent: const Color(0xFFFFB703),
              onRequest: _requestNotifications,
            ),
            const SizedBox(height: 12),
            _PermissionTile(
              icon: Icons.system_update_alt_rounded,
              title: 'Installation de paquets',
              description:
                  'Installer les mises à jour APK directement depuis l\'application.',
              granted: _installGranted,
              busy: _requestingInstall,
              accent: const Color(0xFF8338EC),
              onRequest: _requestInstall,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _finish,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                ),
                child: const Text(
                  'Get Started',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            if (!_storageGranted || !_notificationsGranted || !_installGranted)
              TextButton(
                onPressed: _finish,
                child: Text(
                  'Skip for now',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
          ] else
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _nextPage,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: page.color,
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  'Next',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool granted;
  final bool busy;
  final Color accent;
  final VoidCallback onRequest;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.granted,
    required this.busy,
    required this.accent,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: granted
            ? const Color(0xFF06D6A0).withOpacity(0.10)
            : cs.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: granted
              ? const Color(0xFF06D6A0).withOpacity(0.45)
              : cs.outlineVariant.withOpacity(0.6),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (granted)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF06D6A0),
              ),
            )
          else
            FilledButton.tonal(
              onPressed: busy ? null : onRequest,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                backgroundColor: accent.withOpacity(0.18),
                foregroundColor: accent,
              ),
              child: busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Allow',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String description;
  final bool isPermissionPage;

  const _OnboardingPage({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.description,
    this.isPermissionPage = false,
  });
}

class _OnboardingPageView extends StatelessWidget {
  final _OnboardingPage page;
  const _OnboardingPageView({required this.page});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: page.color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(page.icon, size: 60, color: page.color),
          ),
          const SizedBox(height: 40),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: page.color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
