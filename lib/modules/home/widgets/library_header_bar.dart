import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared header used at the top of the Watch and Manga discovery tabs.
/// Replaces the old Home screen header (Watchtower brand left,
/// 3D-style account icon right that opens /more).
class LibraryHeaderBar extends StatelessWidget {
  const LibraryHeaderBar({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
      child: Row(
        children: [
          Image.asset(
            'assets/app_icons/icon.png',
            width: 30,
            height: 30,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.visibility_outlined, color: cs.primary, size: 26),
          ),
          const SizedBox(width: 10),
          Text(
            'Watchtower',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: cs.onSurface,
            ),
          ),
          const Spacer(),
          const _Account3DIcon(),
        ],
      ),
    );
  }
}

class _Account3DIcon extends StatelessWidget {
  const _Account3DIcon();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/more'),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cs.primary.withValues(alpha: 0.85),
                cs.tertiary.withValues(alpha: 0.85),
                cs.secondary.withValues(alpha: 0.85),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1.2,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // top highlight (3D effect)
              Positioned(
                top: 4,
                left: 8,
                right: 8,
                child: Container(
                  height: 10,
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
              const Icon(Icons.person_rounded,
                  color: Colors.white, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
