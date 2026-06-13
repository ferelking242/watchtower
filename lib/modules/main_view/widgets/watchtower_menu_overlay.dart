import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class _MenuItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _MenuItem({
    required this.label,
    required this.icon,
    required this.onTap,
  });
}

class WatchtowerMenuOverlay extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  const WatchtowerMenuOverlay({super.key, required this.onClose});

  @override
  ConsumerState<WatchtowerMenuOverlay> createState() =>
      _WatchtowerMenuOverlayState();
}

class _WatchtowerMenuOverlayState
    extends ConsumerState<WatchtowerMenuOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<Animation<double>> _itemAnims;

  static const _itemCount = 5;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _itemAnims = List.generate(_itemCount, (i) {
      final start = i * 0.07;
      final end = (start + 0.5).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _ctrl,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      );
    });

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _ctrl.reverse();
    widget.onClose();
  }

  Future<void> _navigate(String route) async {
    await _close();
    if (mounted) context.go(route);
  }

  List<_MenuItem> _buildItems() => [
        _MenuItem(
          label: 'More',
          icon: Icons.apps_rounded,
          onTap: () => _navigate('/more'),
        ),
        _MenuItem(
          label: 'Extensions',
          icon: Icons.extension_rounded,
          onTap: () => _navigate('/browse'),
        ),
        _MenuItem(
          label: 'Schedule',
          icon: Icons.calendar_month_rounded,
          onTap: () => _navigate('/schedule'),
        ),
        _MenuItem(
          label: 'Updates',
          icon: Icons.new_releases_rounded,
          onTap: () => _navigate('/updates'),
        ),
        _MenuItem(
          label: 'History',
          icon: Icons.history_rounded,
          onTap: () => _navigate('/history'),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final items = _buildItems();

    final dockBottom = 14.0 + 64.0 + mq.padding.bottom;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final bg = (_ctrl.value * 0.6).clamp(0.0, 0.6);
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _close();
                },
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: _ctrl.value * 4,
                    sigmaY: _ctrl.value * 4,
                  ),
                  child: Container(
                    color: Colors.black.withValues(alpha: bg),
                  ),
                ),
              ),
            ),

            Positioned(
              right: 12,
              bottom: dockBottom + 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < items.length; i++) ...[
                    _AnimatedMenuItem(
                      item: items[i],
                      animation: _itemAnims[i],
                      isDark: isDark,
                      cs: cs,
                    ),
                    if (i < items.length - 1)
                      const SizedBox(height: 10),
                  ],
                ],
              ),
            ),

            Positioned(
              right: 12,
              bottom: mq.padding.bottom + 7,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _close();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1B1B1E)
                        : cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.10)
                          : Colors.black.withValues(alpha: 0.08),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                        blurRadius: 16,
                        spreadRadius: -2,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Transform.rotate(
                        angle: _ctrl.value * 3.14159 / 4,
                        child: Icon(
                          Icons.close_rounded,
                          color: cs.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Menu',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AnimatedMenuItem extends StatelessWidget {
  final _MenuItem item;
  final Animation<double> animation;
  final bool isDark;
  final ColorScheme cs;

  const _AnimatedMenuItem({
    required this.item,
    required this.animation,
    required this.isDark,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final v = animation.value;
        return Transform.translate(
          offset: Offset((1 - v) * 40, 0),
          child: Opacity(
            opacity: v,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                item.onTap();
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.10)
                          : Colors.black.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                        height: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.10)
                          : Colors.black.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      item.icon,
                      size: 20,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.85)
                          : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
