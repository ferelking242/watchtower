import 'package:flutter/material.dart' hide Category;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/history.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/manga/detail/manga_detail_view.dart';
import 'package:watchtower/modules/manga/detail/providers/state_providers.dart';
import 'package:watchtower/modules/manga/detail/widgets/custom_floating_action_btn.dart';
import 'package:watchtower/modules/more/providers/incognito_mode_state_provider.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/utils/extensions/chapter.dart';

/// Wrapper around [MangaDetailView] that owns the "read / resume" floating
/// action button. The hero, actions and sections all live in
/// [MangaDetailView] itself.
class MangaDetailsView extends ConsumerStatefulWidget {
  final Manga manga;
  final bool sourceExist;
  final Function(bool) checkForUpdate;
  const MangaDetailsView({
    super.key,
    required this.sourceExist,
    required this.manga,
    required this.checkForUpdate,
  });

  @override
  ConsumerState<MangaDetailsView> createState() => _MangaDetailsViewState();
}

class _MangaDetailsViewState extends ConsumerState<MangaDetailsView> {
  @override
  Widget build(BuildContext context) {
    final l10n = l10nLocalizations(context)!;
    return Scaffold(
      floatingActionButton: Consumer(
        builder: (context, ref, child) {
          final chaptersList = ref.watch(chaptersListttStateProvider);
          final isExtended = ref.watch(isExtendedStateProvider);
          if (ref.watch(isLongPressedStateProvider)) {
            return const SizedBox.shrink();
          }
          final hasUnread = chaptersList.any((e) => !(e.isRead ?? false));
          if (chaptersList.isEmpty || !hasUnread) {
            return const SizedBox.shrink();
          }
          final readLabel = widget.manga.itemType != ItemType.anime
              ? l10n.read
              : l10n.watch;
          return StreamBuilder(
            stream: isar.historys
                .filter()
                .chapter(
                  (q) =>
                      q.manga((q) => q.itemTypeEqualTo(widget.manga.itemType)),
                )
                .watch(fireImmediately: true),
            builder: (context, snapshot) {
              final incognitoMode = ref.watch(incognitoModeStateProvider);
              if (snapshot.hasData &&
                  snapshot.data!.isNotEmpty &&
                  !incognitoMode) {
                final entries = snapshot.data!
                    .where((element) => element.mangaId == widget.manga.id)
                    .toList()
                    .reversed
                    .toList();
                if (entries.isNotEmpty) {
                  final chap = entries.first.chapter.value!;
                  return CustomFloatingActionBtn(
                    isExtended: !isExtended,
                    label: l10n.resume,
                    onPressed: () => chap.pushToReaderView(context),
                  );
                }
              }
              return CustomFloatingActionBtn(
                isExtended: !isExtended,
                label: readLabel,
                onPressed: () => widget.manga.chapters
                    .toList()
                    .reversed
                    .toList()
                    .last
                    .pushToReaderView(context),
              );
            },
          );
        },
      ),
      body: MangaDetailView(
        manga: widget.manga,
        isExtended: (value) {
          ref.read(isExtendedStateProvider.notifier).update(value);
        },
        sourceExist: widget.sourceExist,
        checkForUpdate: widget.checkForUpdate,
        itemType: widget.manga.itemType,
      ),
    );
  }
}
