import 'package:flutter/material.dart';

/// A compact, resolution-free empty-state glyph.
///
/// A kaomoji is plain text: it stays sharp at any size, weighs nothing next to
/// a Lottie file, and is trivial to position. Use it wherever a section only
/// needs to say "nothing here"; the animated illustration stays reserved for
/// full-page failure states, which carry more meaning than a bare glyph.
class KaomojiEmpty extends StatelessWidget {
  const KaomojiEmpty({
    super.key,
    this.kaomoji = '(・_・;)',
    this.size = 20,
    this.color,
    this.message,
    this.messageStyle,
  });

  /// The glyph itself. Kept as a parameter so a surface can pick the face that
  /// fits its tone instead of all empty states sharing one.
  final String kaomoji;
  final double size;
  final Color? color;

  /// Optional caption rendered under the glyph.
  final String? message;
  final TextStyle? messageStyle;

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? Colors.white54;
    final caption = message?.trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          kaomoji,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: resolved,
            fontSize: size,
            height: 1.1,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (caption != null && caption.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            caption,
            textAlign: TextAlign.center,
            style:
                messageStyle ??
                TextStyle(color: resolved, fontSize: size * 0.62),
          ),
        ],
      ],
    );
  }
}
