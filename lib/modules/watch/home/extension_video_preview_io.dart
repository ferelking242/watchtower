import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:watchtower/eval/model/m_manga.dart';

Future<void> showExtensionVideoPreview({
  required BuildContext context,
  required MManga item,
  required String previewUrl,
  required VoidCallback onOpen,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _ExtensionVideoPreviewDialog(
      item: item,
      previewUrl: previewUrl,
      onOpen: onOpen,
    ),
  );
}

class _ExtensionVideoPreviewDialog extends StatefulWidget {
  final MManga item;
  final String previewUrl;
  final VoidCallback onOpen;

  const _ExtensionVideoPreviewDialog({
    required this.item,
    required this.previewUrl,
    required this.onOpen,
  });

  @override
  State<_ExtensionVideoPreviewDialog> createState() =>
      _ExtensionVideoPreviewDialogState();
}

class _ExtensionVideoPreviewDialogState
    extends State<_ExtensionVideoPreviewDialog> {
  late final Player _player;
  late final VideoController _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    unawaited(_startPreview());
  }

  Future<void> _startPreview() async {
    try {
      await _player.setVolume(0);
      await _player.open(
        Media(
          widget.previewUrl,
          httpHeaders: const {
            'Referer': 'https://www.xnxx.com/',
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          },
        ),
        play: true,
      );
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.item.name?.trim().isNotEmpty == true
        ? widget.item.name!.trim()
        : 'Aperçu vidéo';
    return Dialog(
      backgroundColor: const Color(0xFF111218),
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: _failed
                    ? _PreviewUnavailable(imageUrl: widget.item.imageUrl)
                    : Video(
                        controller: _controller,
                        controls: NoVideoControls,
                        fit: BoxFit.contain,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onOpen();
                    },
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Ouvrir'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewUnavailable extends StatelessWidget {
  final String? imageUrl;

  const _PreviewUnavailable({this.imageUrl});

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      if (imageUrl?.trim().isNotEmpty == true)
        Image.network(
          imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ColoredBox(
        color: Colors.black.withValues(alpha: .72),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off_rounded, color: Colors.white70, size: 34),
              SizedBox(height: 8),
              Text(
                'Aperçu temporairement indisponible',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}