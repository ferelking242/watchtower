import 'package:flutter/material.dart';
import 'package:watchtower/eval/model/m_manga.dart';

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
      title: Text(item.name?.trim().isNotEmpty == true ? item.name! : 'Aperçu'),
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
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          const SizedBox(height: 12),
          const Text(
            'L’aperçu vidéo n’est pas disponible sur cette plateforme.',
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