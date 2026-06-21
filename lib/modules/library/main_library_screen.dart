// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/category.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/modules/library/library_screen.dart';
import 'package:watchtower/modules/library/providers/isar_providers.dart';
import 'package:watchtower/modules/library/widgets/library_dialogs.dart';
import 'package:watchtower/modules/library/widgets/library_settings_sheet.dart';
import 'package:watchtower/modules/manga/detail/providers/state_providers.dart';
import 'package:watchtower/modules/more/categories/providers/isar_providers.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/services/library_updater.dart';
import 'package:watchtower/utils/arrow_popup_menu.dart';
import 'package:watchtower/utils/global_style.dart';

// ─── Design tokens ──────────────────────────────────────────────────────────
const _kBg            = Color(0xFF0A0A0A);
const _kBorder        = Color(0xFF333333);
const _kAccent        = Color(0xFFE91E63);
const _kTextPrimary   = Color(0xFFFFFFFF);
const _kTextSecondary = Color(0xFF999999);
const _kSurfaceMedium = Color(0xFF2D2D2D);

// ─── Type order ─────────────────────────────────────────────────────────────
const _kTypes = <ItemType>[
  ItemType.anime,
  ItemType.manga,
  ItemType.novel,
  ItemType.music,
  ItemType.game,
];

// ─── Type icons ─────────────────────────────────────────────────────────────
const _kTypeIcons = <ItemType, IconData>{
  ItemType.anime: Icons.tv_rounded,
  ItemType.manga: Icons.menu_book_rounded,
  ItemType.novel: Icons.article_rounded,
  ItemType.music: Icons.music_note_rounded,
  ItemType.game:  Icons.sports_esports_rounded,
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

// ─── Main screen ─────────────────────────────────────────────────────────────
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
  int _selectedCatIndex = 0;
  Settings? _cachedSettings;

  @override
  void initState() {
    super.initState();
    if (widget.presetInput != null && widget.presetInput!.isNotEmpty) {
      _showSearch = true;
      _searchController.text = widget.presetInput!;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  ItemType get _currentType => _kTypes[_typeIndex];

  void _changeType(int delta) {
    setState(() {
      _typeIndex = (_typeIndex + delta + _kTypes.length) % _kTypes.length;
      _selectedCatIndex = 0;
    });
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) _searchController.clear();
    });
  }

  // ── Circular icon button ───────────────────────────────────────────────────
  Widget _circleBtn({
    required IconData icon,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? _kAccent : Colors.transparent,
          border: active ? null : Border.all(color: _kBorder, width: 1.5),
        ),
        child: Icon(
          icon,
          color: active ? Colors.white : Colors.white70,
          size: 20,
        ),
      ),
    );
  }

  // ── Pro chevron button with subtle card background ─────────────────────────
  Widget _chevronBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0xFF2E2E2E), width: 1),
        ),
        child: Icon(icon, color: Colors.white54, size: 17),
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

  @override
  Widget build(BuildContext context) {
    final l10n = l10nLocalizations(context)!;

    final settingsAsync = ref.watch(getSettingsStreamProvider);
    final mangaAsync    = ref.watch(
      getAllMangaStreamProvider(categoryId: null, itemType: _currentType),
    );
    final catsAsync = ref.watch(
      getMangaCategorieStreamProvider(itemType: _currentType),
    );

    // Safe settings access compatible with all Riverpod 2.x versions
    final settingsList = settingsAsync.asData?.value ?? <Settings>[];
    final settings     = settingsList.isNotEmpty ? settingsList.first : null;
    if (settings != null) _cachedSettings = settings;

    final mangaList = mangaAsync.asData?.value ?? <Manga>[];
    final cats      = catsAsync.maybeWhen(data: (c) => c, orElse: () => <Category>[]);

    final int? selectedCatId = _selectedCatIndex == 0
        ? null
        : (cats.length >= _selectedCatIndex ? cats[_selectedCatIndex - 1].id : null);
    final int extCatId = selectedCatId == null ? -1 : selectedCatId;

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  // Type selector with swipe support
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragEnd: (d) {
                        final v = d.primaryVelocity ?? 0;
                        if (v < -200) _changeType(1);
                        else if (v > 200) _changeType(-1);
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _chevronBtn(
                            Icons.chevron_left_rounded,
                            () => _changeType(-1),
                          ),
                          const SizedBox(width: 10),
                          // Animated icon + label
                          Flexible(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              transitionBuilder: (child, anim) =>
                                  FadeTransition(opacity: anim, child: child),
                              child: Row(
                                key: ValueKey(_typeIndex),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Type icon badge
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: _kAccent.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      _kTypeIcons[_currentType] ??
                                          Icons.library_books_rounded,
                                      color: _kAccent,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _typeLabel(_currentType),
                                    style: const TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w800,
                                      color: _kTextPrimary,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _chevronBtn(
                            Icons.chevron_right_rounded,
                            () => _changeType(1),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // ── Action buttons ─────────────────────────────────────────
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Search
                      _circleBtn(
                        icon: Icons.search,
                        onTap: _toggleSearch,
                        active: _showSearch,
                      ),
                      const SizedBox(width: 8),
                      // Download queue
                      _circleBtn(
                        icon: Icons.download_outlined,
                        onTap: () {},
                      ),
                      const SizedBox(width: 8),
                      // ── Horizontal 3-dot popup ─────────────────────────────
                      _buildThreeDotsBtn(context, l10n, mangaList),
                      const SizedBox(width: 8),
                      // ── Notification bell → Updates ────────────────────────
                      _circleBtn(
                        icon: Icons.notifications_outlined,
                        onTap: () => context.push('/updates'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Search bar — fast, smooth, no jank ──────────────────────────
            ClipRect(
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                heightFactor: _showSearch ? 1.0 : 0.0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: _kSurfaceMedium,
                      borderRadius: BorderRadius.circular(23),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 14),
                        const Icon(Icons.search, color: Colors.grey, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            autofocus: _showSearch,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Search library',
                              hintStyle: TextStyle(color: Colors.grey),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 100),
                          opacity: _searchController.text.isNotEmpty ? 1.0 : 0.0,
                          child: GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() {});
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Icon(
                                Icons.close,
                                color: Colors.grey,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Filter / category bar ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _buildFilterBar(context, cats),
            ),

            const SizedBox(height: 8),

            // ── Library content ──────────────────────────────────────────────
            Expanded(
              child: LibraryScreen(
                key: ValueKey('lib_${_typeIndex}_$extCatId'),
                itemType: _currentType,
                presetInput: null,
                hideOwnAppBar: true,
                externalSearchQuery: _showSearch ? _searchController.text : null,
                externalCategoryId: extCatId,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build 3-dot horizontal popup ─────────────────────────────────────────
  Widget _buildThreeDotsBtn(
    BuildContext context,
    dynamic l10n,
    List<Manga> mangaList,
  ) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _kBorder, width: 1.5),
      ),
      child: ClipOval(
        child: ArrowPopupMenuButton<int>(
          icon: const Icon(Icons.more_horiz, color: Colors.white70, size: 20),
          padding: EdgeInsets.zero,
          menuWidth: 230,
          itemBuilder: (_) => [
            PopupMenuItem<int>(
              value: 0,
              child: Row(children: [
                const Icon(Icons.filter_list_sharp, size: 18),
                const SizedBox(width: 12),
                Text(l10n.filter),
              ]),
            ),
            const PopupMenuDivider(),
            PopupMenuItem<int>(
              value: 1,
              child: Row(children: [
                const Icon(Icons.refresh_rounded, size: 18),
                const SizedBox(width: 12),
                Text(l10n.update_library),
              ]),
            ),
            PopupMenuItem<int>(
              value: 2,
              child: Row(children: [
                const Icon(Icons.shuffle_rounded, size: 18),
                const SizedBox(width: 12),
                Text(l10n.open_random_entry),
              ]),
            ),
            PopupMenuItem<int>(
              value: 3,
              child: Row(children: [
                const Icon(Icons.archive_outlined, size: 18),
                const SizedBox(width: 12),
                Text(l10n.import),
              ]),
            ),
            if (_currentType == ItemType.anime)
              PopupMenuItem<int>(
                value: 4,
                child: Row(children: [
                  const Icon(Icons.stream_rounded, size: 18),
                  const SizedBox(width: 12),
                  Text(l10n.torrent_stream),
                ]),
              ),
          ],
          onSelected: (v) {
            switch (v) {
              case 0:
                if (_cachedSettings != null) {
                  showLibrarySettingsSheet(
                    context: context,
                    vsync: this,
                    settings: _cachedSettings!,
                    itemType: _currentType,
                    entries: mangaList,
                  );
                }
                break;
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
    );
  }

  Widget _buildFilterBar(BuildContext context, List<Category> cats) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: _kBorder, width: 1.2),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _showManageCategories(context, cats),
            child: const SizedBox(
              width: 46,
              height: 46,
              child: Icon(
                Icons.handyman_outlined,
                color: Colors.white70,
                size: 20,
              ),
            ),
          ),
          Container(width: 1, height: 26, color: _kBorder),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  _pill(
                    label: 'All',
                    selected: _selectedCatIndex == 0,
                    onTap: () => setState(() => _selectedCatIndex = 0),
                  ),
                  for (int i = 0; i < cats.length; i++)
                    _pill(
                      label: cats[i].name ?? '',
                      selected: _selectedCatIndex == i + 1,
                      onTap: () => setState(() => _selectedCatIndex = i + 1),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? _kAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _kTextSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13.5,
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
    final catsAsync =
        ref.watch(getMangaCategorieStreamProvider(itemType: widget.itemType));
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, sc) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _kAccent.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.label_rounded,
                      color: _kAccent,
                      size: 24,
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
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Remove tabs you no longer need.\nTitles stay in your library.',
                          style: TextStyle(color: Colors.grey, fontSize: 12.5),
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
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF2D2D2D), height: 20),
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
                              color: const Color(0xFF252525),
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: const Color(0xFF3D3D3D)),
                            ),
                            child: TextField(
                              controller: _ctrl,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'New category name',
                                hintStyle: TextStyle(color: Colors.grey),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
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
                              color: const Color(0xFF3D3D3D),
                              borderRadius: BorderRadius.circular(23),
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFF252525),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Done',
                          style: TextStyle(
                            color: Colors.white,
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

// ─── Category row ─────────────────────────────────────────────────────────────
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
    final count = ref
        .watch(
          getAllMangaStreamProvider(categoryId: cat.id, itemType: itemType),
        )
        .maybeWhen(data: (l) => l.length, orElse: () => 0);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count titles',
                  style: const TextStyle(color: Colors.grey, fontSize: 12.5),
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
                color: _kAccent.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: _kAccent,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
