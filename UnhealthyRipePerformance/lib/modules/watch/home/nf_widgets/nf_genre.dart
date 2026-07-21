// Copied verbatim from flutter_netflix — genre.dart
import 'package:flutter/material.dart';

class NfGenre extends StatelessWidget {
  const NfGenre({super.key, this.color, required this.genres});

  final Color?       color;
  final List<String> genres;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style:    DefaultTextStyle.of(context).style,
        children: _buildSpan(),
      ),
    );
  }

  List<TextSpan> _buildSpan() {
    final dot = TextSpan(text: ' • ', style: TextStyle(color: color));
    final spans = <TextSpan>[];
    for (final g in genres) {
      spans.add(TextSpan(text: g));
      spans.add(dot);
    }
    if (spans.isNotEmpty) spans.removeLast();
    return spans;
  }
}
