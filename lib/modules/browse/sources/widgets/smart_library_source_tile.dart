import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/models/manga.dart';

/// Browser entry for the on-device index. It is intentionally separate from
/// Local Source, which opens the user-managed Watchtower/local folder.
class SmartLibrarySourceTile extends StatelessWidget {
  final ItemType itemType;

  const SmartLibrarySourceTile({required this.itemType, super.key});

  @override
  Widget build(BuildContext context) {
    final isManga = itemType == ItemType.manga;
    final accent = isManga
        ? const Color(0xFF8B7CFF)
        : const Color(0xFF54C6B1);

    return Card(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      elevation: 0,
      child: ListTile(
        leading: Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accent, accent.withValues(alpha: 0.62)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isManga ? Icons.auto_stories_rounded : Icons.video_library_rounded,
            color: Colors.white,
          ),
        ),
        title: Text(
          isManga ? 'Smart Library Manga' : 'Smart Library Watch',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          isManga
              ? 'Index CBZ et dossiers manga sur cet appareil'
              : 'Index vidéos stockées sur cet appareil',
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.pushNamed('localWatchHome', extra: itemType),
      ),
    );
  }
}