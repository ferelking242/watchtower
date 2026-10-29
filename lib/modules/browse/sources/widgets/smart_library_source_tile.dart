import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/more/settings/downloads/smart_library_icon.dart';
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
    final isManga = itemType == ItemType.manga;
    final theme = Theme.of(context);

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
          child: SmartLibraryIcon(
            isManga: isManga,
            color: theme.colorScheme.primary,
            size: 26,
          ),
        ),
      ),
      title: Text(
        isManga ? 'Smart Library Manga' : 'Smart Library Watch',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        completeLanguageName('multi'),
        style: const TextStyle(fontWeight: FontWeight.w300, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}
