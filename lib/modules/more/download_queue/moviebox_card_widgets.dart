import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/utils/cached_network.dart';

// MovieBox-style palette shared by the download queue cards.
const Color mbGreen = Color(0xFF27C46B);
const Color mbTeal = Color(0xFF00BFA5);
const Color mbAmber = Color(0xFFFFB300);
const Color mbRed = Color(0xFFFF5252);

/// Landscape cover thumbnail: centered play overlay for video rows and a
/// bottom-left source badge on a dark scrim — MovieBox signature.
class MbThumb extends StatelessWidget {
  final String? imageUrl;
  final List<dynamic>? customBytes;
  final ItemType itemType;
  final String badge;
  final bool isVideo;

  const MbThumb({
    super.key,
    required this.imageUrl,
    required this.customBytes,
    required this.itemType,
    required this.badge,
    required this.isVideo,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Keep the poster compact like MovieBox: the queue is a list first, not
    // a gallery. This leaves room for the real byte progress and actions.
    const w = 96.0;
    const h = 54.0;
    final placeholder = Container(
      width: w,
      height: h,
      color: scheme.surfaceContainerHigh,
      child: Icon(
        itemType == ItemType.anime
            ? Icons.play_circle_outline
            : itemType == ItemType.novel
                ? Icons.auto_stories_outlined
                : Icons.menu_book_outlined,
        color: scheme.onSurfaceVariant.withValues(alpha: 0.35),
        size: 24,
      ),
    );

    Widget image = placeholder;
    if (customBytes != null && customBytes!.isNotEmpty) {
      try {
        image = Image.memory(
          Uint8List.fromList(customBytes!.cast<int>()),
          width: w,
          height: h,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder,
        );
      } catch (_) {}
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      image = cachedNetworkImage(
        imageUrl: imageUrl!,
        width: w,
        height: h,
        fit: BoxFit.cover,
        errorWidget: placeholder,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
            if (badge.isNotEmpty)
              Align(
                alignment: Alignment.bottomLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                      colors: [Color(0xB3000000), Color(0x00000000)],
                    ),
                  ),
                  constraints: const BoxConstraints(maxWidth: 116),
                  child: Text(
                    badge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xF2FFFFFF),
                      fontSize: 7,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            if (isVideo)
              Center(
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: Color(0x66000000),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Right rail: compact 3-dot overflow menu (pause/resume, retry, open,
/// cancel, delete) above the gradient circular action button — MovieBox style.
/// All handlers are the screen's existing callbacks; no logic lives here.
class MbRowActions extends StatelessWidget {
  final bool isComplete;
  final bool hasFailed;
  final bool isPaused;
  final VoidCallback onPauseResume;
  final VoidCallback onCancel;
  final VoidCallback onDelete;
  final VoidCallback onRetry;
  final VoidCallback onOpen;

  const MbRowActions({
    super.key,
    required this.isComplete,
    required this.hasFailed,
    required this.isPaused,
    required this.onPauseResume,
    required this.onCancel,
    required this.onDelete,
    required this.onRetry,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final gradient = hasFailed
        ? const LinearGradient(colors: [mbRed, Color(0xFFFF7043)])
        : isComplete
            ? const LinearGradient(colors: [mbTeal, mbGreen])
            : const LinearGradient(colors: [mbGreen, mbTeal]);
    final icon = isComplete
        ? Icons.folder_open_rounded
        : hasFailed
            ? Icons.refresh_rounded
            : isPaused
                ? Icons.play_arrow_rounded
                : Icons.pause_rounded;
    final onTap = hasFailed
        ? onRetry
        : isComplete
            ? onOpen
            : onPauseResume;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(
            Icons.more_vert_rounded,
            size: 18,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
          onSelected: (v) {
            switch (v) {
              case 'pause':
                onPauseResume();
                break;
              case 'cancel':
                onCancel();
                break;
              case 'retry':
                onRetry();
                break;
              case 'delete':
                onDelete();
                break;
              case 'open':
                onOpen();
                break;
            }
          },
          itemBuilder: (_) => [
            if (!isComplete)
              PopupMenuItem(
                value: 'pause',
                height: 40,
                child: Row(
                  children: [
                    Icon(
                      isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      size: 17,
                      color: mbAmber,
                    ),
                    const SizedBox(width: 10),
                    Text(isPaused ? 'Reprendre' : 'Pause',
                        style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            if (hasFailed)
              PopupMenuItem(
                value: 'retry',
                height: 40,
                child: Row(
                  children: [
                    const Icon(Icons.refresh_rounded, size: 17, color: mbRed),
                    const SizedBox(width: 10),
                    const Text('Réessayer', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            if (isComplete)
              PopupMenuItem(
                value: 'open',
                height: 40,
                child: Row(
                  children: [
                    const Icon(Icons.folder_open_rounded,
                        size: 17, color: mbTeal),
                    const SizedBox(width: 10),
                    const Text('Ouvrir', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            PopupMenuItem(
              value: 'cancel',
              height: 40,
              child: Row(
                children: [
                  Icon(Icons.close_rounded, size: 17,
                      color: scheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  const Text('Annuler', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              height: 40,
              child: Row(
                children: [
                  const Icon(Icons.delete_outline_rounded,
                      size: 17, color: Colors.redAccent),
                  const SizedBox(width: 10),
                  const Text('Supprimer',
                      style: TextStyle(fontSize: 13, color: Colors.redAccent)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: gradient,
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      ],
    );
  }
}
