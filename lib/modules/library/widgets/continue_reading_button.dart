import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/library/providers/isar_providers.dart';
import 'package:watchtower/modules/more/providers/incognito_mode_state_provider.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';
import 'package:watchtower/utils/extensions/chapter.dart';

/// The round "continue reading" play button drawn on a library card.
///
/// It reads the single shared [libraryHistoryByMangaProvider] instead of
/// opening its own Isar query watcher per card, and it resolves the linked
/// chapter lazily on tap — reading `history.chapter.value` while building would
/// issue one synchronous Isar read per visible card.
class ContinueReadingButton extends ConsumerWidget {
  const ContinueReadingButton({super.key, required this.entry});

  final Manga entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(libraryHistoryByMangaProvider).value?[entry.id];
    final incognitoMode = ref.watch(incognitoModeStateProvider);

    return GestureDetector(
      onTap: () {
        if (history != null && !incognitoMode) {
          final chapter = history.chapter.value;
          if (chapter != null) {
            chapter.pushToReaderView(context);
            return;
          }
        }
        final chapters = entry.chapters.toList();
        if (chapters.isNotEmpty) {
          chapters.reversed.toList().last.pushToReaderView(context);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          color: context.primaryColor.withValues(alpha: 0.9),
        ),
        child: const Padding(
          padding: EdgeInsets.all(7),
          child: Icon(Icons.play_arrow, size: 19, color: Colors.white),
        ),
      ),
    );
  }
}
