import 'package:flutter/material.dart' hide Category;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/category.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/history.dart';
import 'package:watchtower/modules/manga/detail/widgets/custom_floating_action_btn.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/widgets/category_selection_dialog.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';
import 'package:watchtower/utils/constant.dart';
import 'package:watchtower/modules/manga/detail/manga_detail_view.dart';
import 'package:watchtower/modules/manga/detail/widgets/detail_shimmer.dart';
import 'package:watchtower/modules/plugin/nfile/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/manga/detail/providers/state_providers.dart';
import 'package:watchtower/modules/more/providers/incognito_mode_state_provider.dart';
import 'package:watchtower/utils/extensions/chapter.dart';

// ─────────────────────────────────────────────────────────────────────────────

String _langFlag(String lang) {
  const map = {
    'ja': '🇯🇵', 'jp': '🇯🇵',
    'ko': '🇰🇷', 'kr': '🇰🇷',
    'zh': '🇨🇳', 'cn': '🇨🇳',
    'zh-hant': '🇹🇼', 'tw': '🇹🇼',
    'en': '🇬🇧', 'fr': '🇫🇷',
    'es': '🇪🇸', 'pt': '🇧🇷',
    'pt-br': '🇧🇷', 'de': '🇩🇪',
    'it': '🇮🇹', 'ru': '🇷🇺',
    'ar': '🇸🇦', 'vi': '🇻🇳',
    'th': '🇹🇭', 'id': '🇮🇩',
  };
  return map[lang.toLowerCase()] ?? '';
}

class MangaDetailsView extends ConsumerStatefulWidget {
  final Manga manga;
  final bool sourceExist;
  final Function(bool) checkForUpdate;

  /// Vrai pendant le chargement des informations de la source : le titre,
  /// l'auteur et le statut passent en shimmer (leurs icônes restent affichées).
  final bool isLoading;

  const MangaDetailsView({
    super.key,
    required this.sourceExist,
    required this.manga,
    required this.checkForUpdate,
    this.isLoading = false,
  });

  @override
  ConsumerState<MangaDetailsView> createState() => _MangaDetailsViewState();
}

class _MangaDetailsViewState extends ConsumerState<MangaDetailsView> {
  Size measureText(String text, TextStyle style) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    return textPainter.size;
  }

  double calculateDynamicButtonWidth(
    String text,
    TextStyle textStyle,
    double padding,
  ) {
    final textSize = measureText(text, textStyle);
    return textSize.width + padding;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = l10nLocalizations(context)!;
    bool? isLocalArchive = widget.manga.isLocalArchive ?? false;
    return Scaffold(
      floatingActionButton: Consumer(
        builder: (context, ref, child) {
          final chaptersList = ref.watch(chaptersListttStateProvider);
          final isExtended = ref.watch(isExtendedStateProvider);
          return ref.watch(isLongPressedStateProvider)
              ? Container()
              : chaptersList.isNotEmpty &&
                    chaptersList
                        .where((element) => !element.isRead!)
                        .toList()
                        .isNotEmpty
              ? StreamBuilder(
                  stream: isar.historys
                      .filter()
                      .chapter(
                        (q) => q.manga(
                          (q) => q.itemTypeEqualTo(widget.manga.itemType),
                        ),
                      )
                      .watch(fireImmediately: true),
                  builder: (context, snapshot) {
                    String buttonLabel = widget.manga.itemType != ItemType.anime
                        ? l10n.read
                        : l10n.watch;
                    if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                      final incognitoMode = ref.watch(
                        incognitoModeStateProvider,
                      );
                      final entries = snapshot.data!
                          .where(
                            (element) => element.mangaId == widget.manga.id,
                          )
                          .toList()
                          .reversed
                          .toList();

                      if (entries.isNotEmpty && !incognitoMode) {
                        final chap = entries.first.chapter.value!;
                        return CustomFloatingActionBtn(
                          isExtended: !isExtended,
                          label: l10n.resume,
                          onPressed: () {
                            chap.pushToReaderView(context);
                          },
                        );
                      }
                      return CustomFloatingActionBtn(
                        isExtended: !isExtended,
                        label: buttonLabel,
                        onPressed: () {
                          widget.manga.chapters
                              .toList()
                              .reversed
                              .toList()
                              .last
                              .pushToReaderView(context);
                        },
                      );
                    }
                    return CustomFloatingActionBtn(
                      isExtended: !isExtended,
                      label: buttonLabel,
                      onPressed: () {
                        widget.manga.chapters
                            .toList()
                            .reversed
                            .toList()
                            .last
                            .pushToReaderView(context);
                      },
                    );
                  },
                )
              : Container();
        },
      ),
      body: MangaDetailView(
        isLoading: widget.isLoading,
        titleDescription: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(Broken.user, size: 15),
                const SizedBox(width: 5),
                if (widget.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: DetailShimmerBox(width: 96, height: 12, radius: 4),
                  )
                else
                  Text(
                    (widget.manga.author?.isEmpty ?? false)
                        ? l10n.unknown
                        : widget.manga.author!,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(getMangaStatusIcon(widget.manga.status), size: 14),
                const SizedBox(width: 4),
                if (widget.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: DetailShimmerBox(width: 132, height: 12, radius: 4),
                  )
                else ...[
                  Text(getMangaStatusName(widget.manga.status, context)),
                  if (!isLocalArchive) const Text(' • '),
                  if (!isLocalArchive) Text(widget.manga.source!),
                  if (!isLocalArchive && widget.manga.lang != null) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: context.primaryColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: context.primaryColor.withValues(alpha: 0.30),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_langFlag(widget.manga.lang!).isNotEmpty) ...[
                            Text(
                              _langFlag(widget.manga.lang!),
                              style: const TextStyle(fontSize: 11),
                            ),
                            const SizedBox(width: 3),
                          ],
                          Text(
                            widget.manga.lang!.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: context.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (!isLocalArchive && !widget.sourceExist)
                    const Padding(
                      padding: EdgeInsets.all(3),
                      child: Icon(
                        Broken.warning_2,
                        color: Colors.deepOrangeAccent,
                        size: 14,
                      ),
                    ),
                ],
              ],
            ),
          ],
        ),
        action: widget.manga.favorite!
            ? SizedBox(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    elevation: 0,
                  ),
                  onPressed: () {
                    final model = widget.manga;
                    isar.writeTxnSync(() {
                      model.favorite = false;
                      model.dateAdded = 0;
                      model.updatedAt = DateTime.now().millisecondsSinceEpoch;
                      isar.mangas.putSync(model);
                    });
                  },
                  // Squelette pendant le chargement : mêmes icône (20) et
                  // libellé (11) que le bouton réel, dans le même ElevatedButton.
                  child: widget.isLoading
                      ? const DetailActionButtonSkeleton(labelWidth: 46)
                      : Column(
                          children: [
                            const Icon(Broken.heart_filled, size: 20),
                            const SizedBox(height: 4),
                            Text(
                              l10n.in_library,
                              style: const TextStyle(fontSize: 11),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                ),
              )
            : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  elevation: 0,
                ),
                onPressed: () {
                  final model = widget.manga;
                  final checkCategoryList = isar.categorys
                      .filter()
                      .forItemTypeEqualTo(model.itemType)
                      .isNotEmptySync();
                  if (checkCategoryList) {
                    showCategorySelectionDialog(
                      context: context,
                      ref: ref,
                      itemType: model.itemType,
                      singleManga: model,
                    );
                  } else {
                    isar.writeTxnSync(() {
                      model.favorite = true;
                      model.dateAdded = DateTime.now().millisecondsSinceEpoch;
                      model.updatedAt = DateTime.now().millisecondsSinceEpoch;
                      isar.mangas.putSync(model);
                    });
                  }
                },
                child: widget.isLoading
                    ? const DetailActionButtonSkeleton(labelWidth: 70)
                    : Column(
                        children: [
                          Icon(
                            Broken.heart,
                            size: 20,
                            color: context.secondaryColor,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.add_to_library,
                            style: TextStyle(
                              color: context.secondaryColor,
                              fontSize: 11,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
              ),
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
