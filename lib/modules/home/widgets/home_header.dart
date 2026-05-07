import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// AnymeX-style home header with scroll-aware frosted-glass effect.
/// Passe scrollOffset depuis le parent pour activer le BackdropFilter
/// progressivement (comme AnymeX transculentBar).
class HomeHeader extends StatelessWidget {
  final double scrollOffset;
  const HomeHeader({super.key, this.scrollOffset = 0});

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
              padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Logo + greeting ────────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _AppIcon(cs: cs),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Hey, Guest 👋',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: cs.onSurface,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            'What are we doing today?',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurface.withValues(alpha: 0.50),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  // ── Account 3-D button ──────────────────────────────────
                  Account3DButton(onTap: () => _showAccountSheet(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── App icon with subtle glow ─────────────────────────────────────────────────

class _AppIcon extends StatelessWidget {
  final ColorScheme cs;
  const _AppIcon({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.22),
            blurRadius: 12,
          ),
        ],
      ),
      child: Image.asset(
        'assets/app_icons/icon.png',
        width: 38,
        height: 38,
        errorBuilder: (_, __, ___) => Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [cs.primary, cs.tertiary],
            ),
          ),
          child: const Icon(Icons.visibility_rounded,
              color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

// ── 3-D gradient account button — partagé avec LibraryHeaderBar ───────────────

class Account3DButton extends StatelessWidget {
  final VoidCallback onTap;
  final double size;
  const Account3DButton({super.key, required this.onTap, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cs.primary.withValues(alpha: 0.92),
                cs.tertiary.withValues(alpha: 0.86),
                cs.secondary.withValues(alpha: 0.86),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withValues(alpha: 0.38),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.24),
              width: 1.2,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Sheen gloss
              Positioned(
                top: 4,
                left: size * 0.17,
                right: size * 0.17,
                child: Container(
                  height: size * 0.22,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.45),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Icon(Icons.person_rounded,
                  color: Colors.white, size: size * 0.50),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Account bottom sheet — frosted glass ──────────────────────────────────────

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
                                  color:
                                      cs.onSurface.withValues(alpha: 0.52)),
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
                    },
                  ),
                  _SheetTile(
                    icon: Icons.track_changes_outlined,
                    label: 'Tracking',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/trackerLibrary');
                    },
                  ),
                  _SheetTile(
                    icon: Icons.history_outlined,
                    label: 'History',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/history');
                    },
                  ),
                  _SheetTile(
                    icon: Icons.download_outlined,
                    label: 'Downloads',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/more');
                    },
                  ),
                  _SheetTile(
                    icon: Icons.info_outline_rounded,
                    label: 'About Watchtower',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/more');
                    },
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
