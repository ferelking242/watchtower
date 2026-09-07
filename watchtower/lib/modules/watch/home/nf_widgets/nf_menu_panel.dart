// Right-edge sidebar menu for the watch home screen.
// Opened by the hamburger in the app bar: a dimmed barrier + frosted glass
// panel listing every destination of the extension home (search, categories,
// playlist rows, new & popular, catalogue). Search pushes the full-page
// search view; every other row drills into the full section page.
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';
import 'package:watchtower/models/source.dart';
import 'nf_utils.dart';

// ── Menu data ──────────────────────────────────────────────────────────────────

class NfMenuTile {
  const NfMenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = false,
  });

  final IconData     icon;
  final String       label;
  final VoidCallback onTap;
  final bool         accent;
}

class NfMenuGroup {
  const NfMenuGroup({this.title, required this.tiles});

  final String?        title;
  final List<NfMenuTile> tiles;
}

// ── Panel ─────────────────────────────────────────────────────────────────────

class NfWatchMenuPanel extends StatelessWidget {
  const NfWatchMenuPanel({
    super.key,
    required this.source,
    required this.groups,
    required this.onClose,
  });

  final Source           source;
  final List<NfMenuGroup> groups;
  final VoidCallback     onClose;

  @override
  Widget build(BuildContext context) {
    final iconUrl = source.iconUrl ?? '';
    final version = (source.version ?? '').trim();
    final lang = (source.lang ?? '').toUpperCase();
    final subtitle = [
      if (lang.isNotEmpty) lang,
      if (version.isNotEmpty) 'v$version',
    ].join(' · ');

    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius:
            const BorderRadius.horizontal(left: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xF50E0E10),
              border: Border(
                left: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header: extension identity + close ───────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 8, 12),
                    child: Row(
                      children: [
                        _PanelBrandIcon(iconUrl: iconUrl),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                source.name ?? source.lang ?? 'Source',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color:          Colors.white,
                                  fontSize:       16,
                                  fontWeight:     FontWeight.w800,
                                  letterSpacing:  -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  color: Colors.white
                                      .withValues(alpha: 0.34),
                                  fontSize:   10.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap:    onClose,
                          child: Container(
                            width:      36,
                            height:     36,
                            alignment:  Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.07),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.10),
                              ),
                            ),
                            child: const Icon(Icons.close_rounded,
                                size: 17, color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    color:  Colors.white.withValues(alpha: 0.06),
                  ),
                  const SizedBox(height: 4),

                  // ── Scrollable sections ─────────────────────────────
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(10, 4, 10, 14),
                      children: [
                        for (final g in groups) ...[
                          if ((g.title ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  12, 12, 12, 6),
                              child: Text(
                                g.title!,
                                style: TextStyle(
                                  color: Colors.white
                                      .withValues(alpha: 0.34),
                                  fontSize:   10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.4,
                                ),
                              ),
                            ),
                          for (final t in g.tiles)
                            _SideMenuTile(tile: t),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelBrandIcon extends StatelessWidget {
  const _PanelBrandIcon({required this.iconUrl});

  final String iconUrl;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color:     Colors.grey[850]!,
      alignment: Alignment.center,
      child: const Icon(Icons.play_circle_fill_rounded,
          size: 20, color: Colors.white24),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width:  40,
        height: 40,
        child: iconUrl.isEmpty
            ? fallback
            : ExtendedImage.network(
                iconUrl,
                fit:             BoxFit.cover,
                loadStateChanged: (state) =>
                    state.extendedImageLoadState == LoadState.failed
                        ? fallback
                        : null,
              ),
      ),
    );
  }
}

// ── One sidebar row ────────────────────────────────────────────────────────────

class _SideMenuTile extends StatelessWidget {
  const _SideMenuTile({super.key, required this.tile});

  final NfMenuTile tile;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap:    tile.onTap,
      child: Container(
        height:      50,
        margin:      const EdgeInsets.only(bottom: 4),
        padding:     const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color:        Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            Container(
              width:      32,
              height:     32,
              alignment:  Alignment.center,
              decoration: BoxDecoration(
                color: tile.accent
                    ? nfRedColor.withValues(alpha: 0.20)
                    : Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                tile.icon,
                size:  17,
                color: tile.accent
                    ? const Color(0xFFFF6B6B)
                    : Colors.white.withValues(alpha: 0.92),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tile.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tile.accent
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.88),
                  fontSize:   14,
                  fontWeight:
                      tile.accent ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
            if (!tile.accent)
              Icon(Icons.chevron_right_rounded,
                  size: 17, color: Colors.white.withValues(alpha: 0.20)),
          ],
        ),
      ),
    );
  }
}
