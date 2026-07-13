// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/category.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/modules/library/library_screen.dart';
import 'package:watchtower/modules/music/music_discovery_screen.dart';
import 'package:watchtower/modules/library/providers/isar_providers.dart';
import 'package:watchtower/modules/library/providers/library_state_provider.dart';
import 'package:watchtower/modules/library/widgets/library_dialogs.dart';
import 'package:watchtower/modules/library/widgets/library_filter_sort_menu.dart';
import 'package:watchtower/modules/library/widgets/library_settings_sheet.dart';
import 'package:watchtower/modules/manga/detail/providers/state_providers.dart';
import 'package:watchtower/modules/widgets/manga_image_card_widget.dart';
import 'package:watchtower/modules/more/categories/providers/isar_providers.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/services/library_updater.dart';
import 'package:watchtower/utils/adaptive_overlay_menu.dart';
import 'package:watchtower/utils/arrow_popup_menu.dart';
import 'package:watchtower/utils/global_style.dart';

// ─── Design tokens ───────────────────────────────────────────────────────────
const _kBorder        = Color(0xFF333333);
const _kAccent        = Color(0xFFE91E63);
const _kTextSecondary = Color(0xFF999999);

// ─── Type order ──────────────────────────────────────────────────────────────
const _kTypes = <ItemType>[
  ItemType.anime,
  ItemType.manga,
  ItemType.novel,
  ItemType.music,
  ItemType.game,
];

// ─── Type icons (Broken set) ─────────────────────────────────────────────────
const _kTypeIcons = <ItemType, IconData>{
  ItemType.anime:  Broken.video,
  ItemType.manga:  Broken.book,
  ItemType.novel:  Broken.document_text,
  ItemType.music:  Broken.music,
  ItemType.game:   Broken.game,
};

String _typeLabel(ItemType type) {
  switch (type) {
    case ItemType.anime:  return 'Watch';
    case ItemType.manga:  return 'Manga';
    case ItemType.novel:  return 'Novel';
    case ItemType.music:  return 'Music';
    case ItemType.game:   return 'Games';
    default:              return 'Library';
  }
}

// ─── Main screen ──────────────────────────────────────────────────────────────
class MainLibraryScreen extends ConsumerStatefulWidget {
  final String? presetInput;
  const MainLibraryScreen({super.key, this.presetInput});

  @override
  ConsumerState<MainLibraryScreen> createState() => _MainLibraryScreenState();
}

class _MainLibraryScreenState extends ConsumerState<MainLibraryScreen>
    with TickerProviderStateMixin {
  int _typeIndex = 0;
  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  int _selectedCatIndex = 0;
  Settings? _cachedSettings;
  List<Manga> _cachedMangaList = [];

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
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  ItemType get _currentType => _kTypes[_typeIndex];

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) {
        _searchController.clear();
        _searchFocus.unfocus();
      } else {
        // Focus the field after the expand animation
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _searchFocus.requestFocus(),
        );
      }
    });
  }

  // ── Ghost circular icon button ─────────────────────────────────────────────
  Widget _iconBtn({
    required IconData icon,
    required VoidCallback onTap,
    bool active = false,
    String? tooltip,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? _kAccent.withValues(alpha: 0.90)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : cs.onSurface.withValues(alpha: 0.06)),
          ),
          child: Icon(
            icon,
            color: active
                ? Colors.white
                : (isDark
                    ? Colors.white60
                    : cs.onSurface.withValues(alpha: 0.55)),
            size: 17,
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

  // ── Filter overlay content (search-field filter icon) ─────────────────────
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
    final cs   = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final settingsAsync = ref.watch(getSettingsStreamProvider);
    final mangaAsync    = ref.watch(
      getAllMangaStreamProvider(categoryId: null, itemType: _currentType),
    );
    final catsAsync = ref.watch(
      getMangaCategorieStreamProvider(itemType: _currentType),
    );

    final settingsList = settingsAsync.asData?.value ?? <Settings>[];
    final settings     = settingsList.isNotEmpty ? settingsList.first : null;
    if (settings != null) _cachedSettings = settings;

    final mangaList = mangaAsync.asData?.value ?? <Manga>[];
    _cachedMangaList = mangaList;

    final cats = catsAsync.maybeWhen(
      data: (c) => c,
      orElse: () => <Category>[],
    );

    final int? selectedCatId = _selectedCatIndex == 0
        ? null
        : (cats.length >= _selectedCatIndex
            ? cats[_selectedCatIndex - 1].id
            : null);
    final int extCatId = selectedCatId == null ? -1 : selectedCatId;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1: type pills + action icons ─────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Row(
                children: [
                  // ── Type pills (scrollable) ───────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(_kTypes.length, (i) {
                          final t = _kTypes[i];
                          final sel = _typeIndex == i;
                          return GestureDetector(
                            onTap: () => setState(() {
                              _typeIndex = i;
                              _selectedCatIndex = 0;
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: sel
                                    ? _kAccent
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.07)
                                        : cs.onSurface.withValues(alpha: 0.05)),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _kTypeIcons[t] ?? Broken.book,
                                    color: sel
                                        ? Colors.white
                                        : (isDark
                                            ? Colors.white54
                                            : cs.onSurface
                                                .withValues(alpha: 0.45)),
                                    size: 13,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    _typeLabel(t),
                                    style: TextStyle(
                                      color: sel
                                          ? Colors.white
                                          : (isDark
                                              ? Colors.white54
                                              : cs.onSurface
                                                  .withValues(alpha: 0.50)),
                                      fontSize: 13,
                                      fontWeight: sel
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // ── Actions: Search → Notifications → 3-dots ─────────
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. Search toggle
                      _iconBtn(
                        icon: Broken.search_normal_1,
                        onTap: _toggleSearch,
                        active: _showSearch,
                        tooltip: l10n.search,
                      ),
                      const SizedBox(width: 6),

                      // 2. Notifications
                      _iconBtn(
                        icon: Broken.notification,
                        onTap: () => context.push('/updates'),
                        tooltip: l10n.updates,
                      ),
                      const SizedBox(width: 6),

                      // 3. Three-dots menu
                      _buildThreeDotsBtn(context, l10n, mangaList),
                    ],
                  ),
                ],
              ),
            ),

            // ── Search bar (animated slide-in) ───────────────────────────
            ClipRect(
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                heightFactor: _showSearch ? 1.0 : 0.0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: _buildSearchBar(cs, isDark),
                ),
              ),
            ),

            // ── Category bar ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: _buildCategoryBar(context, cats, cs, isDark),
            ),

            const SizedBox(height: 8),

            // ── Library content ──────────────────────────────────────────
            Expanded(
              child: _currentType == ItemType.music
                  ? const MusicDiscoveryScreen()
                  : LibraryScreen(
                      key: ValueKey('lib_${_typeIndex}_$extCatId'),
                      itemType: _currentType,
                      presetInput: null,
                      hideOwnAppBar: true,
                      externalSearchQuery:
                          _showSearch ? _searchController.text : null,
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
    final focused = _searchFocus.hasFocus;
    final hasText = _searchController.text.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 46,
      decoration: BoxDecoration(
        color: focused
            ? (isDark ? cs.surfaceContainerHighest : cs.surface)
            : (isDark
                ? cs.surfaceContainerHigh
                : cs.surfaceContainerHigh),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: focused
              ? cs.primary.withValues(alpha: 0.50)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.06)
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
            color: focused
                ? cs.primary
                : cs.onSurface.withValues(alpha: 0.40),
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

          // Filter overlay button
          AdaptiveOverlayMenuButton(
            menuWidth: 250,
            trigger: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                Broken.slider_horizontal,
                size: 18,
                color: focused
                    ? cs.primary.withValues(alpha: 0.70)
                    : cs.onSurface.withValues(alpha: 0.38),
              ),
            ),
            contentBuilder: _buildFilterOverlayContent,
          ),

          const SizedBox(width: 2),
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
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // ── Manage categories — ghost icon pill ───────────────────────
          GestureDetector(
            onTap: () => _showManageCategories(context, cats),
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : cs.outline.withValues(alpha: 0.18),
                  width: 1,
                ),
              ),
              child: Icon(
                Broken.setting_2,
                size: 15,
                color: isDark
                    ? Colors.white38
                    : cs.onSurface.withValues(alpha: 0.38),
              ),
            ),
          ),

          // ── Subtle separator ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              width: 1,
              height: 18,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : cs.outline.withValues(alpha: 0.14),
            ),
          ),

          // ── "All" pill ────────────────────────────────────────────────
          _pill(
            label: 'All',
            selected: _selectedCatIndex == 0,
            onTap: () => setState(() => _selectedCatIndex = 0),
            cs: cs,
            isDark: isDark,
          ),

          // ── Category pills ────────────────────────────────────────────
          for (int i = 0; i < cats.length; i++)
            _pill(
              label: cats[i].name ?? '',
              selected: _selectedCatIndex == i + 1,
              onTap: () => setState(() => _selectedCatIndex = i + 1),
              cs: cs,
              isDark: isDark,
            ),
        ],
      ),
    );
  }

  Widget _pill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required ColorScheme cs,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? _kAccent
              : (isDark
                  ? Colors.white.withValues(alpha: 0.0)
                  : Colors.transparent),
          borderRadius: BorderRadius.circular(10),
          border: selected
              ? null
              : Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.0)
                      : Colors.transparent,
                ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? Colors.white
                : (isDark ? _kTextSecondary : cs.onSurface.withValues(alpha: 0.55)),
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 13,
          ),
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
      width: 34,
      height: 34,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : cs.onSurface.withValues(alpha: 0.06),
        ),
        child: ClipOval(
          child: ArrowPopupMenuButton<int>(
            icon: Icon(
              Broken.more_2,
              color: isDark ? Colors.white60 : cs.onSurface.withValues(alpha: 0.55),
              size: 17,
            ),
            padding: EdgeInsets.zero,
            menuWidth: 230,
            itemBuilder: (_) => [
              PopupMenuItem<int>(
                value: 1,
                child: Row(children: [
                  const Icon(Broken.refresh_left_square, size: 18),
                  const SizedBox(width: 12),
                  Text(l10n.update_library),
                ]),
              ),
              PopupMenuItem<int>(
                value: 2,
                child: Row(children: [
                  const Icon(Broken.shuffle, size: 18),
                  const SizedBox(width: 12),
                  Text(l10n.open_random_entry),
                ]),
              ),
              PopupMenuItem<int>(
                value: 3,
                child: Row(children: [
                  const Icon(Broken.folder_add, size: 18),
                  const SizedBox(width: 12),
                  Text(l10n.import),
                ]),
              ),
              if (_currentType == ItemType.anime)
                PopupMenuItem<int>(
                  value: 4,
                  child: Row(children: [
                    const Icon(Broken.video, size: 18),
                    const SizedBox(width: 12),
                    Text(l10n.torrent_stream),
                  ]),
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
              }
            },
          ),
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final catsAsync =
        ref.watch(getMangaCategorieStreamProvider(itemType: widget.itemType));
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, sc) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
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
                      color: _kAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Broken.tag,
                      color: _kAccent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manage Categories',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Remove tabs you no longer need.\nTitles stay in your library.',
                          style: TextStyle(
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
            Divider(
              color: cs.outline.withValues(alpha: 0.15),
              height: 20,
            ),
            // Category list + add field
            Expanded(
              child: catsAsync.when(
                data: (cats) => ListView(
                  controller: sc,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final cat in cats)
                      _CatRow(
                        cat: cat,
                        itemType: widget.itemType,
                        onDelete: () => _delete(cat),
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
                                contentPadding:
                                    const EdgeInsets.symmetric(
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
                              color: _kAccent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Broken.element_plus,
                              color: Colors.white,
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
                          backgroundColor:
                              cs.surfaceContainerHigh,
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

  const _CatRow({
    required this.cat,
    required this.itemType,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final count = ref
        .watch(
          getAllMangaStreamProvider(
              categoryId: cat.id, itemType: itemType),
        )
        .maybeWhen(data: (l) => l.length, orElse: () => 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
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
                const SizedBox(height: 2),
                Text(
                  '$count titles',
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.45),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onDelete,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _kAccent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Broken.trash,
                color: _kAccent,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
