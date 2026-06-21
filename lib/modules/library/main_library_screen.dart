// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/category.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/library/library_screen.dart';
import 'package:watchtower/modules/library/providers/isar_providers.dart';
import 'package:watchtower/modules/more/categories/providers/isar_providers.dart';

// ─── Design tokens ─────────────────────────────────────────────────────────
const _kBg = Color(0xFF0A0A0A);
const _kBorder = Color(0xFF333333);
const _kAccent = Color(0xFFE91E63);
const _kTextPrimary = Color(0xFFFFFFFF);
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

class _MainLibraryScreenState extends ConsumerState<MainLibraryScreen> {
  int _typeIndex = 0;
  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();
  int _selectedCatIndex = 0; // 0 = All

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

  @override
  Widget build(BuildContext context) {
    final catsAsync = ref.watch(
      getMangaCategorieStreamProvider(itemType: _currentType),
    );
    final cats = catsAsync.maybeWhen(data: (c) => c, orElse: () => <Category>[]);

    // Determine effective category id (null = All)
    final int? selectedCatId = _selectedCatIndex == 0
        ? null
        : (cats.length >= _selectedCatIndex ? cats[_selectedCatIndex - 1].id : null);
    // Sentinel -1 means All for LibraryScreen
    final int extCatId = selectedCatId == null ? -1 : selectedCatId;

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  // Type selector with swipe + arrows
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
                          GestureDetector(
                            onTap: () => _changeType(-1),
                            child: const Icon(
                              Icons.chevron_left_rounded,
                              color: Colors.white38,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 2),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, anim) {
                              return FadeTransition(opacity: anim, child: child);
                            },
                            child: Text(
                              _typeLabel(_currentType),
                              key: ValueKey(_typeIndex),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: _kTextPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          GestureDetector(
                            onTap: () => _changeType(1),
                            child: const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white38,
                              size: 30,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Action buttons
                  Row(
                    children: [
                      _circleBtn(
                        icon: Icons.search,
                        onTap: _toggleSearch,
                        active: _showSearch,
                      ),
                      const SizedBox(width: 8),
                      _circleBtn(
                        icon: Icons.download_outlined,
                        onTap: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Animated search bar ───────────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: _showSearch
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                                autofocus: true,
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
                            if (_searchController.text.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Icon(Icons.close, color: Colors.grey, size: 18),
                                ),
                              ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            // ── Filter bar ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _buildFilterBar(context, cats),
            ),

            const SizedBox(height: 8),

            // ── Library content (scrolls under filter bar) ─────────────
            Expanded(
              child: LibraryScreen(
                key: ValueKey('lib_' + _typeIndex.toString() + '_' + extCatId.toString()),
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
          // Wrench button → Manage Categories
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
          // Vertical divider
          Container(width: 1, height: 26, color: _kBorder),
          // Category pills
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  _pill(label: 'All', selected: _selectedCatIndex == 0,
                      onTap: () => setState(() => _selectedCatIndex = 0)),
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
        duration: const Duration(milliseconds: 180),
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

// ─── Manage Categories Sheet ─────────────────────────────────────────────────
class _ManageCategoriesSheet extends ConsumerStatefulWidget {
  final ItemType itemType;
  const _ManageCategoriesSheet({required this.itemType});
  @override
  ConsumerState<_ManageCategoriesSheet> createState() => _ManageCategoriesSheetState();
}

class _ManageCategoriesSheetState extends ConsumerState<_ManageCategoriesSheet> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

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
    final catsAsync = ref.watch(
      getMangaCategorieStreamProvider(itemType: widget.itemType),
    );
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
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: _kAccent.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.label_rounded, color: _kAccent, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Manage Categories',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                        SizedBox(height: 3),
                        Text('Remove tabs you no longer need.\nTitles stay in your library.',
                            style: TextStyle(color: Colors.grey, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.close, color: Colors.white70, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF2D2D2D), height: 20),
            // List
            Expanded(
              child: catsAsync.when(
                data: (cats) => ListView(
                  controller: sc,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final cat in cats)
                      _CatRow(cat: cat, itemType: widget.itemType, onDelete: () => _delete(cat)),
                    const SizedBox(height: 16),
                    // Add field
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              color: const Color(0xFF252525),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF3D3D3D)),
                            ),
                            child: TextField(
                              controller: _ctrl,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: const InputDecoration(
                                hintText: 'New category name',
                                hintStyle: TextStyle(color: Colors.grey),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () => _add(cats),
                          child: Container(
                            width: 46, height: 46,
                            decoration: BoxDecoration(
                              color: const Color(0xFF3D3D3D),
                              borderRadius: BorderRadius.circular(23),
                            ),
                            child: const Icon(Icons.add, color: Colors.white, size: 22),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Done
                    SizedBox(
                      width: double.infinity, height: 50,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFF252525),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Done',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e',
                    style: const TextStyle(color: Colors.red))),
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
  const _CatRow({required this.cat, required this.itemType, required this.onDelete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref
        .watch(getAllMangaStreamProvider(categoryId: cat.id, itemType: itemType))
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
                Text(cat.name ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('$count titles',
                    style: const TextStyle(color: Colors.grey, fontSize: 12.5)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onDelete,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _kAccent.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded, color: _kAccent, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}