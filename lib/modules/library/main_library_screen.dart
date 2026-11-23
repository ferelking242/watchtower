// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/utils/item_type_icons.dart';
import 'package:watchtower/eval/model/m_bridge.dart' show botToast;
import 'package:watchtower/main.dart';
import 'package:watchtower/models/category.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/modules/library/library_screen.dart';
import 'package:watchtower/modules/library/providers/isar_providers.dart';
import 'package:watchtower/modules/library/providers/library_filter_provider.dart';
import 'package:watchtower/modules/library/providers/library_state_provider.dart';
import 'package:watchtower/modules/library/services/library_maintenance.dart';
import 'package:watchtower/modules/library/services/maintenance_notification_service.dart';
import 'package:watchtower/modules/library/widgets/library_dialogs.dart';
import 'package:watchtower/modules/library/widgets/library_filter_sort_menu.dart';
import 'package:watchtower/modules/manga/detail/providers/state_providers.dart';
import 'package:watchtower/modules/more/providers/downloaded_only_state_provider.dart';
import 'package:watchtower/modules/more/settings/library/providers/library_settings_provider.dart';
import 'package:watchtower/modules/widgets/manga_image_card_widget.dart';
import 'package:watchtower/modules/more/categories/providers/isar_providers.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/services/library_updater.dart';
import 'package:watchtower/utils/adaptive_overlay_menu.dart';
import 'package:watchtower/utils/display_fonts.dart';

// ─── Design tokens (resolved from theme at build time) ─────────────────────
// cs.outlineVariant and _kTextSecondary replaced with cs.outlineVariant / cs.onSurfaceVariant
// in each build method to respect the active theme.

// ─── Type order ──────────────────────────────────────────────────────────────
// Manga first so the coverflow opens as [Manga] [Watch] [Novel] — Watch
// centered, neighbors peeking at the edges (user request). Music is NOT here:
// the music library now lives behind Hub → Music.
const _kTypes = <ItemType>[
  ItemType.manga,
  ItemType.anime,
  ItemType.novel,
  ItemType.game,
];

// ─── Type arc geometry ───────────────────────────────────────────────────────
// Fixed pixel anchors on the leading edge: the left shoulder sits at x == 0 so
// the cluster hugs the margin instead of floating in a wide slot.
const _kArcFrontSize = 44.0;
const _kArcSideSize = 27.0;

/// Visible gap between two neighbouring circles. Tight enough that the three
/// icons read as one cluster, wide enough that they do not melt together.
const _kArcGap = 4.0;
const _kArcStep = _kArcFrontSize / 2 + _kArcGap + _kArcSideSize / 2;
const _kArcWidth = _kArcStep * 2 + _kArcSideSize;
const _kArcHeight = 46.0;
const _kArcFrontCentreX = _kArcSideSize / 2 + _kArcStep;

// ─── App-bar action button size ──────────────────────────────────────────────
// The right-hand actions are a *secondary* cluster next to the type arc, so
// they sit one step smaller (40 vs 44) and tighter (6 vs the arc's gap): equal
// discs made the two ends compete, and a looser gap read as three unrelated
// buttons. Their glyphs stay at 20 px so the difference is proportion, not
// legibility.
const _kActionBtnSize = 40.0;
const _kActionBtnIconSize = 20.0;
const _kActionBtnGap = 6.0;

/// The arc is a circle plus a label hanging below it, while the action row is
/// just discs. Centring both against the same 60 px row leaves the buttons a
/// few pixels under the circle's optical centre; this lifts them back up.
const _kActionRowBaselineLift = 5.0;

// ─── Main screen ──────────────────────────────────────────────────────────────
class MainLibraryScreen extends ConsumerStatefulWidget {
  final String? presetInput;
  const MainLibraryScreen({super.key, this.presetInput});

  @override
  ConsumerState<MainLibraryScreen> createState() => _MainLibraryScreenState();
}

class _MainLibraryScreenState extends ConsumerState<MainLibraryScreen>
    with TickerProviderStateMixin {
  bool _showSearch = false;
  bool _searchOpening = false;
  bool _searchClosing = false;
  bool _searchIconRotated = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  int _selectedCatIndex = 0;
  Settings? _cachedSettings;
  List<Manga> _cachedMangaList = [];

  // Continuous position of the type carousel: the selected type sits at
  // round(_arcOffset) and its two neighbours one step to either side. It is
  // deliberately not clamped so the wheel/drag can run past the ends and wrap.
  double _arcOffset = 1.0; // 1 == ItemType.anime (Watch)
  late final AnimationController _arcAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  VoidCallback? _arcListener;
  double _arcFrom = 0;
  double _arcDelta = 0;

  @override
  void initState() {
    super.initState();
    if (widget.presetInput != null && widget.presetInput!.isNotEmpty) {
      _showSearch = true;
      _searchController.text = widget.presetInput!;
    }
    _searchFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    final listener = _arcListener;
    if (listener != null) _arcAnim.removeListener(listener);
    _arcAnim.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  ItemType get _currentType => _kTypes[_typeIndex];

  /// Index of the type currently under the front (centre) slot.
  int get _typeIndex {
    final n = _kTypes.length;
    return ((_arcOffset.round() % n) + n) % n;
  }

  /// Rotates the carousel so the type [steps] positions away becomes selected.
  /// Keeps the raw offset continuous so the arc animation runs the short way.
  void _arcStep(int steps) {
    final target = _arcOffset.roundToDouble() + steps;
    _animateArcTo(target);
  }

  void _animateArcTo(double target) {
    final previous = _arcListener;
    if (previous != null) _arcAnim.removeListener(previous);
    _arcAnim.stop();
    _arcFrom = _arcOffset;
    _arcDelta = target - _arcFrom;
    void listener() {
      if (!mounted) return;
      setState(() => _arcOffset = _arcFrom + _arcDelta * _arcAnim.value);
    }

    _arcListener = listener;
    _arcAnim.addListener(listener);
    _arcAnim.forward(from: 0).whenComplete(() {
      if (_arcListener != null) _arcAnim.removeListener(_arcListener!);
      _arcListener = null;
      if (!mounted) return;
      setState(() {
        _arcOffset = target;
        _selectedCatIndex = 0;
      });
    });
  }

  Future<void> _toggleSearch() async {
    if (_showSearch) {
      if (_searchClosing) return;
      // Mirror the opening sequence on close: the field has to stay mounted
      // while the container animates back to zero width, otherwise swapping the
      // child out for an empty box made the collapse invisible.
      setState(() => _searchClosing = true);
      await Future<void>.delayed(const Duration(milliseconds: 260));
      if (!mounted) return;
      setState(() {
        _searchClosing = false;
        _showSearch = false;
        _searchController.clear();
        _searchFocus.unfocus();
        _searchIconRotated = false;
      });
      return;
    }
    if (_searchOpening) return;

    // Let the search control complete its spin before it expands over the
    // carousel from right to left.
    setState(() {
      _searchOpening = true;
      _searchIconRotated = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 240));
    if (!mounted) return;
    setState(() {
      _searchOpening = false;
      _showSearch = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  // ── Arc type selector ──────────────────────────────────────────────────────
  //
  // Three types are drawn on a shallow half-circle: the selected one sits at
  // the front (top of the arc, largest, opaque), its two neighbours ride the
  // ends of the arc, slightly smaller and dimmed so they read as "behind".
  // Dragging or scrolling spins the arc; the middle icon always ends up in
  // front. The wheel of types wraps, so the carousel never dead-ends.
  //
  // Geometry is fixed in pixels and anchored on the leading edge: the left
  // shoulder of the arc sits at x == 0, so the group hugs the left margin
  // instead of floating in the middle of a wide slot, and the three circles
  // are one short step apart so they read as a single cluster.
  Widget _buildArcTypeSelector(ColorScheme cs, bool isDark) {
    final n = _kTypes.length;
    final l10n = l10nLocalizations(context)!;

    String nameOf(ItemType type) => switch (type) {
      ItemType.anime => l10n.watch,
      ItemType.manga => l10n.manga,
      ItemType.novel => l10n.novel,
      ItemType.game => l10n.catalog_tab_games,
      ItemType.music => l10n.catalog_tab_music,
      ItemType.plugin => l10n.browse_plugins,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: _kArcWidth,
          height: _kArcHeight,
          child: Listener(
            onPointerSignal: (event) {
              if (event is! PointerScrollEvent) return;
              final delta = event.scrollDelta.dy != 0
                  ? event.scrollDelta.dy
                  : event.scrollDelta.dx;
              if (delta == 0) return;
              _arcStep(delta > 0 ? 1 : -1);
            },
            // No horizontal drag here on purpose: a drag on the arc competed
            // with the per-cover swipe actions in the grid below (the arc's
            // gesture arena won on short horizontal flicks), so the swipe
            // silently spun the type selector instead of running the user's
            // action. Tapping a shoulder still steps the arc, and the pointer
            // signal above keeps desktop wheel/scroll stepping.
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const frontY = _kArcHeight / 2;
                  const sideY = _kArcHeight / 2 + 7;
                  const cx = _kArcFrontCentreX;

                  // Render the three slots around the nearest integer
                  // position. A slot's distance `d` is continuous, so the two
                  // end slots are only ever swapped while they sit at
                  // |d| ~ 1.5 and are fully faded out — the hand-off is
                  // invisible.
                  final centre = _arcOffset.round();
                  final painted = <Widget>[];
                  for (
                    var slotIndex = centre - 1;
                    slotIndex <= centre + 1;
                    slotIndex++
                  ) {
                    final d = slotIndex - _arcOffset;
                    final ad = d.abs();
                    if (ad >= 1.5) continue;
                    final type = _kTypes[((slotIndex % n) + n) % n];
                    // Full opacity at the front, ~0.55 on the shoulders, gone
                    // at 1.5.
                    final opacity = ad <= 1.0
                        ? 1.0 - 0.45 * ad
                        : 0.55 * (1.5 - ad) / 0.5;
                    final size =
                        _kArcFrontSize +
                        (_kArcSideSize - _kArcFrontSize) * ad.clamp(0.0, 1.0);
                    final isFront = ad < 0.5;
                    final x = cx + d.clamp(-1.5, 1.5) * _kArcStep;
                    final y =
                        sideY + (frontY - sideY) * (1.0 - ad.clamp(0.0, 1.0));

                    painted.add(
                      Positioned(
                        left: x - size / 2,
                        top: y - size / 2,
                        width: size,
                        height: size,
                        child: GestureDetector(
                          onTap: () {
                            final diff = slotIndex - _arcOffset.round();
                            if (diff != 0) _arcStep(diff);
                          },
                          child: Opacity(
                            opacity: opacity.clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: isFront
                                    ? LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          cs.primary,
                                          cs.primary.withValues(alpha: 0.75),
                                        ],
                                      )
                                    : null,
                                color: isFront
                                    ? null
                                    : cs.onSurface.withValues(alpha: 0.05),
                                border: Border.all(
                                  color: isFront
                                      ? cs.primary.withValues(alpha: 0.85)
                                      : (isDark
                                            ? cs.onSurface.withValues(
                                                alpha: 0.22,
                                              )
                                            : cs.outline.withValues(
                                                alpha: 0.35,
                                              )),
                                  width: isFront ? 1.5 : 1.0,
                                ),
                                boxShadow: isFront
                                    ? [
                                        BoxShadow(
                                          color: cs.primary.withValues(
                                            alpha: 0.35,
                                          ),
                                          blurRadius: 14,
                                          spreadRadius: -2,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Icon(
                                itemTypeIcon(type),
                                color: isFront
                                    ? cs.onSurface
                                    : (isDark
                                          ? cs.onSurface.withValues(alpha: 0.60)
                                          : cs.onSurface.withValues(
                                              alpha: 0.55,
                                            )),
                                size: isFront ? 22 : 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  return Stack(clipBehavior: Clip.none, children: painted);
                },
              ),
            ),
          ),
        ),
        // The type name hangs under the front circle rather than inside it:
        // the icons stay pure glyphs and the label keeps a readable size.
        SizedBox(
          height: 14,
          width: _kArcWidth,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Text(
                nameOf(_kTypes[((_arcOffset.round() % n) + n) % n]),
                key: ValueKey(_arcOffset.round()),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: kMangaDisplayFont,
                  fontSize: 11,
                  height: 1.0,
                  letterSpacing: 0.4,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.70),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Ghost circular icon button ─────────────────────────────────────────────
  Widget _iconBtn({
    required IconData icon,
    required VoidCallback onTap,
    bool active = false,
    String? tooltip,
    double rotationTurns = 0,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: _kActionBtnSize,
          height: _kActionBtnSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? cs.primary.withValues(alpha: 0.90)
                : (isDark
                      ? cs.onSurface.withValues(alpha: 0.08)
                      : cs.onSurface.withValues(alpha: 0.06)),
          ),
          child: AnimatedRotation(
            turns: rotationTurns,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeInOutCubic,
            child: Icon(
              icon,
              color: active
                  ? cs.onSurface
                  : (isDark
                        ? cs.onSurface.withValues(alpha: 0.60)
                        : cs.onSurface.withValues(alpha: 0.55)),
              size: _kActionBtnIconSize,
            ),
          ),
        ),
      ),
    );
  }

  // ── Open random manga ──────────────────────────────────────────────────────
  void _openRandom(List<Manga> mangaList) {
    if (mangaList.isEmpty) return;
    final randomManga = (List.of(mangaList)..shuffle()).first;
    pushToMangaReaderDetail(
      ref: ref,
      archiveId: randomManga.isLocalArchive ?? false ? randomManga.id : null,
      context: context,
      lang: randomManga.lang!,
      mangaM: randomManga,
      source: randomManga.source!,
      sourceId: randomManga.sourceId,
    );
  }

  // ── Shared filter overlay content ─────────────────────────────────────────
  Widget _buildFilterOverlayContent(VoidCallback close) {
    if (_cachedSettings == null) return const SizedBox.shrink();
    return LibraryFilterSortMenu(
      itemType: _currentType,
      settings: _cachedSettings!,
      entries: _cachedMangaList,
      close: close,
      onSelect: () {
        ref.read(isLongPressedStateProvider.notifier).update(true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = l10nLocalizations(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final settingsAsync = ref.watch(getSettingsStreamProvider);
    final mangaAsync = ref.watch(
      getAllMangaStreamProvider(categoryId: null, itemType: _currentType),
    );
    final catsAsync = ref.watch(
      getMangaCategorieStreamProvider(itemType: _currentType),
    );

    final settingsList = settingsAsync.asData?.value ?? <Settings>[];
    final settings = settingsList.isNotEmpty ? settingsList.first : null;
    if (settings != null) _cachedSettings = settings;

    final mangaList = mangaAsync.asData?.value ?? <Manga>[];
    _cachedMangaList = mangaList;

    final cats = catsAsync.maybeWhen(
      data: (c) => c,
      orElse: () => <Category>[],
    );
    // Category tabs and per-category item counts are user-toggled from the
    // Display menu; the tabs are on by default.
    final showCategoryTabs =
        settings == null ||
        ref.watch(
          libraryShowCategoryTabsStateProvider(
            itemType: _currentType,
            settings: settings,
          ),
        );
    // Counts default to on: before the settings row loads there is no
    // `Settings` object to read the toggle from, and hiding the numbers for a
    // frame made the bar visibly jump.
    final showItemCounts =
        settings == null ||
        ref.watch(
          libraryShowNumbersOfItemsStateProvider(
            itemType: _currentType,
            settings: settings,
          ),
        );
    // Highlight the filter icon whenever a filter actually narrows the list.
    final filtersActive =
        settings != null &&
        libraryFiltersActive(
          ref,
          itemType: _currentType,
          settings: settings,
          entries: mangaList,
        );
    final filterButton = AdaptiveOverlayMenuButton(
      menuWidth: 250,
      trigger: ValueListenableBuilder<Set<String>>(
        valueListenable: selectedLibrarySourcesFilter(_currentType),
        builder: (context, selectedSources, _) =>
            ValueListenableBuilder<Set<int>>(
              valueListenable: selectedLibraryCategoriesFilter(_currentType),
              builder: (context, selectedCategories, _) {
                // `libraryFiltersActive` reads the source/category/rating
                // selections imperatively, so the two builders above are what
                // make the icon repaint when they change.
                final active = filtersActive;
                return Tooltip(
                  message: l10n.filter,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: _kActionBtnSize,
                    height: _kActionBtnSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active
                          ? cs.primary
                          : (isDark
                                ? cs.onSurface.withValues(alpha: 0.08)
                                : cs.onSurface.withValues(alpha: 0.06)),
                    ),
                    child: Icon(
                      Broken.filter,
                      // Filled accent disc + contrasting glyph: an active
                      // filter has to be obvious at a glance.
                      color: active
                          ? cs.onPrimary
                          : (isDark
                                ? cs.onSurface.withValues(alpha: 0.60)
                                : cs.onSurface.withValues(alpha: 0.55)),
                      size: _kActionBtnIconSize,
                    ),
                  ),
                );
              },
            ),
      ),
      contentBuilder: _buildFilterOverlayContent,
    );

    final int? selectedCatId = _selectedCatIndex == 0
        ? null
        : (cats.length >= _selectedCatIndex
              ? cats[_selectedCatIndex - 1].id
              : null);
    final int extCatId = selectedCatId ?? -1;

    return SafeArea(
      bottom: false,
      child: PopScope(
        // Back closes the search overlay before it leaves the library: while the
        // field is open the system back gesture should undo the search, not
        // navigate away from the tab.
        canPop: !_showSearch,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _showSearch) unawaited(_toggleSearch());
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1: arc type selector + action icons ────────────────
            Padding(
              // No leading gutter: the arc's left shoulder is a circle whose
              // optical margin already reads as ~4 px, so any extra padding
              // pushed the group away from the edge.
              padding: const EdgeInsets.fromLTRB(0, 6, 12, 0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final rowWidth = constraints.maxWidth;
                  return SizedBox(
                    width: rowWidth,
                    height: 60,
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned.fill(
                          child: AnimatedOpacity(
                            opacity: (_showSearch && !_searchClosing) ? 0 : 1,
                            duration: const Duration(milliseconds: 200),
                            child: IgnorePointer(
                              ignoring: _showSearch && !_searchClosing,
                              child: Row(
                                children: [
                                  _buildArcTypeSelector(cs, isDark),
                                  const Spacer(),
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: _kActionRowBaselineLift,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _iconBtn(
                                          icon: Broken.search_normal_1,
                                          onTap: () =>
                                              unawaited(_toggleSearch()),
                                          active: _showSearch,
                                          tooltip: l10n.search,
                                          rotationTurns: _searchIconRotated
                                              ? 1
                                              : 0,
                                        ),
                                        const SizedBox(width: _kActionBtnGap),
                                        filterButton,
                                        const SizedBox(width: _kActionBtnGap),
                                        _buildThreeDotsBtn(
                                          context,
                                          l10n,
                                          mangaList,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 7,
                          child: ClipRect(
                            child: AnimatedContainer(
                              width: (_showSearch && !_searchClosing)
                                  ? rowWidth
                                  : 0,
                              height: 46,
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeInOutCubic,
                              child: (_showSearch || _searchClosing)
                                  ? SizedBox(
                                      width: rowWidth,
                                      height: 46,
                                      child: _buildSearchBar(cs, isDark),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Container(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.42),
              ),
            ),

            // ── Category bar ──────────────────────────────────────────────
            if (showCategoryTabs)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: _buildCategoryBar(
                  context,
                  cats,
                  cs,
                  isDark,
                  mangaList,
                  showItemCounts,
                ),
              ),

            const SizedBox(height: 8),

            // ── Library content ──────────────────────────────────────────
            Expanded(
              // No horizontal-drag wrapper here: it stole the gesture from the
              // per-cover swipe actions, so swiping a cover spun the type arc
              // instead of running the configured action. The arc has its own
              // drag handler.
              child: LibraryScreen(
                key: ValueKey('lib_${_typeIndex}_$extCatId'),
                itemType: _currentType,
                presetInput: null,
                hideOwnAppBar: true,
                // Keep the embedded library controller in sync when search
                // closes, so the old query cannot stay applied.
                externalSearchQuery: _showSearch ? _searchController.text : '',
                externalCategoryId: extCatId,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Animated search bar with filter overlay ────────────────────────────────
  Widget _buildSearchBar(ColorScheme cs, bool isDark) {
    final l10n = l10nLocalizations(context)!;
    final focused = _searchFocus.hasFocus;
    final hasText = _searchController.text.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 46,
      decoration: BoxDecoration(
        color: focused
            ? (isDark ? cs.surfaceContainerHighest : cs.surface)
            : (isDark ? cs.surfaceContainerHigh : cs.surfaceContainerHigh),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: focused
              ? cs.primary.withValues(alpha: 0.50)
              : (isDark
                    ? cs.onSurface.withValues(alpha: 0.06)
                    : cs.outline.withValues(alpha: 0.12)),
          width: focused ? 1.4 : 1.0,
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.14),
                  blurRadius: 12,
                  spreadRadius: -3,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),

          // Search icon
          Icon(
            Broken.search_normal_1,
            color: focused ? cs.primary : cs.onSurface.withValues(alpha: 0.40),
            size: 18,
          ),
          const SizedBox(width: 10),

          // Text field
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              autofocus: false,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 14.5,
                fontWeight: FontWeight.w400,
              ),
              decoration: InputDecoration(
                hintText: l10nLocalizations(context)!.search,
                hintStyle: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.35),
                  fontSize: 14.5,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // Clear button
          AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            opacity: hasText ? 1.0 : 0.0,
            child: GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() {});
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  Broken.close_circle,
                  color: cs.onSurface.withValues(alpha: 0.38),
                  size: 18,
                ),
              ),
            ),
          ),

          // Multi-level filter overlay from the Sep 17 Library UI.
          AdaptiveOverlayMenuButton(
            menuWidth: 250,
            trigger: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                Broken.filter,
                size: 18,
                color: focused
                    ? cs.primary.withValues(alpha: 0.70)
                    : cs.onSurface.withValues(alpha: 0.38),
              ),
            ),
            contentBuilder: _buildFilterOverlayContent,
          ),

          IconButton(
            tooltip: l10n.settings_close_search,
            visualDensity: VisualDensity.compact,
            onPressed: () => unawaited(_toggleSearch()),
            icon: Icon(
              Broken.close_circle,
              color: cs.onSurface.withValues(alpha: 0.48),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  // ── Unified category bar (no double-band) ──────────────────────────────────
  Widget _buildCategoryBar(
    BuildContext context,
    List<Category> cats,
    ColorScheme cs,
    bool isDark,
    List<Manga> mangaList,
    bool showItemCounts,
  ) {
    final l10n = l10nLocalizations(context)!;
    final settings = _cachedSettings;

    return ValueListenableBuilder<Set<String>>(
      valueListenable: selectedLibrarySourcesFilter(_currentType),
      builder: (context, selectedSources, _) =>
          ValueListenableBuilder<Set<int>>(
            valueListenable: selectedLibraryCategoriesFilter(_currentType),
            builder: (context, selectedCategories, _) {
              // Numbers follow every filter *except* the category one: each
              // pill reports its own bucket, so scoping the count to the
              // selected category made all the other pills read 0.
              final filtered = _filteredForCounts(
                settings,
                mangaList,
                selectedSources: selectedSources,
              );

              int? countFor(int? catId) {
                if (!showItemCounts) return null;
                if (catId == null) return filtered.length;
                return filtered
                    .where((m) => m.categories?.contains(catId) ?? false)
                    .length;
              }

              return Row(
                children: [
                  Tooltip(
                    message: l10n.manage_categories,
                    child: Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _showManageCategories(context, cats),
                        child: Container(
                          height: 36,
                          width: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark
                                  ? cs.onSurface.withValues(alpha: 0.28)
                                  : cs.outline.withValues(alpha: 0.42),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.grid_view_rounded,
                            size: 17,
                            color: cs.onSurface.withValues(alpha: 0.62),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(
                          alpha: isDark ? 0.24 : 0.45,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isDark
                              ? cs.onSurface.withValues(alpha: 0.26)
                              : cs.outline.withValues(alpha: 0.40),
                          width: 1,
                        ),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _pill(
                              label: l10n.media_all,
                              count: countFor(null),
                              selected: _selectedCatIndex == 0,
                              onTap: () =>
                                  setState(() => _selectedCatIndex = 0),
                              cs: cs,
                              isDark: isDark,
                            ),
                            for (int i = 0; i < cats.length; i++)
                              _pill(
                                label: cats[i].name ?? '',
                                count: countFor(cats[i].id),
                                selected: _selectedCatIndex == i + 1,
                                onTap: () =>
                                    setState(() => _selectedCatIndex = i + 1),
                                cs: cs,
                                isDark: isDark,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
    );
  }

  /// Entries that the grid would display for the current filters, used by the
  /// category pills so their numbers match the visible content.
  List<Manga> _filteredForCounts(
    Settings? settings,
    List<Manga> mangaList, {
    required Set<String> selectedSources,
  }) {
    if (settings == null) return mangaList;
    final itemType = _currentType;
    final downloadedOnly = ref.watch(downloadedOnlyStateProvider);
    final base = ref.watch(
      filteredLibraryMangaProvider(
        data: mangaList,
        downloadFilterType: ref.watch(
          mangaFilterDownloadedStateProvider(
            itemType: itemType,
            mangaList: mangaList,
            settings: settings,
          ),
        ),
        unreadFilterType: ref.watch(
          mangaFilterUnreadStateProvider(
            itemType: itemType,
            mangaList: mangaList,
            settings: settings,
          ),
        ),
        startedFilterType: ref.watch(
          mangaFilterStartedStateProvider(
            itemType: itemType,
            mangaList: mangaList,
            settings: settings,
          ),
        ),
        bookmarkedFilterType: ref.watch(
          mangaFilterBookmarkedStateProvider(
            itemType: itemType,
            mangaList: mangaList,
            settings: settings,
          ),
        ),
        completedFilterType: ref.watch(
          mangaFilterCompletedStateProvider(
            itemType: itemType,
            mangaList: mangaList,
            settings: settings,
          ),
        ),
        trackingFilterType: ref.watch(
          mangaFilterTrackingStateProvider(
            itemType: itemType,
            mangaList: mangaList,
            settings: settings,
          ),
        ),
        sortType:
            ref
                .watch(
                  sortLibraryMangaStateProvider(
                    itemType: itemType,
                    settings: settings,
                  ),
                )
                .index ??
            0,
        downloadedOnly: downloadedOnly,
        searchQuery: _showSearch ? _searchController.text : '',
        ignoreFiltersOnSearch: false,
      ),
    );
    final scoped = applyLibrarySourceAndCategoryFilters(
      itemType,
      base,
      selectedSources: selectedSources,
      selectedCategories: const <int>{},
    );
    return applyLibraryContentRatingFilter(
      scoped,
      ref.watch(libraryContentRatingFilterProvider),
    );
  }

  Widget _pill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required ColorScheme cs,
    required bool isDark,
    int? count,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        margin: const EdgeInsets.only(right: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: isDark ? 0.20 : 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? cs.primary
                    : cs.onSurfaceVariant.withValues(alpha: 0.65),
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 5),
              // "Tous (751)" reads at a glance and needs no extra chrome, so
              // the count is part of the label instead of a separate chip that
              // crowded the pill on narrow screens.
              Text(
                '($count)',
                style: TextStyle(
                  color: selected
                      ? cs.primary.withValues(alpha: 0.85)
                      : cs.onSurfaceVariant.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w600,
                  fontSize: 11.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Three-dots popup ───────────────────────────────────────────────────────
  Widget _buildThreeDotsBtn(
    BuildContext context,
    dynamic l10n,
    List<Manga> mangaList,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: _kActionBtnSize,
      height: _kActionBtnSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark
              ? cs.onSurface.withValues(alpha: 0.08)
              : cs.onSurface.withValues(alpha: 0.06),
        ),
        child: ClipOval(
          child: AdaptiveOverlayMenu<int>(
            icon: Icon(
              Broken.more_2,
              color: isDark
                  ? cs.onSurface.withValues(alpha: 0.60)
                  : cs.onSurface.withValues(alpha: 0.55),
              size: _kActionBtnIconSize,
            ),
            padding: EdgeInsets.zero,
            menuWidth: 230,
            itemBuilder: (_) => [
              PopupMenuItem<int>(
                value: 1,
                child: Row(
                  children: [
                    const Icon(Broken.refresh_left_square, size: 18),
                    const SizedBox(width: 12),
                    Text(l10n.update_library),
                  ],
                ),
              ),
              PopupMenuItem<int>(
                value: 2,
                child: Row(
                  children: [
                    const Icon(Broken.shuffle, size: 18),
                    const SizedBox(width: 12),
                    Text(l10n.open_random_entry),
                  ],
                ),
              ),
              PopupMenuItem<int>(
                value: 3,
                child: Row(
                  children: [
                    const Icon(Broken.folder_add, size: 18),
                    const SizedBox(width: 12),
                    Text(l10n.import),
                  ],
                ),
              ),
              if (_currentType == ItemType.anime)
                PopupMenuItem<int>(
                  value: 4,
                  child: Row(
                    children: [
                      const Icon(Broken.video, size: 18),
                      const SizedBox(width: 12),
                      Text(l10n.torrent_stream),
                    ],
                  ),
                ),
              const PopupMenuItem<int>(
                enabled: false,
                value: 99,
                child: Divider(height: 1, indent: 0, endIndent: 0),
              ),
              // Activity / Maintenance / Library settings are *sub-menus*: the
              // caret marks them so a tap that opens another panel is not
              // mistaken for an action that already ran.
              PopupMenuItem<int>(
                value: 5,
                child: Row(
                  children: [
                    const Icon(Broken.clock, size: 18),
                    const SizedBox(width: 12),
                    Text(l10n.library_menu_activity),
                    const Spacer(),
                    const Icon(Broken.arrow_right_3, size: 14),
                  ],
                ),
              ),
              PopupMenuItem<int>(
                value: 6,
                child: Row(
                  children: [
                    const Icon(Broken.setting, size: 18),
                    const SizedBox(width: 12),
                    Text(l10n.library_menu_maintenance),
                    const Spacer(),
                    const Icon(Broken.arrow_right_3, size: 14),
                  ],
                ),
              ),
              const PopupMenuItem<int>(
                enabled: false,
                value: 99,
                child: Divider(height: 1, indent: 0, endIndent: 0),
              ),
              PopupMenuItem<int>(
                value: 10,
                child: Row(
                  children: [
                    const Icon(Broken.setting_2, size: 18),
                    const SizedBox(width: 12),
                    Text(l10n.library_settings_title),
                  ],
                ),
              ),
            ],
            onSelected: (v) {
              switch (v) {
                case 1:
                  updateLibrary(
                    ref: ref,
                    context: context,
                    mangaList: mangaList,
                    itemType: _currentType,
                  );
                  break;
                case 2:
                  _openRandom(mangaList);
                  break;
                case 3:
                  showImportLocalDialog(context, _currentType);
                  break;
                case 4:
                  addTorrent(context);
                  break;
                case 5:
                  _openSubMenuAfterPopup(context, _showActivityMenu);
                  break;
                case 6:
                  _openSubMenuAfterPopup(context, _showMaintenanceMenu);
                  break;
                case 10:
                  context.push('/librarySettings');
                  break;
              }
            },
          ),
        ),
      ),
    );
  }

  // ── Sub-menu opener ────────────────────────────────────────────────────────
  //
  // The three-dots popup closes itself as soon as an item is picked, so opening
  // the nested Activity/Maintenance sheet straight from `onSelected` raced the
  // popup's exit animation and the sheet flickered under the closing panel.
  // Defer the sheet by one frame so the popup is gone first.
  void _openSubMenuAfterPopup(
    BuildContext context,
    void Function(BuildContext) open,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) open(context);
    });
  }

  // ── Activity sub-menu (History / Updates / Schedule / Downloads) ───────────

  void _showActivityMenu(BuildContext context) {
    final l10n = l10nLocalizations(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _LibraryMenuSheet(
        title: l10n.library_menu_activity,
        items: [
          _LibraryMenuItem(
            icon: Broken.clock,
            label: l10n.history,
            onTap: () {
              Navigator.pop(ctx);
              context.push('/history');
            },
          ),
          _LibraryMenuItem(
            icon: Broken.notification,
            label: l10n.updates,
            onTap: () {
              Navigator.pop(ctx);
              context.push('/updates');
            },
          ),
          _LibraryMenuItem(
            icon: Broken.calendar,
            label: l10n.schedule,
            onTap: () {
              Navigator.pop(ctx);
              context.push('/schedule');
            },
          ),
          _LibraryMenuItem(
            icon: Broken.document_download,
            label: l10n.downloads,
            onTap: () {
              Navigator.pop(ctx);
              context.push('/downloads');
            },
          ),
        ],
      ),
    );
  }

  // ── Maintenance sub-menu (Reindex / Downloads not in library) ──────────────

  void _showMaintenanceMenu(BuildContext context) {
    final l10n = l10nLocalizations(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _LibraryMenuSheet(
        title: l10n.library_menu_maintenance,
        items: [
          _LibraryMenuItem(
            icon: Broken.refresh_left_square,
            label: l10n.settings_reindex_downloads,
            subtitle: l10n.settings_reindex_downloads_desc,
            onTap: () {
              Navigator.pop(ctx);
              _runMaintenance(
                context,
                notifTitle: l10n.settings_reindex_downloads,
                busyMessage: l10n.settings_reindexing,
                run: (onProgress) => reindexDownloads(onProgress: onProgress),
                message: (result) => reindexToastMessage(l10n, result),
              );
            },
          ),
          _LibraryMenuItem(
            icon: Broken.folder_favorite,
            label: l10n.settings_downloads_not_in_library,
            subtitle: l10n.settings_downloads_not_in_library_desc,
            onTap: () {
              Navigator.pop(ctx);
              _runMaintenance(
                context,
                notifTitle: l10n.settings_downloads_not_in_library,
                busyMessage: l10n.settings_checking,
                run: (onProgress) =>
                    addDownloadedToLibrary(onProgress: onProgress),
                message: (added) => addDownloadedToastMessage(l10n, added),
              );
            },
          ),
          _LibraryMenuItem(
            icon: Broken.trash,
            label: l10n.settings_purge_missing_downloads,
            subtitle: l10n.settings_purge_missing_downloads_desc,
            onTap: () {
              Navigator.pop(ctx);
              _runMaintenance(
                context,
                notifTitle: l10n.settings_purge_missing_downloads,
                busyMessage: l10n.settings_checking,
                run: (onProgress) =>
                    purgeMissingDownloads(onProgress: onProgress),
                message: (purged) => purgeMissingToastMessage(l10n, purged),
              );
            },
          ),
          _LibraryMenuItem(
            icon: Broken.gallery_slash,
            label: l10n.library_clear_image_cache,
            subtitle: l10n.library_clear_image_cache_desc,
            onTap: () {
              Navigator.pop(ctx);
              PaintingBinding.instance.imageCache
                ..clear()
                ..clearLiveImages();
              botToast(l10n.cache_cleared);
            },
          ),
        ],
      ),
    );
  }

  /// Runs one maintenance action behind a blocking progress dialog and a system
  /// progress notification.
  ///
  /// These scans walk every download record and hit the filesystem, so they can
  /// take a few seconds on a large library. The old code fired a toast and
  /// returned immediately, which is why the action looked like it did nothing
  /// and the final toast often never appeared (the toast was posted, then the
  /// screen moved on). A modal barrier keeps the UI honest, a real progress bar
  /// in the notification keeps the user informed when they background the app,
  /// and the final toast lands on the screen the user is still looking at.
  Future<void> _runMaintenance<T>(
    BuildContext context, {
    required String notifTitle,
    required String busyMessage,
    required Future<T> Function(MaintenanceProgress onProgress) run,
    required String Function(T) message,
  }) async {
    final l10n = l10nLocalizations(context)!;
    final locale = Localizations.localeOf(context);
    final notif = MaintenanceNotificationService.instance;
    await notif.start(notifTitle, locale);
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _MaintenanceProgressDialog(message: busyMessage),
    );
    try {
      final result = await run(
        (done, total) => notif.update(notifTitle, done, total),
      );
      await notif.finish(notifTitle, message(result));
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) botToast(message(result));
    } catch (_) {
      await notif.cancel();
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) botToast(l10n.settings_error);
    }
  }

  void _showManageCategories(BuildContext context, List<Category> cats) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ManageCategoriesSheet(itemType: _currentType),
    );
  }
}

// ─── Manage Categories Sheet ──────────────────────────────────────────────────
class _ManageCategoriesSheet extends ConsumerStatefulWidget {
  final ItemType itemType;
  const _ManageCategoriesSheet({required this.itemType});

  @override
  ConsumerState<_ManageCategoriesSheet> createState() =>
      _ManageCategoriesSheetState();
}

class _ManageCategoriesSheetState
    extends ConsumerState<_ManageCategoriesSheet> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _delete(Category cat) async {
    if (cat.id == null) return;
    await isar.writeTxn(() => isar.categorys.delete(cat.id!));
  }

  Future<void> _add(List<Category> existing) async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    final cat = Category(
      name: name,
      forItemType: widget.itemType,
      pos: existing.length,
    );
    await isar.writeTxn(() => isar.categorys.put(cat));
    _ctrl.clear();
    setState(() {});
  }

  void _showEditCategory(BuildContext context, Category cat) {
    final cs = Theme.of(context).colorScheme;
    final nameCtrl = TextEditingController(text: cat.name ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.45,
        minChildSize: 0.3,
        maxChildSize: 0.7,
        builder: (_, sc) => Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Icon(Broken.edit, color: cs.primary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Edit Category',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: cs.onSurface.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Broken.close_circle,
                          color: cs.onSurface.withValues(alpha: 0.60),
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: cs.outline.withValues(alpha: 0.15), height: 1),
              // Content
              Expanded(
                child: ListView(
                  controller: sc,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Name field
                    Text(
                      'Name',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface.withValues(alpha: 0.60),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: cs.outline.withValues(alpha: 0.12),
                        ),
                      ),
                      child: TextField(
                        controller: nameCtrl,
                        style: TextStyle(color: cs.onSurface, fontSize: 14.5),
                        decoration: InputDecoration(
                          hintText: 'Category name',
                          hintStyle: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.35),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Quick icon picker
                    Text(
                      'Icon',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface.withValues(alpha: 0.60),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          [
                            Broken.tag,
                            Broken.book,
                            Broken.video,
                            Broken.music,
                            Broken.game,
                            Broken.star_1,
                            Broken.heart,
                            Broken.flash_1,
                            Broken.crown_1,
                            Broken.cpu,
                            Broken.danger,
                            Broken.document_text,
                          ].map((icon) {
                            return GestureDetector(
                              onTap: () {
                                // Store selected icon for saving
                              },
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: icon == Broken.tag
                                        ? cs.primary.withValues(alpha: 0.50)
                                        : cs.outline.withValues(alpha: 0.08),
                                  ),
                                ),
                                child: Icon(
                                  icon,
                                  size: 18,
                                  color: icon == Broken.tag
                                      ? cs.primary
                                      : cs.onSurface.withValues(alpha: 0.45),
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 24),
                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: TextButton(
                        onPressed: () async {
                          final newName = nameCtrl.text.trim();
                          if (newName.isNotEmpty && cat.id != null) {
                            cat.name = newName;
                            await isar.writeTxn(() => isar.categorys.put(cat));
                          }
                          Navigator.pop(context);
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: cs.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Save',
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final catsAsync = ref.watch(
      getMangaCategorieStreamProvider(itemType: widget.itemType),
    );
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, sc) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Broken.tag, color: cs.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.manage_categories,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          context.l10n.manage_categories_subtitle,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: cs.onSurface.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Broken.close_circle,
                        color: cs.onSurface.withValues(alpha: 0.60),
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: cs.outline.withValues(alpha: 0.15), height: 20),
            // Category list + add field
            Expanded(
              child: catsAsync.when(
                data: (cats) => ListView(
                  controller: sc,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (int ci = 0; ci < cats.length; ci++)
                      _CatRow(
                        cat: cats[ci],
                        itemType: widget.itemType,
                        onDelete: () => _delete(cats[ci]),
                        onEdit: () => _showEditCategory(context, cats[ci]),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: cs.outline.withValues(alpha: 0.15),
                              ),
                            ),
                            child: TextField(
                              controller: _ctrl,
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: 'New category name',
                                hintStyle: TextStyle(
                                  color: cs.onSurface.withValues(alpha: 0.38),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () => _add(cats),
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: cs.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Broken.element_plus,
                              color: cs.onSurface,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          backgroundColor: cs.surfaceContainerHigh,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Done',
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    'Error: $e',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Category row (in manage sheet) ──────────────────────────────────────────
class _CatRow extends ConsumerWidget {
  final Category cat;
  final ItemType itemType;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;

  const _CatRow({
    required this.cat,
    required this.itemType,
    required this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = l10nLocalizations(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final count = ref
        .watch(
          getAllMangaStreamProvider(categoryId: cat.id, itemType: itemType),
        )
        .maybeWhen(data: (l) => l.length, orElse: () => 0);
    final totalCountAsync = ref.watch(
      getAllMangaStreamProvider(categoryId: null, itemType: itemType),
    );
    final totalCount = totalCountAsync.maybeWhen(
      data: (l) => l.length,
      orElse: () => 1,
    );
    final percent = totalCount > 0 ? ((count / totalCount) * 100).round() : 0;

    // Reading count: items in category where isRead == false
    final readingCount = ref
        .watch(
          getAllMangaStreamProvider(categoryId: cat.id, itemType: itemType),
        )
        .maybeWhen(
          data: (l) =>
              l.where((m) => m.lastRead == null || m.lastRead == 0).length,
          orElse: () => 0,
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark
            ? cs.onSurface.withValues(alpha: 0.04)
            : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? cs.onSurface.withValues(alpha: 0.06)
              : cs.outline.withValues(alpha: 0.08),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Icon badge
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            cs.primary.withValues(alpha: 0.20),
                            cs.primary.withValues(alpha: 0.10),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Broken.tag, size: 17, color: cs.primary),
                    ),
                    const SizedBox(width: 12),
                    // Name + description
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cat.name ?? '',
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (cat.name != null && cat.name!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                context.l10n.library_items_percent(
                                  count,
                                  percent,
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurface.withValues(alpha: 0.40),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Delete button
                    GestureDetector(
                      onTap: onDelete,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: cs.error.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Broken.trash,
                          color: cs.error.withValues(alpha: 0.65),
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Stats row
                Row(
                  children: [
                    _statChip(
                      icon: Broken.book,
                      label: l10n.library_entries_count(count),
                      cs: cs,
                    ),
                    const SizedBox(width: 8),
                    _statChip(
                      icon: Broken.eye,
                      label: l10n.library_reading_count(readingCount),
                      cs: cs,
                    ),
                    const SizedBox(width: 8),
                    _statChip(icon: Broken.chart_2, label: '$percent%', cs: cs),
                  ],
                ),
                const SizedBox(height: 8),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: percent / 100.0,
                    minHeight: 4,
                    backgroundColor: cs.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(cs.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statChip({
    required IconData icon,
    required String label,
    required ColorScheme cs,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: cs.onSurface.withValues(alpha: 0.45)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurface.withValues(alpha: 0.50),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Library sub-menu sheet (Activity / Maintenance) ─────────────────────────

/// A single row inside a [_LibraryMenuSheet].
class _LibraryMenuItem {
  const _LibraryMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
}

/// Bottom sheet used for the nested "Activité" and "Maintenance" sub-menus of
/// the library three-dots button. Styled like the filter overlay: a single
/// translucent glass panel with a grab handle, so the sub-options read as a
/// proper sheet instead of a block nested inside the popup.
class _LibraryMenuSheet extends StatelessWidget {
  const _LibraryMenuSheet({required this.title, required this.items});

  final String title;
  final List<_LibraryMenuItem> items;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? cs.surface.withValues(alpha: 0.92)
        : cs.surfaceContainerHigh.withValues(alpha: 0.96);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.09)
        : Colors.black.withValues(alpha: 0.06);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: borderColor, width: 0.8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.42 : 0.13),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Grab handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: cs.onSurface.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  for (final item in items)
                    ListTile(
                      leading: Icon(item.icon, color: cs.onSurfaceVariant),
                      title: Text(item.label),
                      subtitle: item.subtitle == null
                          ? null
                          : Text(
                              item.subtitle!,
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                      onTap: item.onTap,
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Blocking progress dialog shown while a maintenance scan runs.
class _MaintenanceProgressDialog extends StatelessWidget {
  const _MaintenanceProgressDialog({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
