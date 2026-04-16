import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/category.dart';
import 'package:watchtower/models/changed.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/more/categories/providers/isar_providers.dart';
import 'package:watchtower/modules/more/categories/providers/category_metadata_provider.dart';
import 'package:watchtower/modules/more/categories/widgets/custom_textfield.dart';
import 'package:watchtower/modules/more/settings/reader/providers/reader_state_provider.dart';
import 'package:watchtower/modules/more/settings/sync/providers/sync_providers.dart';
import 'package:watchtower/modules/widgets/progress_center.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/utils/item_type_filters.dart';
import 'package:watchtower/utils/item_type_localization.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

// ---------------------------------------------------------------------------
// Icon catalogue for the category icon picker
// ---------------------------------------------------------------------------
const _kCategoryIcons = <(String, IconData)>[
  ('label', Icons.label_outline_rounded),
  ('bookmark', Icons.bookmark_border),
  ('star', Icons.star_border),
  ('heart', Icons.favorite_border),
  ('play', Icons.play_circle_outline),
  ('movie', Icons.movie_outlined),
  ('tv', Icons.tv_outlined),
  ('book', Icons.menu_book_outlined),
  ('manga', Icons.auto_stories_outlined),
  ('folder', Icons.folder_outlined),
  ('history', Icons.history_outlined),
  ('trophy', Icons.emoji_events_outlined),
  ('fire', Icons.local_fire_department_outlined),
  ('lightning', Icons.bolt_outlined),
  ('music', Icons.music_note_outlined),
  ('game', Icons.sports_esports_outlined),
];

// ---------------------------------------------------------------------------
// Gradient palette for category banners (cycles by index)
// ---------------------------------------------------------------------------
const _kBannerGradients = <List<Color>>[
  [Color(0xFF7C3AED), Color(0xFF5B21B6)],
  [Color(0xFF2563EB), Color(0xFF1D4ED8)],
  [Color(0xFF0891B2), Color(0xFF0E7490)],
  [Color(0xFF059669), Color(0xFF047857)],
  [Color(0xFFD97706), Color(0xFFB45309)],
  [Color(0xFFDC2626), Color(0xFFB91C1C)],
  [Color(0xFFDB2777), Color(0xFFBE185D)],
  [Color(0xFF7C3AED), Color(0xFF4338CA)],
];

class CategoriesScreen extends ConsumerStatefulWidget {
  final (bool, int) data;
  const CategoriesScreen({required this.data, super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen>
    with TickerProviderStateMixin {
  late TabController _tabBarController;
  late final List<ItemType> _visibleTabTypes;
  @override
  void initState() {
    super.initState();
    _visibleTabTypes = hiddenItemTypes(ref.read(hideItemsStateProvider));
    _tabBarController = TabController(
      length: _visibleTabTypes.length,
      vsync: this,
    );
    _tabBarController.animateTo(widget.data.$2);
  }

  @override
  void dispose() {
    _tabBarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_visibleTabTypes.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.categories)),
        body: Center(child: Text("EMPTY\nMPTY\nMTY\nMT\n\n")),
      );
    }
    final l10n = l10nLocalizations(context)!;
    return DefaultTabController(
      animationDuration: Duration.zero,
      length: _visibleTabTypes.length,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text(
            widget.data.$1 ? l10n.edit_categories : l10n.categories,
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
          bottom: TabBar(
            indicatorSize: TabBarIndicatorSize.label,
            controller: _tabBarController,
            tabs: _visibleTabTypes.map((type) {
              return Tab(text: type.localized(l10n));
            }).toList(),
          ),
        ),
        body: TabBarView(
          controller: _tabBarController,
          children: _visibleTabTypes.map((type) {
            return CategoriesTab(itemType: type);
          }).toList(),
        ),
      ),
    );
  }
}

class CategoriesTab extends ConsumerStatefulWidget {
  final ItemType itemType;
  const CategoriesTab({required this.itemType, super.key});

  @override
  ConsumerState<CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends ConsumerState<CategoriesTab>
    with SingleTickerProviderStateMixin {
  List<Category> _entries = [];
  late AnimationController _swapAnimationController;
  int? _animatingFromIndex;
  int? _animatingToIndex;

  @override
  void initState() {
    super.initState();
    _swapAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _swapAnimationController.dispose();
    super.dispose();
  }

  final bool _isDesktop =
      Platform.isMacOS || Platform.isLinux || Platform.isWindows;

  /// Moves a category from `index` to `newIndex` in the list,
  /// swaps their positions in memory, and persists the change in Isar.
  Future<void> _moveCategory(int index, int newIndex) async {
    // Prevent invalid moves (out of bounds)
    if (newIndex < 0 || newIndex >= _entries.length) return;

    if (_isDesktop && mounted) {
      setState(() {
        _animatingFromIndex = index;
        _animatingToIndex = newIndex;
      });

      await _swapAnimationController.forward(from: 0.0);
    }

    // Grab the two category objects involved in the swap
    final a = _entries[index];
    final b = _entries[newIndex];
    // Swap their positions inside the in‑memory list
    _entries[newIndex] = a;
    _entries[index] = b;
    // Swap their persisted `pos` values so ordering is saved correctly
    final temp = a.pos;
    a.pos = b.pos;
    b.pos = temp;
    // Persist both updated objects in a single Isar transaction
    await isar.writeTxn(() async => isar.categorys.putAll([a, b]));

    if (mounted) {
      setState(() {
        _animatingFromIndex = null;
        _animatingToIndex = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = l10nLocalizations(context)!;
    final categories = ref.watch(
      getMangaCategorieStreamProvider(itemType: widget.itemType),
    );
    return Scaffold(
      body: categories.when(
        data: (data) {
          if (data.isEmpty) {
            _entries = [];
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  l10n.edit_categories_description,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          data.sort((a, b) => (a.pos ?? 0).compareTo(b.pos ?? 0));
          _entries = data;

          return SuperListView.builder(
            itemCount: _entries.length,
            padding: const EdgeInsets.only(bottom: 100),
            itemBuilder: (context, index) {
              final category = _entries[index];

              Widget itemWidget = _buildCategoryCard(context, category, index);

              if (_isDesktop &&
                  _animatingFromIndex != null &&
                  _animatingToIndex != null) {
                if (index == _animatingFromIndex ||
                    index == _animatingToIndex) {
                  final isMovingDown =
                      _animatingFromIndex! < _animatingToIndex!;
                  final offset = index == _animatingFromIndex
                      ? (isMovingDown ? 1.0 : -1.0)
                      : (isMovingDown ? -1.0 : 1.0);

                  itemWidget = AnimatedBuilder(
                    animation: _swapAnimationController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(
                          0,
                          offset * (1 - _swapAnimationController.value) * 80,
                        ),
                        child: child,
                      );
                    },
                    child: itemWidget,
                  );
                }
              }

              return itemWidget;
            },
          );
        },
        error: (Object error, StackTrace stackTrace) {
          _entries = [];
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                l10n.edit_categories_description,
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
        loading: () {
          return const ProgressCenter();
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCategoryDialog(context, l10n),
        label: Row(
          children: [
            const Icon(Icons.add),
            const SizedBox(width: 10),
            Text(l10n.add),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // ADD CATEGORY DIALOG (name + icon picker + description)
  // -------------------------------------------------------------------------
  void _showAddCategoryDialog(BuildContext context, dynamic l10n) {
    bool isExist = false;
    final nameController = TextEditingController();
    final descController = TextEditingController();
    int? selectedIconIndex;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            final selectedIcon = selectedIconIndex != null
                ? _kCategoryIcons[selectedIconIndex!].$2
                : Icons.label_outline_rounded;
            final gradients = _kBannerGradients[
              (_entries.length) % _kBannerGradients.length
            ];

            return AlertDialog(
              contentPadding: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── gradient banner preview ──────────────────────────
                  GestureDetector(
                    onTap: () => _showIconPickerSheet(ctx, (idx) {
                      setDlgState(() => selectedIconIndex = idx);
                    }),
                    child: Container(
                      height: 90,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradients,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(selectedIcon, size: 36, color: Colors.white),
                          const SizedBox(width: 12),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nameController.text.isEmpty
                                    ? 'Category Name'
                                    : nameController.text,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              if (descController.text.isNotEmpty)
                                Text(
                                  descController.text,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.edit_outlined,
                            color: Colors.white.withOpacity(0.6),
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // ── fields ────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomTextFormField(
                          controller: nameController,
                          entries: _entries,
                          context: ctx,
                          exist: (v) => setDlgState(() => isExist = v),
                          isExist: isExist,
                          val: (_) => setDlgState(() {}),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: descController,
                          maxLines: 2,
                          onChanged: (_) => setDlgState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Description (optional)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.cancel),
                ),
                TextButton(
                  onPressed: nameController.text.isEmpty || isExist
                      ? null
                      : () async {
                          final category = Category(
                            forItemType: widget.itemType,
                            name: nameController.text,
                            updatedAt: DateTime.now().millisecondsSinceEpoch,
                          );
                          isar.writeTxnSync(() {
                            isar.categorys.putSync(
                              category..pos = category.id,
                            );
                            final nullPosCats = isar.categorys
                                .filter()
                                .posIsNull()
                                .findAllSync();
                            for (var c in nullPosCats) {
                              isar.categorys.putSync(c..pos = c.id);
                            }
                          });
                          // Persist icon + description metadata
                          if (selectedIconIndex != null ||
                              descController.text.isNotEmpty) {
                            await ref
                                .read(categoryMetadataProvider.notifier)
                                .set(
                                  category.id!,
                                  CategoryMeta(
                                    iconCodePoint: selectedIconIndex != null
                                        ? _kCategoryIcons[selectedIconIndex!]
                                              .$2
                                              .codePoint
                                        : null,
                                    description: descController.text.isEmpty
                                        ? null
                                        : descController.text,
                                  ),
                                );
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                  child: Text(
                    l10n.add,
                    style: TextStyle(
                      color: nameController.text.isEmpty || isExist
                          ? Theme.of(ctx).primaryColor.withValues(alpha: 0.2)
                          : null,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showIconPickerSheet(
    BuildContext context,
    void Function(int index) onSelected,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose an icon',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 8,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: _kCategoryIcons.asMap().entries.map((e) {
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      onSelected(e.key);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          ctx,
                        ).colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        e.value.$2,
                        size: 22,
                        color: Theme.of(ctx).colorScheme.primary,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // CATEGORY CARD  (gradient banner + icon + description)
  // -------------------------------------------------------------------------
  Widget _buildCategoryCard(
    BuildContext context,
    Category category,
    int index,
  ) {
    final l10n = l10nLocalizations(context)!;
    final meta = ref.watch(categoryMetadataProvider)[category.id];
    final gradients = _kBannerGradients[index % _kBannerGradients.length];

    IconData cardIcon = Icons.label_outline_rounded;
    if (meta?.iconCodePoint != null) {
      // Resolve stored code point back to an IconData
      final match = _kCategoryIcons.where(
        (e) => e.$2.codePoint == meta!.iconCodePoint,
      );
      if (match.isNotEmpty) cardIcon = match.first.$2;
    }

    return Padding(
      key: Key('category_${category.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        child: Column(
          children: [
            // ── gradient banner header ─────────────────────────────────
            GestureDetector(
              onTap: () => _renameCategory(category),
              child: Container(
                width: double.infinity,
                height: 70,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradients,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(cardIcon, color: Colors.white, size: 26),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.name!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          if (meta?.description != null &&
                              meta!.description!.isNotEmpty)
                            Text(
                              meta.description!,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.78),
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.edit_outlined,
                      color: Colors.white.withOpacity(0.6),
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
            // ── action bar ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // reorder buttons
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_drop_up_outlined),
                        onPressed: index > 0
                            ? () => _moveCategory(index, index - 1)
                            : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_drop_down_outlined),
                        onPressed: index < _entries.length - 1
                            ? () => _moveCategory(index, index + 1)
                            : null,
                      ),
                    ],
                  ),
                  // action buttons
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => _renameCategory(category),
                        icon: const Icon(Icons.mode_edit_outline_outlined),
                        tooltip: l10n.rename_category,
                      ),
                      IconButton(
                        onPressed: () async {
                          await isar.writeTxn(() async {
                            category.shouldUpdate =
                                !(category.shouldUpdate ?? true);
                            category.updatedAt =
                                DateTime.now().millisecondsSinceEpoch;
                            isar.categorys.put(category);
                          });
                        },
                        icon: Icon(
                          category.shouldUpdate ?? true
                              ? Icons.update_outlined
                              : Icons.update_disabled_outlined,
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          await isar.writeTxn(() async {
                            category.hide = !(category.hide ?? false);
                            category.updatedAt =
                                DateTime.now().millisecondsSinceEpoch;
                            isar.categorys.put(category);
                          });
                        },
                        icon: Icon(
                          !(category.hide ?? false)
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return StatefulBuilder(
                                builder: (context, setState) {
                                  return AlertDialog(
                                    title: Text(l10n.delete_category),
                                    content: Text(
                                      l10n.delete_category_msg(category.name!),
                                    ),
                                    actions: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: Text(l10n.cancel),
                                          ),
                                          const SizedBox(width: 15),
                                          TextButton(
                                            onPressed: () async {
                                              await _removeCategory(
                                                category,
                                                context,
                                              );
                                            },
                                            child: Text(l10n.ok),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          );
                        },
                        icon: const Icon(Icons.delete_outlined),
                        tooltip: l10n.delete_category,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeCategory(Category category, BuildContext context) async {
    await isar.writeTxn(() async {
      // All Items with this category
      final allItems = await isar.mangas
          .filter()
          .categoriesElementEqualTo(category.id!)
          .findAll();
      // Remove the category ID from each item's category list
      final updatedItems = allItems.map((manga) {
        final cats = List<int>.from(manga.categories ?? []);
        cats.remove(category.id!);
        manga.categories = cats;
        return manga;
      }).toList();

      // Save updated items back to the database
      await isar.mangas.putAll(updatedItems);

      // Delete category
      await isar.categorys.delete(category.id!);
    });

    await ref
        .read(synchingProvider(syncId: 1).notifier)
        .addChangedPartAsync(
          ActionType.removeCategory,
          category.id,
          "{}",
          true,
        );
    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  void _renameCategory(Category category) {
    bool isExist = false;
    final controller = TextEditingController(text: category.name);
    bool isSameName = controller.text == category.name;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final l10n = l10nLocalizations(context);
            return AlertDialog(
              title: Text(l10n!.rename_category),
              content: CustomTextFormField(
                controller: controller,
                entries: _entries,
                context: context,
                exist: (value) {
                  setState(() {
                    isExist = value;
                  });
                },
                isExist: isExist,
                name: category.name!,
                val: (val) {
                  setState(() {
                    isSameName = controller.text == category.name;
                  });
                },
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text(l10n.cancel),
                    ),
                    const SizedBox(width: 15),
                    TextButton(
                      onPressed:
                          controller.text.isEmpty || isExist || isSameName
                          ? null
                          : () async {
                              await isar.writeTxn(() async {
                                category.name = controller.text;
                                category.updatedAt =
                                    DateTime.now().millisecondsSinceEpoch;
                                await isar.categorys.put(category);
                              });
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            },
                      child: Text(
                        l10n.ok,
                        style: TextStyle(
                          color:
                              controller.text.isEmpty || isExist || isSameName
                              ? Theme.of(
                                  context,
                                ).primaryColor.withValues(alpha: 0.2)
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}
