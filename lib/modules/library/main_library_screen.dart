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
  import 'package:watchtower/modules/music/music_discovery_screen.dart';
import 'package:watchtower/modules/library/providers/isar_providers.dart';
import 'package:watchtower/modules/library/widgets/library_dialogs.dart';
import 'package:watchtower/modules/library/widgets/library_settings_sheet.dart';
import 'package:watchtower/modules/manga/detail/providers/state_providers.dart';
import 'package:watchtower/modules/widgets/manga_image_card_widget.dart';
import 'package:watchtower/modules/more/categories/providers/isar_providers.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/services/library_updater.dart';
import 'package:watchtower/utils/arrow_popup_menu.dart';
import 'package:watchtower/utils/global_style.dart';

// ─── Design tokens ──────────────────────────────────────────────────────────
// NOTE: _kBg removed — background now inherits from the app theme so the
// screen blends with the surrounding interface instead of forcing a hard black.
const _kBorder        = Color(0xFF333333);
const _kAccent        = Color(0xFFE91E63);
const _kTextSecondary = Color(0xFF999999);

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

  // ── Ghost icon button — smaller, no heavy border ───────────────────────────
  Widget _iconBtn({
    required IconData icon,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active
              ? _kAccent.withValues(alpha: 0.90)
              : Colors.white.withValues(alpha: 0.07),
        ),
        child: Icon(
          icon,
          color: active ? Colors.white : Colors.white60,
          size: 16,
        ),
      ),
    );
  }

  // ── Compact chevron button ─────────────────────────────────────────────────
  Widget _chevronBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, color: Colors.white38, size: 14),
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
    final cs   = Theme.of(context).colorScheme;

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
    final cats      = catsAsync.maybeWhen(data: (c) => c, orElse: () => <Category>[]);

    final int? selectedCatId = _selectedCatIndex == 0
        ? null
        : (cats.length >= _selectedCatIndex ? cats[_selectedCatIndex - 1].id : null);
    final int extCatId = selectedCatId == null ? -1 : selectedCatId;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1 : type selector + action icons ─────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Row(
                children: [
                  // ── Left : sub-dock type pills ──────────────────────────
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
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: sel ? _kAccent : Colors.white.withValues(alpha: 0.07),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _kTypeIcons[t] ?? Icons.library_books_rounded,
                                      color: sel ? Colors.white : Colors.white54,
                                      size: 13,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      _typeLabel(t),
                                      style: TextStyle(
                                        color: sel ? Colors.white : Colors.white54,
                                        fontSize: 13,
                                        fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
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

                  // ── Right : action icons — smaller, lighter ─────────────────
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _iconBtn(
                        icon: Icons.search,
                        onTap: _toggleSearch,
                        active: _showSearch,
                      ),
                      const SizedBox(width: 5),
                      _iconBtn(
                        icon: Icons.download_outlined,
                        onTap: () {},
                      ),
                      const SizedBox(width: 5),
                      _buildThreeDotsBtn(context, l10n, mangaList),
                      const SizedBox(width: 5),
                      _iconBtn(
                        icon: Icons.notifications_outlined,
                        onTap: () => context.push('/updates'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Search bar ───────────────────────────────────────────────────
            ClipRect(
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                heightFactor: _showSearch ? 1.0 : 0.0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(21),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        Icon(Icons.search, color: cs.onSurfaceVariant, size: 17),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            autofocus: _showSearch,
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search library',
                              hintStyle: TextStyle(color: cs.onSurfaceVariant),
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
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Icon(
                                Icons.close,
                                color: cs.onSurfaceVariant,
                                size: 16,
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

            // ── Row 2 : filter / category bar ────────────────────────────────
            // "Manage" is its own separate pill bubble — distinct from "All".
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: _buildFilterBar(context, cats),
            ),

            const SizedBox(height: 8),

            // ── Library content ─────────────────────────────────────────────
              Expanded(
                child: _currentType == ItemType.music
                    ? const MusicDiscoveryScreen()
                    : LibraryScreen(
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
  // ── 3-dot popup — same size as other icon buttons ─────────────────────────
  Widget _buildThreeDotsBtn(
    BuildContext context,
    dynamic l10n,
    List<Manga> mangaList,
  ) {
    return SizedBox(
      width: 32,
      height: 32,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.07),
        ),
        child: ClipOval(
          child: ArrowPopupMenuButton<int>(
            icon: const Icon(Icons.more_horiz, color: Colors.white60, size: 16),
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
      ),
    );
  }

  // ── Filter bar : 2 distinct pill bubbles ─────────────────────────────────
  //
  //  [ ⚙ ]   [ All  Cat1  Cat2 … ]
  //   └─ manage bubble (separate)   └─ categories scrollable bubble
  //
  Widget _buildFilterBar(BuildContext context, List<Category> cats) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        // ── Bubble 1 : "Manage" — standalone, left ───────────────────────────
        GestureDetector(
          onTap: () => _showManageCategories(context, cats),
          child: Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.10),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: Colors.white54,
              size: 17,
            ),
          ),
        ),

        const SizedBox(width: 8),

        // ── Bubble 2 : "All" + categories — scrollable pill row ──────────────
        Expanded(
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.09),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    _pill(
                      label: 'All',
                      selected: _selectedCatIndex == 0,
                      onTap: () => setState(() => _selectedCatIndex = 0),
                      cs: cs,
                    ),
                    for (int i = 0; i < cats.length; i++)
                      _pill(
                        label: cats[i].name ?? '',
                        selected: _selectedCatIndex == i + 1,
                        onTap: () => setState(() => _selectedCatIndex = i + 1),
                        cs: cs,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _pill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required ColorScheme cs,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? _kAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _kTextSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 13,
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
