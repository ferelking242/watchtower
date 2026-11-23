import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:share_plus/share_plus.dart';

import 'package:watchtower/eval/model/m_bridge.dart' show botToast;
import 'package:watchtower/main.dart';
import 'package:watchtower/models/download.dart';
import 'package:watchtower/modules/manga/download/providers/download_provider.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/more/settings/library/providers/library_settings_provider.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/modules/manga/reader/providers/reader_controller_provider.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/utils/extensions/chapter.dart';

/// Runs the library swipe action the user configured for the left/right swipe.
///
/// [actionIndex] indexes into [kLibrarySwipeActions]. [context] is only needed
/// by actions that surface UI (the delete confirmation).
Future<void> runLibrarySwipeAction(
  WidgetRef ref,
  Manga manga,
  int actionIndex, {
  BuildContext? context,
}) async {
  if (actionIndex < 0 || actionIndex >= kLibrarySwipeActions.length) return;

  switch (actionIndex) {
    case 0: // Marquer le chapitre — first unread chapter only
      await _markChapters(ref, manga, onlyFirstUnread: true);
    case 1: // Marquer comme lu — every chapter
      await _markChapters(ref, manga);
    case 2: // Aucun(e)
      return;
    case 3: // Ajouter à la bibliothèque
      await _addToLibrary(manga);
    case 4: // Télécharger — first unread chapter
      await _downloadFirstUnread(ref, manga);
    case 5: // Partager
      await _share(manga);
    case 6: // Copier le lien
      await _copyLink(manga, context);
    case 7: // Retirer de la bibliothèque
      await _removeFromLibrary(manga);
    case 8: // Marquer comme non lu
      await _markUnread(ref, manga);
    case 9: // Supprimer (bibliothèque / stockage)
      if (context != null) {
        await showSwipeDeleteDialog(context: context, ref: ref, manga: manga);
      }
  }
}

/// Chapters of [manga], read through the denormalized `mangaId` index.
///
/// The lazy `manga.chapters` backlink runs a full synchronous chapter load on
/// the UI isolate, which is felt as a freeze on the swipe action.
List<Chapter> _chaptersOf(Manga manga) {
  final id = manga.id;
  if (id == null) return const [];
  return isar.chapters.where().mangaIdEqualTo(id).findAllSync();
}

Future<void> _downloadFirstUnread(WidgetRef ref, Manga manga) async {
  final chapters = _chaptersOf(manga);
  if (chapters.isEmpty) return;
  final target = chapters.firstWhere(
    (c) => !(c.isRead ?? false),
    orElse: () => chapters.first,
  );
  await ref.read(addDownloadToQueueProvider(chapter: target).future);
}

/// Marks chapters as read and persists both chapters and the parent manga.
Future<void> _markChapters(
  WidgetRef ref,
  Manga manga, {
  bool onlyFirstUnread = false,
}) async {
  final chapters = _chaptersOf(manga);
  if (chapters.isEmpty) return;

  final targets = onlyFirstUnread
      ? chapters.where((c) => !(c.isRead ?? false)).take(1).toList()
      : chapters;
  if (targets.isEmpty) return;

  final now = DateTime.now().millisecondsSinceEpoch;
  for (final chapter in targets) {
    chapter.isRead = true;
    chapter.lastPageRead = '1';
    chapter.updatedAt = now;
    chapter.manga.value = manga;
    chapter.updateTrackChapterRead(ref);
  }
  manga.lastRead = now;
  manga.updatedAt = now;

  isar.writeTxnSync(() {
    isar.chapters.putAllSync(targets);
    isar.mangas.putSync(manga);
  });
}

Future<void> _addToLibrary(Manga manga) async {
  if (manga.favorite == true) return;
  manga.favorite = true;
  manga.dateAdded = DateTime.now().millisecondsSinceEpoch;
  manga.updatedAt = manga.dateAdded;
  isar.writeTxnSync(() => isar.mangas.putSync(manga));
}

/// Removes the series from the library without touching its files.
Future<void> _removeFromLibrary(Manga manga) async {
  if (manga.favorite != true) return;
  manga.favorite = false;
  manga.updatedAt = DateTime.now().millisecondsSinceEpoch;
  isar.writeTxnSync(() => isar.mangas.putSync(manga));
}

/// Clears the read state of every chapter and the continue-reading pointer.
Future<void> _markUnread(WidgetRef ref, Manga manga) async {
  final chapters = _chaptersOf(manga);
  if (chapters.isEmpty) return;

  final now = DateTime.now().millisecondsSinceEpoch;
  for (final chapter in chapters) {
    chapter
      ..isRead = false
      ..lastPageRead = '0'
      ..updatedAt = now
      ..manga.value = manga;
  }
  manga
    ..lastRead = null
    ..updatedAt = now;

  isar.writeTxnSync(() {
    isar.chapters.putAllSync(chapters);
    isar.mangas.putSync(manga);
  });
}

Future<void> _share(Manga manga) async {
  final name = manga.name ?? '';
  final link = manga.link ?? '';
  final text = link.isEmpty ? name : '$name\n$link';
  if (text.trim().isEmpty) return;
  await SharePlus.instance.share(ShareParams(text: text));
}

Future<void> _copyLink(Manga manga, BuildContext? context) async {
  final link = manga.link ?? '';
  if (link.trim().isEmpty) return;
  await Clipboard.setData(ClipboardData(text: link));
  if (context != null && context.mounted) {
    botToast(l10nLocalizations(context)!.copied_to_clipboard);
  }
}

/// Confirmation dialog used by the "Supprimer" swipe action. Two independent
/// checkboxes let the user remove the series from the library, wipe the
/// downloaded files, or both.
Future<void> showSwipeDeleteDialog({
  required BuildContext context,
  required WidgetRef ref,
  required Manga manga,
}) async {
  final l10n = l10nLocalizations(context)!;
  var fromLibrary = manga.favorite == true;
  // Pre-tick "storage" when the series only lives on disk: leaving both boxes
  // empty made the confirm button do nothing, which read as a broken action.
  var fromStorage = !fromLibrary;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(l10n.remove),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  value: fromLibrary,
                  onChanged: (v) => setState(() => fromLibrary = v ?? false),
                  title: Text(l10n.from_library),
                  subtitle: Text(
                    l10n.library_delete_library_hint,
                    style: const TextStyle(fontSize: 11),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                ),
                CheckboxListTile(
                  value: fromStorage,
                  onChanged: (v) => setState(() => fromStorage = v ?? false),
                  title: Text(l10n.storage),
                  subtitle: Text(
                    l10n.library_delete_storage_hint,
                    style: const TextStyle(fontSize: 11),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              TextButton(
                // Nothing ticked means nothing to delete: keep the button
                // inert instead of closing on a no-op.
                onPressed: (fromLibrary || fromStorage)
                    ? () => Navigator.pop(context, true)
                    : null,
                child: Text(l10n.ok),
              ),
            ],
          );
        },
      );
    },
  );

  if (confirmed != true) return;

  // Read the chapters once: both branches below need them, and the old code
  // re-ran the index query for the storage pass alone.
  final chapters = _chaptersOf(manga);

  if (fromStorage) {
    for (final chapter in chapters) {
      final id = chapter.id;
      if (id != null && isar.downloads.getSync(id) != null) {
        await chapter.deleteDownloadedFiles();
      }
    }
  }

  if (fromLibrary) {
    manga.favorite = false;
    manga.updatedAt = DateTime.now().millisecondsSinceEpoch;
    isar.writeTxnSync(() => isar.mangas.putSync(manga));
  }
}
