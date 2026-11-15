import 'package:flutter/material.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/providers/l10n_providers.dart';

Future<void> showExtensionVideoPreview({
  required BuildContext context,
  required MManga item,
  required String previewUrl,
  required VoidCallback onOpen,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: const Color(0xFF171820),
      title: Text(
        item.name?.trim().isNotEmpty == true
            ? item.name!
            : context.l10n.common_preview,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.imageUrl?.trim().isNotEmpty == true)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                item.imageUrl!,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            context.l10n.video_preview_unavailable,
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Fermer'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            onOpen();
          },
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Ouvrir la vidéo'),
        ),
      ],
    ),
  );
}