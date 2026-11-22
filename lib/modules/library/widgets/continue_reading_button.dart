import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/library/providers/isar_providers.dart';
import 'package:watchtower/modules/more/providers/incognito_mode_state_provider.dart';
import 'package:watchtower/modules/more/settings/library/providers/library_settings_provider.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';
import 'package:watchtower/utils/extensions/chapter.dart';

/// The "continue reading" control drawn on a library card.
///
/// It reads the single shared [libraryHistoryByMangaProvider] instead of
/// opening its own Isar query watcher per card, and it resolves the linked
/// chapter lazily on tap — reading `history.chapter.value` while building would
/// issue one synchronous Isar read per visible card.
///
/// When [libraryShowProviderBadgeProvider] is on the pill also carries the
/// source (extension) that provides the entry, the same watermark the download
/// manager paints on its covers.
class ContinueReadingButton extends ConsumerWidget {
  const ContinueReadingButton({super.key, required this.entry});

  final Manga entry;

  void _open(BuildContext context, WidgetRef ref) {
    final history = ref.read(libraryHistoryByMangaProvider).value?[entry.id];
    final incognitoMode = ref.read(incognitoModeStateProvider);
    if (history != null && !incognitoMode) {
      final chapter = history.chapter.value;
      if (chapter != null) {
        chapter.pushToReaderView(context);
        return;
      }
    }
    // Index-backed read instead of the lazy `entry.chapters` backlink,
    // which ran a full synchronous chapter load on the UI isolate on tap.
    final chapters = entry.id == null
        ? <Chapter>[]
        : isar.chapters.where().mangaIdEqualTo(entry.id!).findAllSync();
    if (chapters.isNotEmpty) {
      chapters.reversed.toList().last.pushToReaderView(context);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showProvider = ref.watch(libraryShowProviderBadgeProvider);
    var provider = (entry.source ?? '')
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .toUpperCase();
    if (provider.length > 8) provider = provider.substring(0, 8);
    final showBadge = showProvider && provider.isNotEmpty;

    return GestureDetector(
      onTap: () => _open(context, ref),
      child: Container(
        margin: const EdgeInsets.all(6),
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: context.primaryColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 8,
              offset: const Offset(0, 2),
              spreadRadius: -2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 9),
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              if (showBadge)
                Container(
                  height: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0x4D000000), Color(0x66000000)],
                    ),
                  ),
                  child: Text(
                    provider,
                    style: const TextStyle(
                      color: Color(0xF2FFFFFF),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
