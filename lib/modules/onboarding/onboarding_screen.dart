import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
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
  bool _permissionGranted = false;
  bool _requestingPermission = false;

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
      icon: Icons.folder_open_rounded,
      color: Color(0xFFFF6B6B),
      title: 'Storage Access',
      subtitle: 'One permission needed',
      description:
          'Watchtower needs access to your storage to download content, save covers, and manage your library files.',
      isPermissionPage: true,
    ),
  ];

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _requestPermission() async {
    if (_requestingPermission) return;
    setState(() => _requestingPermission = true);
    final granted = await StorageProvider().requestPermission();
    if (mounted) {
      setState(() {
        _permissionGranted = granted;
        _requestingPermission = false;
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
            if (!_permissionGranted)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _requestingPermission ? null : _requestPermission,
                  icon: _requestingPermission
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.folder_open_rounded),
                  label: Text(
                    _requestingPermission
                        ? 'Requesting…'
                        : 'Grant Storage Access',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: page.color,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            if (_permissionGranted) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF06D6A0).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF06D6A0),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Storage access granted',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF06D6A0),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _finish,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: _permissionGranted
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHighest,
                  foregroundColor: _permissionGranted
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
                ),
                child: const Text(
                  'Get Started',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            if (!_permissionGranted)
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
