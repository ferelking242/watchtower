import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/more/settings/downloads/smart_library_icon.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/utils/language.dart';

/// Browser entry for the on-device index. It is intentionally separate from
/// Local Source, which opens the user-managed Watchtower/local folder.
///
/// Rendered with the same chrome as [SourceListTile] so the local index reads
/// as just another extension: neutral icon well on the left, name, and a
/// language line underneath.
class SmartLibrarySourceTile extends StatelessWidget {
  final ItemType itemType;

  const SmartLibrarySourceTile({required this.itemType, super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final String title;
    if (itemType == ItemType.music) {
      title = l10n.smart_library_music_title;
    } else if (itemType == ItemType.manga) {
      title = l10n.smart_library_manga_title;
    } else {
      title = l10n.smart_library_watch_title;
    }

    // Same chrome as [SourceListTile]: a neutral 37px icon well on the left,
    // the name, and the language line underneath. `completeLanguageName('multi')`
    // yields the localised "Multi-language" string the extension list uses.
    return ListTile(
      onTap: () => context.pushNamed('localWatchHome', extra: itemType),
      leading: Container(
        height: 37,
        width: 37,
        decoration: BoxDecoration(
          color: theme.secondaryHeaderColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Center(
          child: itemType == ItemType.music
              ? Icon(
                  Icons.music_note_rounded,
                  color: theme.colorScheme.primary,
                  size: 22,
                )
              : SmartLibraryIcon(
                  isManga: itemType == ItemType.manga,
                  color: theme.colorScheme.primary,
                  size: 26,
                ),
        ),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        completeLanguageName('multi'),
        style: const TextStyle(fontWeight: FontWeight.w300, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}
