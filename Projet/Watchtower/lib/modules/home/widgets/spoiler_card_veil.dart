import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────────────────────
// C-08  Spoiler Mode  — blurs or masks cards the user hasn't seen yet
// ─────────────────────────────────────────────────────────────────────────────

// ── Provider ─────────────────────────────────────────────────────────────────

/// Global toggle: when true, unseen cards are blurred.
final spoilerModeProvider = StateProvider<bool>((ref) => false);

// ── Veil widget ───────────────────────────────────────────────────────────────

/// Wrap any card child with this widget. When [spoilerMode] is enabled and
/// [isSeen] is false, the child is blurred and a reveal button is shown.
class SpoilerCardVeil extends ConsumerStatefulWidget {
  final Widget child;
  final bool isSeen;

  const SpoilerCardVeil({
    super.key,
    required this.child,
    this.isSeen = false,
  });

  @override
  ConsumerState<SpoilerCardVeil> createState() => _SpoilerCardVeilState();
}

class _SpoilerCardVeilState extends ConsumerState<SpoilerCardVeil> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final spoilerMode = ref.watch(spoilerModeProvider);
    final shouldBlur = spoilerMode && !widget.isSeen && !_revealed;

    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        if (shouldBlur) ...[
          // Blur overlay
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
          // Reveal button
          Positioned.fill(
            child: Center(
              child: GestureDetector(
                onTap: () => setState(() => _revealed = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35), width: 0.8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility_off_rounded,
                          size: 13, color: Colors.white70),
                      SizedBox(width: 5),
                      Text(
                        'Révéler',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Toggle button for settings/toolbar ───────────────────────────────────────

class SpoilerModeToggle extends ConsumerWidget {
  const SpoilerModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(spoilerModeProvider);
    final cs = Theme.of(context).colorScheme;

    return Tooltip(
      message: enabled ? 'Désactiver le mode spoiler' : 'Activer le mode spoiler',
      child: GestureDetector(
        onTap: () => ref.read(spoilerModeProvider.notifier).state = !enabled,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: enabled
                ? cs.primary.withValues(alpha: 0.15)
                : cs.onSurface.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: enabled
                  ? cs.primary.withValues(alpha: 0.45)
                  : cs.outlineVariant.withValues(alpha: 0.25),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                enabled ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                size: 15,
                color: enabled ? cs.primary : cs.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 5),
              Text(
                'Spoiler',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: enabled
                      ? cs.primary
                      : cs.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
