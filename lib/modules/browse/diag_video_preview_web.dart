import 'package:flutter/material.dart';
import 'package:watchtower/services/extension_diagnostics.dart';

class DiagVideoPreview extends StatelessWidget {
  final List<DiagMediaUrl> urls;
  final ColorScheme cs;

  const DiagVideoPreview({required this.urls, required this.cs, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(Icons.info_outline_rounded,
            size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          'Prévisualisation vidéo non disponible sur web.',
          style: TextStyle(
              fontSize: 12, color: cs.onSurfaceVariant),
        ),
      ]),
    );
  }
}
