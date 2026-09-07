import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/modules/library/library_screen.dart';
import 'package:watchtower/modules/library/providers/isar_providers.dart';
import 'package:watchtower/modules/library/providers/library_state_provider.dart';
import 'package:watchtower/modules/library/widgets/library_dialogs.dart';
import 'package:watchtower/modules/library/widgets/library_filter_sort_menu.dart';
import 'package:watchtower/modules/library/widgets/library_settings_sheet.dart';
import 'package:watchtower/modules/library/widgets/search_text_form_field.dart';
import 'package:watchtower/modules/manga/detail/providers/state_providers.dart';
import 'package:watchtower/modules/widgets/error_text.dart';
import 'package:watchtower/modules/widgets/progress_center.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/services/library_updater.dart';
import 'package:watchtower/utils/adaptive_overlay_menu.dart';
import 'package:watchtower/utils/arrow_popup_menu.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';
import 'package:watchtower/utils/global_style.dart';
import 'package:watchtower/utils/item_type_localization.dart';
import 'package:watchtower/modules/widgets/manga_image_card_widget.dart';

/// AppBar for the standalone library screen.
///
/// Actions order (per design spec): Search → Notifications → Three-dots menu
/// Filter is accessible:
///   • Inside the search field when search mode is active (filter overlay).
///   • Via the three-dots menu ("Filters & Sort") when search is inactive.
///
/// All icons use the Broken icon set — no Material icons in the action area.
class LibraryAppBar extends ConsumerStatefulWidget implements PreferredSizeWidget {
  final ItemType itemType;
  final bool isNotFiltering;
  final bool showNumbersOfItems;
  final int numberOfItems;
  final List<Manga> entries;
  final bool isCategory;
  final int? categoryId;
  final Settings settings;
  final bool isSearch;
  final bool ignoreFiltersOnSearch;
  final TextEditingController textEditingController;
  final VoidCallback onSearchToggle;
  final VoidCallback onSearchClear;
  final ValueChanged<bool> onIgnoreFiltersChanged;
  final TickerProvider vsync;

  const LibraryAppBar({
    super.key,
    required this.itemType,
    required this.isNotFiltering,
    required this.showNumbersOfItems,
    required this.numberOfItems,
    required this.entries,
    required this.isCategory,
    required this.categoryId,
    required this.settings,
    required this.isSearch,
    required this.ignoreFiltersOnSearch,
    required this.textEditingController,
    required this.onSearchToggle,
    required this.onSearchClear,
    required this.onIgnoreFiltersChanged,
    required this.vsync,
  });

  @override
  Size get preferredSize => Size.fromHeight(AppBar().preferredSize.height);

  @override
  ConsumerState<LibraryAppBar> createState() => _LibraryAppBarState();
}

class _LibraryAppBarState extends ConsumerState<LibraryAppBar> {
  // ── Filter overlay shown via search-field filter icon ──────────────────────
  Widget _buildFilterOverlayContent(VoidCallback close) {
    return LibraryFilterSortMenu(
      itemType: widget.itemType,
      settings: widget.settings,
      entries: widget.entries,
      close: close,
      onSelect: () {
        ref.read(isLongPressedStateProvider.notifier).update(true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLongPressed = ref.watch(isLongPressedStateProvider);
    final mangaIdsList = ref.watch(mangasListStateProvider);
    final manga = widget.categoryId == null
        ? ref.watch(
            getAllMangaWithoutCategoriesStreamProvider(
                itemType: widget.itemType),
          )
        : ref.watch(
            getAllMangaStreamProvider(
              categoryId: widget.categoryId,
              itemType: widget.itemType,
            ),
          );
    final l10n = l10nLocalizations(context)!;
    final isMobile = !kIsWeb && (Platform.isIOS || Platform.isAndroid);

    if (isLongPressed) {
      return manga.when(
        data: (data) => _SelectionAppBar(
          itemType: widget.itemType,
          mangaIdsList: mangaIdsList,
          data: data,
        ),
        error: (error, _) => ErrorText(error),
        loading: () => const ProgressCenter(),
      );
    }

    // ── Filter button embedded in the search field ─────────────────────────
    final filterBtn = AdaptiveOverlayMenuButton(
      menuWidth: 250,
      trigger: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Icon(
          Broken.slider_horizontal,
          size: 18,
          color: widget.isNotFiltering
              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45)
              : Theme.of(context).colorScheme.primary,
        ),
      ),
      contentBuilder: _buildFilterOverlayContent,
    );

    return AppBar(
      elevation: 0,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      title: widget.isSearch
          ? null
          : Row(
              children: [
                Text(
                  widget.itemType.localized(l10n),
                  style:
                      TextStyle(color: Theme.of(context).hintColor),
                ),
                const SizedBox(width: 10),
                if (widget.showNumbersOfItems)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Badge(
                      backgroundColor: Theme.of(context).focusColor,
                      label: Text(
                        widget.numberOfItems.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              Theme.of(context).textTheme.bodySmall!.color,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
      actions: [
        // ── 1. Search ──────────────────────────────────────────────────────
        if (widget.isSearch)
          SeachFormTextField(
            onChanged: (_) => widget.onSearchClear(),
            onPressed: widget.onSearchToggle,
            controller: widget.textEditingController,
            onSuffixPressed: () {
              widget.textEditingController.clear();
              widget.onSearchClear();
            },
            filterButton: filterBtn,
          )
        else
          IconButton(
            splashRadius: 20,
            onPressed: () {
              widget.textEditingController.clear();
              widget.onSearchToggle();
            },
            icon: const Icon(Broken.search_normal_1),
          ),

        // Ignore-filters checkbox (only when searching, mobile)
        if (widget.isSearch)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isMobile
                    ? l10n.ignore_filters.replaceFirst(' ', '\n')
                    : l10n.ignore_filters.replaceAll('\n', ''),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11),
              ),
              Checkbox(
                value: widget.ignoreFiltersOnSearch,
                onChanged: (val) {
                  widget.onIgnoreFiltersChanged(val ?? false);
                },
              ),
            ],
          ),

        // ── 2. Notifications ───────────────────────────────────────────────
        IconButton(
          splashRadius: 20,
          onPressed: () => context.push('/updates'),
          icon: const Icon(Broken.notification),
          tooltip: l10n.updates,
        ),

        // ── 3. Three-dots popup ────────────────────────────────────────────
        ArrowPopupMenuButton<int>(
          popUpAnimationStyle: popupAnimationStyle,
          icon: const Icon(Broken.more_2),
          itemBuilder: (context) {
            return [
              PopupMenuItem<int>(
                value: 0,
                child: Row(children: [
                  const Icon(Broken.refresh_left_square, size: 18),
                  const SizedBox(width: 10),
                  Text(context.l10n.update_library),
                ]),
              ),
              PopupMenuItem<int>(
                value: 1,
                child: Row(children: [
                  const Icon(Broken.programming_arrows, size: 18),
                  const SizedBox(width: 10),
                  Text(l10n.open_random_entry),
                ]),
              ),
              PopupMenuItem<int>(
                value: 2,
                child: Row(children: [
                  const Icon(Broken.arrow_square, size: 18),
                  const SizedBox(width: 10),
                  Text(l10n.import),
                ]),
              ),
              PopupMenuItem<int>(
                value: 4,
                child: Row(children: [
                  const Icon(Broken.slider_horizontal, size: 18),
                  const SizedBox(width: 10),
                  Text(l10n.filter),
                ]),
              ),
              if (widget.itemType == ItemType.anime)
                PopupMenuItem<int>(
                  value: 3,
                  child: Row(children: [
                    const Icon(Broken.video_play, size: 18),
                    const SizedBox(width: 10),
                    Text(l10n.torrent_stream),
                  ]),
                ),
            ];
          },
          onSelected: (value) {
            if (value == 0) {
              manga.whenData((value) {
                updateLibrary(
                  ref: ref,
                  context: context,
                  mangaList: value,
                  itemType: widget.itemType,
                );
              });
            } else if (value == 1) {
              manga.whenData((value) {
                var randomManga = (value..shuffle()).first;
                pushToMangaReaderDetail(
                  ref: ref,
                  archiveId: randomManga.isLocalArchive ?? false
                      ? randomManga.id
                      : null,
                  context: context,
                  lang: randomManga.lang!,
                  mangaM: randomManga,
                  source: randomManga.source!,
                  sourceId: randomManga.sourceId,
                );
              });
            } else if (value == 2) {
              showImportLocalDialog(context, widget.itemType);
            } else if (value == 3 && widget.itemType == ItemType.anime) {
              addTorrent(context);
            } else if (value == 4) {
              showLibrarySettingsSheet(
                context: context,
                vsync: widget.vsync,
                settings: widget.settings,
                itemType: widget.itemType,
                entries: widget.entries,
              );
            }
          },
        ),
      ],
    );
  }
}

/// AppBar shown when items are long-pressed for bulk selection.
class _SelectionAppBar extends ConsumerWidget {
  final ItemType itemType;
  final List<int> mangaIdsList;
  final List<Manga> data;

  const _SelectionAppBar({
    required this.itemType,
    required this.mangaIdsList,
    required this.data,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLongPressed = ref.watch(isLongPressedStateProvider);
    return AppBar(
      title: Text(mangaIdsList.length.toString()),
      backgroundColor: context.primaryColor.withValues(alpha: 0.2),
      leading: IconButton(
        onPressed: () {
          ref.read(mangasListStateProvider.notifier).clear();
          ref
              .read(isLongPressedStateProvider.notifier)
              .update(!isLongPressed);
        },
        icon: const Icon(Broken.close_circle),
      ),
      actions: [
        IconButton(
          onPressed: () {
            for (var manga in data) {
              ref.read(mangasListStateProvider.notifier).selectAll(manga);
            }
          },
          icon: const Icon(Broken.tick_square),
        ),
        IconButton(
          onPressed: () {
            if (data.length == mangaIdsList.length) {
              for (var manga in data) {
                ref
                    .read(mangasListStateProvider.notifier)
                    .selectSome(manga);
              }
              ref
                  .read(isLongPressedStateProvider.notifier)
                  .update(false);
            } else {
              for (var manga in data) {
                ref
                    .read(mangasListStateProvider.notifier)
                    .selectSome(manga);
              }
            }
          },
          icon: const Icon(Broken.back_square),
        ),
      ],
    );
  }
}
