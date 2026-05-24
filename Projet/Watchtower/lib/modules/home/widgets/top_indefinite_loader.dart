import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────────────────────
// N-10  Top Indefinite Loader
// A thin 3 px progress bar pinned to the very top of the screen that slides
// whenever any async operation is in flight.
// ─────────────────────────────────────────────────────────────────────────────

// ── Provider ─────────────────────────────────────────────────────────────────

/// Increment to show the loader, decrement to hide.
/// Widget auto-hides when count reaches 0.
final topLoaderProvider = StateNotifierProvider<_TopLoaderNotifier, int>(
  (_) => _TopLoaderNotifier(),
);

class _TopLoaderNotifier extends StateNotifier<int> {
  _TopLoaderNotifier() : super(0);

  void show() => state = state + 1;
  void hide() => state = (state - 1).clamp(0, 9999);
}

// ── Convenience helpers ───────────────────────────────────────────────────────

void showTopLoader(WidgetRef ref) => ref.read(topLoaderProvider.notifier).show();
void hideTopLoader(WidgetRef ref) => ref.read(topLoaderProvider.notifier).hide();

// ── Widget ────────────────────────────────────────────────────────────────────

class TopIndefiniteLoader extends ConsumerStatefulWidget {
  const TopIndefiniteLoader({super.key});

  @override
  ConsumerState<TopIndefiniteLoader> createState() =>
      _TopIndefiniteLoaderState();
}

class _TopIndefiniteLoaderState extends ConsumerState<TopIndefiniteLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pos;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    // The animated "pulse" travels from -0.4 to 1.0 in relative offset
    _pos = Tween<double>(begin: -0.5, end: 1.2).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = ref.watch(topLoaderProvider);
    final visible = count > 0;
    final color = Theme.of(context).colorScheme.primary;

    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: SizedBox(
        height: 3,
        child: AnimatedBuilder(
          animation: _pos,
          builder: (_, __) {
            return CustomPaint(
              painter: _LoaderPainter(
                progress: _pos.value,
                color: color,
              ),
              size: const Size(double.infinity, 3),
            );
          },
        ),
      ),
    );
  }
}

// ── Painter ───────────────────────────────────────────────────────────────────

class _LoaderPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _LoaderPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Thin track
    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), trackPaint);

    // Moving pulse — 40% of bar width
    const pulseWidth = 0.4;
    final left = (progress - pulseWidth / 2) * size.width;
    final right = (progress + pulseWidth / 2) * size.width;
    final gradient = LinearGradient(
      colors: [
        color.withValues(alpha: 0),
        color.withValues(alpha: 0.9),
        color,
        color.withValues(alpha: 0.9),
        color.withValues(alpha: 0),
      ],
      stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
    );
    final rect = Rect.fromLTWH(left, 0, right - left, size.height);
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_LoaderPainter old) =>
      old.progress != progress || old.color != color;
}
