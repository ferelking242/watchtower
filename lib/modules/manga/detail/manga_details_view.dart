import 'package:flutter/material.dart' hide Category;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/category.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/history.dart';
import 'package:watchtower/modules/manga/detail/widgets/custom_floating_action_btn.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/widgets/category_selection_dialog.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';
import 'package:watchtower/utils/constant.dart';
import 'package:watchtower/utils/utils.dart';
import 'package:watchtower/modules/manga/detail/manga_detail_view.dart';
import 'package:watchtower/modules/manga/detail/widgets/detail_shimmer.dart';
import 'package:watchtower/modules/plugin/nfile/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/manga/detail/providers/state_providers.dart';
import 'package:watchtower/modules/more/providers/incognito_mode_state_provider.dart';
import 'package:watchtower/utils/adaptive_overlay_menu.dart';
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

  /// Author and designer (artist) as tappable chips. A tap opens the shared
  /// glass box — the same component as the download and three-dots menus —
  /// anchored to the tapped name, offering copy, in-extension search and
  /// global search.
  Widget _buildAuthorLine(AppLocalizations l10n) {
    final author = widget.manga.author?.trim();
    final artist = widget.manga.artist?.trim();
    final hasAuthor = author?.isNotEmpty ?? false;
    final hasArtist = artist?.isNotEmpty ?? false;

    if (!hasAuthor && !hasArtist) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Broken.user, size: 15),
          const SizedBox(width: 5),
          Text(
            l10n.unknown,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      );
    }

    // (name, isDesigner): the author leads, the designer follows when it
    // differs. When the extension publishes only one of the two, that one
    // still carries its own icon.
    final people = <(String, bool)>[
      if (hasAuthor) (author!, false),
      if (hasArtist && artist != author) (artist!, true),
    ];

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < people.length; i++) ...[
          if (i > 0)
            Text(
              ' • ',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: context.secondaryColor,
              ),
            ),
          _personChip(people[i].$1, people[i].$2),
        ],
      ],
    );
  }

  Widget _personChip(String name, bool isDesigner) {
    final l10n = l10nLocalizations(context)!;
    return AdaptiveOverlayMenuButton(
      menuWidth: 264,
      trigger: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDesigner ? Broken.brush : Broken.user,
            size: 15,
            color: context.secondaryColor,
          ),
          const SizedBox(width: 5),
          Text(
            name,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: context.primaryColor,
            ),
          ),
        ],
      ),
      contentBuilder: (close) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdaptiveOverlaySection(
            title: isDesigner ? l10n.designer : l10n.author_works,
          ),
          AdaptiveOverlayItem(
            icon: Broken.copy,
            label: l10n.copy,
            onTap: () {
              close();
              _copyName(name);
            },
          ),
          AdaptiveOverlayItem(
            icon: Broken.search_normal,
            label: l10n.search_in_extension,
            onTap: () {
              close();
              _openAuthorWorks(name);
            },
          ),
          AdaptiveOverlayItem(
            icon: Broken.global,
            label: l10n.global_search,
            onTap: () {
              close();
              _globalSearchName(name);
            },
          ),
        ],
      ),
    );
  }

  void _copyName(String name) {
    Clipboard.setData(ClipboardData(text: name));
    botToast(l10nLocalizations(context)!.copied_to_clipboard);
  }

  void _globalSearchName(String name) {
    context.push('/globalSearch', extra: (name, widget.manga.itemType));
  }

  /// Compact genre chips published by the extension (`MManga.genre`). Each
  /// chip opens the global search pre-filled with that genre so the user can
  /// browse every source for it.
  Widget _buildGenreRow() {
    final genres = (widget.manga.genre ?? const <String>[])
        .map((g) => g.trim())
        .where((g) => g.isNotEmpty)
        .toSet()
        .toList();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final genre in genres)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push(
              '/globalSearch',
              extra: (genre, widget.manga.itemType),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: context.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: context.primaryColor.withValues(alpha: 0.22),
                  width: 0.8,
                ),
              ),
              child: Text(
                genre,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Adds the manga to the library in the default category ("all"), bypassing
  /// the category picker. Used by the long press on the heart button.
  void _addToLibraryDefault() {
    final model = widget.manga;
    if (model.favorite == true) return;
    isar.writeTxnSync(() {
      model.favorite = true;
      model.dateAdded = DateTime.now().millisecondsSinceEpoch;
      model.updatedAt = DateTime.now().millisecondsSinceEpoch;
      model.categories = [];
      isar.mangas.putSync(model);
    });
    botToast(l10nLocalizations(context)!.added_to_library);
  }

  void _openAuthorWorks(String name) {
    final source = getSource(
      widget.manga.lang!,
      widget.manga.source!,
      widget.manga.sourceId,
    );
    if (source == null) {
      botToast(l10nLocalizations(context)!.source_not_added);
      return;
    }
    context.push('/extensionPersonSearch', extra: (source, name));
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
          // Fallback for the FAB when the history stream has no entry: start at
          // the first chapter of the series. Reuse the chapters already
          // filtered/sorted by the page instead of walking the lazy
          // `manga.chapters` backlink, which loaded every chapter synchronously
          // on the UI isolate (the freeze felt on tap).
          Chapter? firstChapter() {
            Chapter? oldest;
            for (final chapter in chaptersList) {
              final id = chapter.id;
              if (id == null) continue;
              if (oldest == null || id < oldest.id!) oldest = chapter;
            }
            return oldest;
          }
          return ref.watch(isLongPressedStateProvider)
              ? Container()
              : chaptersList.isNotEmpty &&
                    chaptersList
                        .where((element) => !element.isRead!)
                        .toList()
                        .isNotEmpty
              ? StreamBuilder(
                  // Scoped to this manga by the indexed `mangaId` field. The
                  // previous query walked the whole `historys` collection and
                  // traversed the `chapter → manga` link, then filtered in Dart:
                  // a full deserialization of every history row (and their
                  // links) on each write, on the UI isolate.
                  stream: isar.historys
                      .where()
                      .mangaIdEqualTo(widget.manga.id!)
                      .watch(fireImmediately: true),
                  builder: (context, snapshot) {
                    String buttonLabel = widget.manga.itemType != ItemType.anime
                        ? l10n.read
                        : l10n.watch;
                    if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                      final incognitoMode = ref.watch(
                        incognitoModeStateProvider,
                      );
                      // `chapter` is an IsarLink: reading `.value` here loads it
                      // synchronously. Resolve the single newest entry with one
                      // index-backed read instead.
                      final entry = snapshot.data!.last;
                      final chap = entry.chapterId == null
                          ? null
                          : isar.chapters.getSync(entry.chapterId!);

                      if (chap != null && !incognitoMode) {
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
                          firstChapter()?.pushToReaderView(context);
                        },
                      );
                    }
                    return CustomFloatingActionBtn(
                      isExtended: !isExtended,
                      label: buttonLabel,
                      onPressed: () {
                        firstChapter()?.pushToReaderView(context);
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
                if (widget.isLoading) ...[
                  const Icon(Broken.user, size: 15),
                  const SizedBox(width: 5),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: DetailShimmerBox(width: 96, height: 12, radius: 4),
                  ),
                ] else
                  _buildAuthorLine(l10n),
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
            if (!widget.isLoading &&
                (widget.manga.genre?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 6),
              _buildGenreRow(),
            ],
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
            : GestureDetector(
                // Long press: add straight to the library in the default
                // category, without opening the category picker.
                onLongPress: _addToLibraryDefault,
                child: ElevatedButton(
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
                      _addToLibraryDefault();
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
