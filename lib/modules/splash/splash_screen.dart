import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const _kPreloadUrls = [
  'https://cdn.myanimelist.net/images/anime/1141/142503l.jpg',
  'https://cdn.myanimelist.net/images/anime/1277/142022l.jpg',
  'https://cdn.myanimelist.net/images/anime/1305/132237l.jpg',
  'https://cdn.myanimelist.net/images/anime/1770/97704l.jpg',
  'https://cdn.myanimelist.net/images/anime/10/47347l.jpg',
  'https://cdn.myanimelist.net/images/anime/1286/99889l.jpg',
  'https://cdn.myanimelist.net/images/anime/1171/109222l.jpg',
  'https://cdn.myanimelist.net/images/anime/1541/147774l.jpg',
  'https://cdn.myanimelist.net/images/manga/1/157897l.jpg',
  'https://cdn.myanimelist.net/images/manga/1/259070l.jpg',
  'https://cdn.myanimelist.net/images/manga/2/188925l.jpg',
  'https://image.tmdb.org/t/p/w500/ztkUQFLlC19CCMYHW9o1zWhJRNq.jpg',
  'https://image.tmdb.org/t/p/w500/abf8tHznhSvl9BAElD2cQeRr7do.jpg',
  'https://image.tmdb.org/t/p/w500/4fVddnbhcmzRZE14NJY03GKS6Fn.jpg',
  'https://image.tmdb.org/t/p/w500/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg',
  'https://image.tmdb.org/t/p/w500/7O4iVfOMQmdCSxhOg1WnzG1AgYT.jpg',
];

class WatchtowerSplashScreen extends StatefulWidget {
  final String destination;
  const WatchtowerSplashScreen({super.key, required this.destination});

  @override
  State<WatchtowerSplashScreen> createState() => _WatchtowerSplashScreenState();
}

class _WatchtowerSplashScreenState extends State<WatchtowerSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _nameSlide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.70, curve: Curves.easeOut),
    );
    _nameSlide = Tween<double>(begin: 18, end: 0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.30, 1.0, curve: Curves.easeOut),
      ),
    );
    _ctrl.forward();

    Future.delayed(const Duration(milliseconds: 1700), () {
      if (mounted) context.go(widget.destination);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final url in _kPreloadUrls) {
      precacheImage(NetworkImage(url), context);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Stack(
          children: [
            // ── Centered logo ────────────────────────────────────────────
            Center(
              child: FadeTransition(
                opacity: _fade,
                child: Image.asset(
                  'assets/app_icons/icon.png',
                  width: screenH * 0.40,
                  height: screenH * 0.40,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // ── App name + tagline at bottom ──────────────────────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 52),
                  child: FadeTransition(
                    opacity: _fade,
                    child: Transform.translate(
                      offset: Offset(0, _nameSlide.value),
                      child: Column(
                        children: [
                          const Text(
                            'Watchtower',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Anime · Manga · Films · Séries',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.35),
                              fontSize: 12,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
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
