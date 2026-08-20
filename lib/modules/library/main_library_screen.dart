// ignore_for_file: use_build_context_synchronously

import 'dart:ui';
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
  late final PageController _arcPageCtrl = PageController(
    viewportFraction: 0.28,
    initialPage: _typeIndex,
  );

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
    _arcPageCtrl.dispose();
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

  // ── Arc carousel type selector ─────────────────────────────────────────────
  Widget _buildArcTypeSelector(ColorScheme cs, bool isDark) {
    return NotificationListener<ScrollNotification>(
      onNotification: (_) {
        final p = _arcPageCtrl.page;
        if (p != null) {
          final idx = p.round();
          if (idx != _typeIndex && idx >= 0 && idx < _kTypes.length) {
            setState(() => _typeIndex = idx);
          }
        }
        return false;
      },
      child: PageView.builder(
        controller: _arcPageCtrl,
        itemCount: _kTypes.length,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (i) => setState(() => _typeIndex = i),
        itemBuilder: (_, i) {
          final selected = i == _typeIndex;
          final diff = (i - _typeIndex).abs().toDouble();
          final scale = (1.0 - diff * 0.12).clamp(0.76, 1.0);
          final opacity = (1.0 - diff * 0.30).clamp(0.40, 1.0);
          final blur = diff > 0.5 ? (diff * 1.8).clamp(0.0, 2.5) : 0.0;

          return Center(
            child: AnimatedScale(
              scale: scale,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: opacity,
                duration: const Duration(milliseconds: 220),
                child: ImageFiltered(
                  imageFilter: blur > 0
                      ? ImageFilter.blur(sigmaX: blur, sigmaY: blur)
                      : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                  child: GestureDetector(
                    onTap: () {
                      _arcPageCtrl.animateToPage(
                        i,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                      );
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Arc + icon
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: selected ? 42 : 36,
                          height: selected ? 42 : 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: selected
                                ? LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      cs.primary,
                                      cs.primary.withValues(alpha: 0.75),
                                    ],
                                  )
                                : null,
                            color: selected
                                ? null
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : cs.onSurface.withValues(alpha: 0.06)),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color: cs.primary.withValues(alpha: 0.35),
                                      blurRadius: 14,
                                      spreadRadius: -2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            _kTypeIcons[_kTypes[i]]!,
                            color: selected
                                ? Colors.white
                                : (isDark
                                    ? Colors.white54
                                    : cs.onSurface.withValues(alpha: 0.50)),
                            size: selected ? 20 : 17,
                          ),
                        ),
                        const SizedBox(height: 3),
                        // Label
                        Text(
                          _typeLabel(_kTypes[i]),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                            color: selected
                                ? cs.primary
                                : (isDark ? _kTextSecondary : cs.onSurface.withValues(alpha: 0.45)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
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
                ? cs.primary.withValues(alpha: 0.90)
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
            // ── Row 1: arc type selector + action icons ────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Row(
                children: [
                  // ── Arc carousel type selector ─────────────────────────
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: _buildArcTypeSelector(cs, isDark),
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
                Broken.filter,
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
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? cs.primary.withValues(alpha: 0.60)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : cs.outline.withValues(alpha: 0.25)),
            width: selected ? 1.2 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? cs.primary
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
              const PopupMenuItem<int>(
                enabled: false,
                value: 99,
                child: Divider(height: 1, indent: 0, endIndent: 0),
              ),
              PopupMenuItem<int>(
                value: 10,
                child: Row(children: [
                  const Icon(Broken.filter, size: 18),
                  const SizedBox(width: 12),
                  Text(l10n.filter),
                ]),
              ),
              PopupMenuItem<int>(
                value: 11,
                child: Row(children: [
                  const Icon(Broken.arrow_up_2, size: 18),
                  const SizedBox(width: 12),
                  Text(l10n.sort),
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
                case 10:
                case 11:
                  _showFilterSheet(context);
                  break;
              }
            },
          ),
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    if (_cachedSettings == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        itemType: _currentType,
        settings: _cachedSettings!,
        entries: _cachedMangaList,
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
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 14.5,
                        ),
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
                      children: [
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
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            color: Colors.white,
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
                      color: cs.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Broken.tag,
                      color: cs.primary,
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
                              color: cs.primary,
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
  final VoidCallback? onEdit;

  const _CatRow({
    required this.cat,
    required this.itemType,
    required this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final count = ref
        .watch(
          getAllMangaStreamProvider(
              categoryId: cat.id, itemType: itemType),
        )
        .maybeWhen(data: (l) => l.length, orElse: () => 0);
    final totalCountAsync = ref.watch(
      getAllMangaStreamProvider(categoryId: null, itemType: itemType),
    );
    final totalCount = totalCountAsync.maybeWhen(data: (l) => l.length, orElse: () => 1);
    final percent = totalCount > 0 ? ((count / totalCount) * 100).round() : 0;

    // Reading count: items in category where isRead == false
    final readingCount = ref
        .watch(
          getAllMangaStreamProvider(categoryId: cat.id, itemType: itemType),
        )
        .maybeWhen(data: (l) => l.where((m) => m.lastRead == null || m.lastRead == 0).length, orElse: () => 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
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
                      child: Icon(
                        Broken.tag,
                        size: 17,
                        color: cs.primary,
                      ),
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
                                '$count items · $percent%',
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
                      label: '$count entries',
                      cs: cs,
                    ),
                    const SizedBox(width: 8),
                    _statChip(
                      icon: Broken.eye,
                      label: '$readingCount reading',
                      cs: cs,
                    ),
                    const SizedBox(width: 8),
                    _statChip(
                      icon: Broken.chart_2,
                      label: '$percent%',
                      cs: cs,
                    ),
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

// ─── Filter bottom sheet (from 3-dots menu) ──────────────────────────────────
class _FilterSheet extends ConsumerStatefulWidget {
  final ItemType itemType;
  final Settings settings;
  final List<Manga> entries;

  const _FilterSheet({
    required this.itemType,
    required this.settings,
    required this.entries,
  });

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = l10nLocalizations(context)!;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.85,
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
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Broken.filter, color: cs.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.filter,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  // Reset
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        l10n.sort,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: cs.outline.withValues(alpha: 0.15), height: 20),
            Expanded(
              child: ListView(
                controller: sc,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // Downloaded toggle
                  _filterToggle(
                    icon: Broken.import,
                    label: l10n.downloaded,
                    cs: cs,
                  ),
                  // Tracking toggle
                  _filterToggle(
                    icon: Broken.chart_2,
                    label: l10n.tracking,
                    cs: cs,
                  ),
                  // Unread toggle
                  _filterToggle(
                    icon: Broken.eye_slash,
                    label: l10n.unread,
                    cs: cs,
                  ),
                  // Completed toggle
                  _filterToggle(
                    icon: Broken.tick_circle,
                    label: l10n.completed,
                    cs: cs,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        backgroundColor: cs.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Apply',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterToggle({
    required IconData icon,
    required String label,
    required ColorScheme cs,
  }) {
    bool enabled = false;
    return StatefulBuilder(
      builder: (context, setLocal) => GestureDetector(
        onTap: () => setLocal(() => enabled = !enabled),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: enabled
                ? cs.primary.withValues(alpha: 0.10)
                : cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enabled
                  ? cs.primary.withValues(alpha: 0.35)
                  : cs.outline.withValues(alpha: 0.10),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: enabled ? cs.primary : cs.onSurface.withValues(alpha: 0.45)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: enabled ? cs.primary : cs.onSurface,
                  ),
                ),
              ),
              Icon(
                enabled ? Broken.eye : Broken.eye_slash,
                size: 16,
                color: enabled ? cs.primary : cs.onSurface.withValues(alpha: 0.25),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
