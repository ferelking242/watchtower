import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
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
import 'package:watchtower/utils/extensions/build_context_extensions.dart';
import 'package:watchtower/utils/item_type_localization.dart';
import 'package:watchtower/modules/widgets/manga_image_card_widget.dart';

/// AppBar for the standalone library screen.
///
/// The action carousel keeps three commands visible at once and exposes the
/// remaining actions through horizontal swipes. The search-field filter overlay
/// remains available while searching.
class LibraryAppBar extends ConsumerStatefulWidget
    implements PreferredSizeWidget {
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
  Size get preferredSize =>
      Size.fromHeight(AppBar().preferredSize.height + 1);

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
              itemType: widget.itemType,
            ),
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
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(
          height: 1,
          thickness: 1,
          color: Theme.of(context).colorScheme.outlineVariant.withValues(
                alpha: 0.45,
              ),
        ),
      ),
      title: widget.isSearch
          ? null
          : Row(
              children: [
                Text(
                  widget.itemType.localized(l10n),
                  style: TextStyle(color: Theme.of(context).hintColor),
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
                          color: Theme.of(context).textTheme.bodySmall!.color,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
      actions: [
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
          ),
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
        _LibraryActionCarousel(
          actions: [
            _LibraryAction(
              id: 'search',
              icon: Broken.search_normal_1,
              label: l10n.search,
              onPressed: () {
                if (!widget.isSearch) widget.textEditingController.clear();
                widget.onSearchToggle();
              },
            ),
            _LibraryAction(
              id: 'notifications',
              icon: Broken.notification,
              label: l10n.updates,
              onPressed: () => context.push('/notifications'),
            ),
            _LibraryAction(
              id: 'update-library',
              icon: Broken.refresh_left_square,
              label: l10n.update_library,
              onPressed: () {
                manga.whenData((entries) {
                  updateLibrary(
                    ref: ref,
                    context: context,
                    mangaList: entries,
                    itemType: widget.itemType,
                  );
                });
              },
            ),
            _LibraryAction(
              id: 'random-entry',
              icon: Broken.programming_arrows,
              label: l10n.open_random_entry,
              onPressed: () {
                manga.whenData((entries) {
                  if (entries.isEmpty) return;
                  final shuffledEntries = List<Manga>.of(entries)..shuffle();
                  final randomManga = shuffledEntries.first;
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
              },
            ),
            _LibraryAction(
              id: 'import',
              icon: Broken.arrow_square,
              label: l10n.import,
              onPressed: () => showImportLocalDialog(context, widget.itemType),
            ),
            _LibraryAction(
              id: 'filters-sort',
              icon: Broken.slider_horizontal,
              label: l10n.filter,
              onPressed: () => showLibrarySettingsSheet(
                context: context,
                vsync: widget.vsync,
                settings: widget.settings,
                itemType: widget.itemType,
                entries: widget.entries,
              ),
            ),
            if (widget.itemType == ItemType.anime)
              _LibraryAction(
                id: 'torrent-stream',
                icon: Broken.video_play,
                label: l10n.torrent_stream,
                onPressed: () => addTorrent(context),
              ),
          ],
        ),
      ],
    );
  }
}

class _LibraryAction {
  final String id;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _LibraryAction({
    required this.id,
    required this.icon,
    required this.label,
    required this.onPressed,
  });
}

/// A three-item action carousel with a shallow arc and a swipeable sequence.
class _LibraryActionCarousel extends StatefulWidget {
  final List<_LibraryAction> actions;

  const _LibraryActionCarousel({super.key, required this.actions});

  @override
  State<_LibraryActionCarousel> createState() =>
      _LibraryActionCarouselState();
}

class _LibraryActionCarouselState extends State<_LibraryActionCarousel> {
  static const double _leftPosition = 0;
  static const double _centerPosition = 56;
  static const double _rightPosition = 112;
  static const double _width = 160;
  static const double _height = 56;

  int _centerIndex = 1;
  String? _enteringActionId;
  double _dragDistance = 0;

  int _wrappedIndex(int index) =>
      (index % widget.actions.length + widget.actions.length) %
      widget.actions.length;

  List<String> _visibleIds(int centerIndex) {
    if (widget.actions.isEmpty) return const [];
    return [
      widget.actions[_wrappedIndex(centerIndex - 1)].id,
      widget.actions[_wrappedIndex(centerIndex)].id,
      widget.actions[_wrappedIndex(centerIndex + 1)].id,
    ];
  }

  void _move(int direction) {
    final count = widget.actions.length;
    if (count < 3) return;

    final previousIds = _visibleIds(_centerIndex);
    final nextCenter = _wrappedIndex(_centerIndex + direction);
    final nextIds = _visibleIds(nextCenter);
    final incomingIds = nextIds.where((id) => !previousIds.contains(id));
    final newId = incomingIds.isEmpty ? null : incomingIds.first;

    setState(() {
      _centerIndex = nextCenter;
      _enteringActionId = newId;
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final direction = velocity.abs() > 220
        ? (velocity > 0 ? 1 : -1)
        : _dragDistance.abs() > 30
        ? (_dragDistance > 0 ? 1 : -1)
        : 0;
    _dragDistance = 0;
    if (direction != 0) _move(direction);
  }

  Widget _buildSlot(int center, int slot) {
    final action = widget.actions[_wrappedIndex(center + slot)];
    final left = slot < 0
        ? _leftPosition
        : slot > 0
        ? _rightPosition
        : _centerPosition;
    return _LibraryArcActionIcon(
      key: ValueKey(action.id),
      action: action,
      left: left,
      isCenter: slot == 0,
      isEntering: action.id == _enteringActionId,
      centerPosition: _centerPosition,
    );
  }

  @override
  void didUpdateWidget(covariant _LibraryActionCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.actions.isNotEmpty && _centerIndex >= widget.actions.length) {
      _centerIndex = widget.actions.length - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.actions.length < 3) return const SizedBox(width: _width);

    final center = _wrappedIndex(_centerIndex);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (details) => _dragDistance += details.delta.dx,
      onHorizontalDragEnd: _handleDragEnd,
      onHorizontalDragCancel: () => _dragDistance = 0,
      child: SizedBox(
        width: _width,
        height: _height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (final slot in const [-1, 1, 0]) _buildSlot(center, slot),
          ],
        ),
      ),
    );
  }
}

class _LibraryArcActionIcon extends StatefulWidget {
  final _LibraryAction action;
  final double left;
  final bool isCenter;
  final bool isEntering;
  final double centerPosition;

  const _LibraryArcActionIcon({
    super.key,
    required this.action,
    required this.left,
    required this.isCenter,
    required this.isEntering,
    required this.centerPosition,
  });

  @override
  State<_LibraryArcActionIcon> createState() => _LibraryArcActionIconState();
}

class _LibraryArcActionIconState extends State<_LibraryArcActionIcon> {
  static const _duration = Duration(milliseconds: 260);

  late double _left;
  late double _top;
  late double _scale;
  late double _opacity;
  late double _rotation;

  @override
  void initState() {
    super.initState();
    if (widget.isEntering) {
      _left = widget.centerPosition;
      _top = 2;
      _scale = 0.52;
      _opacity = 0;
      _rotation = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(_setTargetPosition);
      });
    } else {
      _setTargetPosition();
    }
  }

  void _setTargetPosition() {
    _left = widget.left;
    _top = widget.isCenter ? 2 : 8;
    _scale = widget.isCenter ? 1.08 : 0.82;
    _opacity = widget.isCenter ? 1 : 0.62;
    _rotation = widget.isCenter
        ? 0
        : (widget.left < widget.centerPosition ? -0.1 : 0.1);
  }

  @override
  void didUpdateWidget(covariant _LibraryArcActionIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.left != widget.left || oldWidget.isCenter != widget.isCenter) {
      _setTargetPosition();
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface.withValues(
          alpha: widget.isCenter ? 0.94 : 0.58,
        );

    return AnimatedPositioned(
      duration: _duration,
      curve: Curves.easeOutCubic,
      left: _left,
      top: _top,
      width: 48,
      height: 48,
      child: AnimatedOpacity(
        duration: _duration,
        curve: Curves.easeOutCubic,
        opacity: _opacity,
        child: AnimatedScale(
          duration: _duration,
          curve: Curves.easeOutCubic,
          scale: _scale,
          child: Transform.rotate(
            angle: _rotation,
            child: IconButton(
              tooltip: widget.action.label,
              onPressed: widget.action.onPressed,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
              focusColor: Colors.transparent,
              icon: Icon(
                widget.action.icon,
                size: widget.isCenter ? 22 : 19,
                color: color,
              ),
            ),
          ),
        ),
      ),
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
          ref.read(isLongPressedStateProvider.notifier).update(!isLongPressed);
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
                ref.read(mangasListStateProvider.notifier).selectSome(manga);
              }
              ref.read(isLongPressedStateProvider.notifier).update(false);
            } else {
              for (var manga in data) {
                ref.read(mangasListStateProvider.notifier).selectSome(manga);
              }
            }
          },
          icon: const Icon(Broken.back_square),
        ),
      ],
    );
  }
}
