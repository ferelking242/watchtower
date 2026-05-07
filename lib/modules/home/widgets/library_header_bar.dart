import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/home/widgets/home_header.dart';

/// AnymeX-style discovery tab header — Watch, Manga, Novel tabs.
/// LEFT  — 3-D gradient account button + greeting
/// RIGHT — frosted-glass search button (icône Iconsax-style)
class LibraryHeaderBar extends StatelessWidget {
  final ItemType itemType;
  final double scrollOffset;
  const LibraryHeaderBar(
      {super.key, this.itemType = ItemType.anime, this.scrollOffset = 0});

  void _showAccountSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AccountSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final blurProgress = (scrollOffset / 56).clamp(0.0, 1.0);
    final isBlurred = scrollOffset > 8;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: isBlurred
            ? cs.surface.withValues(alpha: blurProgress * 0.60)
            : Colors.transparent,
        border: isBlurred
            ? Border(
                bottom: BorderSide(
                  color: cs.outline.withValues(alpha: blurProgress * 0.10),
                  width: 0.8,
                ),
              )
            : null,
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: isBlurred ? 18 * blurProgress : 0,
            sigmaY: isBlurred ? 18 * blurProgress : 0,
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Account 3-D button ────────────────────────────────
                  Account3DButton(
                    onTap: () => _showAccountSheet(context),
                    size: 42,
                  ),
                  const SizedBox(width: 12),

                  // ── Greeting ──────────────────────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Hey, Guest 👋',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          'What are we doing today?',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface.withValues(alpha: 0.48),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Search button ─────────────────────────────────────
                  _SearchButton(
                    onTap: () => context.push('/globalSearch',
                        extra: (null as String?, itemType)),
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

// ── Frosted-glass search button ───────────────────────────────────────────────

class _SearchButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: cs.outline.withValues(alpha: 0.16),
                  width: 0.8,
                ),
              ),
              child: Icon(
                Icons.search_rounded,
                color: cs.onSurface,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Account sheet (frosted glass) ─────────────────────────────────────────────

class _AccountSheet extends StatelessWidget {
  const _AccountSheet();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.88),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                color: cs.outline.withValues(alpha: 0.12),
                width: 0.8,
              ),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: cs.onSurface.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [cs.primary, cs.tertiary],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: cs.primary.withValues(alpha: 0.32),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.person_rounded,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Guest',
                                style: tt.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800)),
                            Text(
                              'Connect a tracker to sync your lists',
                              style: tt.bodySmall?.copyWith(
                                  color: cs.onSurface.withValues(alpha: 0.52)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Divider(color: cs.outlineVariant.withValues(alpha: 0.40)),
                  const SizedBox(height: 4),
                  _SheetTile(
                      icon: Icons.settings_outlined,
                      label: 'Settings',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/more');
                      }),
                  _SheetTile(
                      icon: Icons.track_changes_outlined,
                      label: 'Tracking',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/trackerLibrary');
                      }),
                  _SheetTile(
                      icon: Icons.history_outlined,
                      label: 'History',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/history');
                      }),
                  _SheetTile(
                      icon: Icons.info_outline_rounded,
                      label: 'About',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/more');
                      }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SheetTile(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: cs.primary, size: 20),
      ),
      title: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      trailing: Icon(Icons.chevron_right_rounded,
          color: cs.onSurface.withValues(alpha: 0.30)),
      onTap: onTap,
    );
  }
}
