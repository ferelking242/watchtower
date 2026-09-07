import 'dart:ui';
import 'package:flutter/material.dart';

enum GlassButtonIntent { primary, gray, white }

class GlassButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final GlassButtonIntent intent;
  final bool pill;
  final VoidCallback? onTap;
  final VoidCallback? onPressed;
  final double? fontSize;
  final double? height;

  const GlassButton({
    super.key,
    required this.label,
    this.icon,
    this.intent = GlassButtonIntent.primary,
    this.pill = false,
    this.onTap,
    this.onPressed,
    this.fontSize,
    this.height,
  });

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  bool _pressed = false;

  VoidCallback? get _callback => widget.onTap ?? widget.onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final bgColor = switch (widget.intent) {
      GlassButtonIntent.primary => cs.primary.withValues(alpha: _pressed ? 0.32 : 0.20),
      GlassButtonIntent.gray    => cs.onSurface.withValues(alpha: _pressed ? 0.18 : 0.10),
      GlassButtonIntent.white   => Colors.white.withValues(alpha: _pressed ? 0.22 : 0.13),
    };

    final textColor = switch (widget.intent) {
      GlassButtonIntent.primary => cs.primary,
      GlassButtonIntent.gray    => cs.onSurface.withValues(alpha: 0.85),
      GlassButtonIntent.white   => Colors.white,
    };

    final borderColor = switch (widget.intent) {
      GlassButtonIntent.primary => cs.primary.withValues(alpha: 0.35),
      GlassButtonIntent.gray    => cs.onSurface.withValues(alpha: 0.18),
      GlassButtonIntent.white   => Colors.white.withValues(alpha: 0.30),
    };

    final radius = widget.pill ? 50.0 : 12.0;

    final double vPad = widget.height != null ? ((widget.height! - (widget.fontSize ?? 13) * 1.2) / 2).clamp(4, 20) : 10;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        _callback?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              height: widget.height,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: vPad),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: borderColor, width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: 16, color: textColor),
                    const SizedBox(width: 7),
                  ],
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: textColor,
                      fontSize: widget.fontSize ?? 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
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
