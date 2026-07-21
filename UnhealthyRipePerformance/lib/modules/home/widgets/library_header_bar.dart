import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/main_view/main_screen.dart' show menuOpenProvider;

/// AnymeX-style discovery tab header — Watch, Manga, Novel tabs.
/// LEFT  — drawer/menu button
/// RIGHT — frosted-glass search button (icône Iconsax-style)
class LibraryHeaderBar extends ConsumerWidget {
  final ItemType itemType;
  final double scrollOffset;
  final VoidCallback? onOpenDrawer;
  const LibraryHeaderBar(
      {super.key,
      this.itemType = ItemType.anime,
      this.scrollOffset = 0,
      this.onOpenDrawer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  // ── Drawer button (clean, transparent header) ─────────
                  _DrawerButton(
                    onTap: onOpenDrawer ??
                        () => ref.read(menuOpenProvider.notifier).state =
                            !ref.read(menuOpenProvider),
                  ),
                  const Spacer(),

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

// ── Frosted-glass drawer (menu) button ─────────────────────────────────────────

class _DrawerButton extends StatelessWidget {
  final VoidCallback onTap;
  const _DrawerButton({required this.onTap});

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
                Broken.menu_1,
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
                Broken.search_normal_1,
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

