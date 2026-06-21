import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:watchtower/models/manga.dart';
  import 'package:watchtower/models/settings.dart';
  import 'package:watchtower/modules/library/library_screen.dart';
  import 'package:watchtower/modules/library/providers/isar_providers.dart';
  import 'package:watchtower/modules/library/widgets/library_dialogs.dart';
  import 'package:watchtower/modules/library/widgets/library_settings_sheet.dart';
  import 'package:watchtower/modules/library/widgets/search_text_form_field.dart';
  import 'package:watchtower/modules/widgets/manga_image_card_widget.dart';
  import 'package:watchtower/providers/l10n_providers.dart';
  import 'package:watchtower/services/library_updater.dart';
  import 'package:watchtower/utils/arrow_popup_menu.dart';
  import 'package:watchtower/utils/extensions/build_context_extensions.dart';
  import 'package:watchtower/utils/global_style.dart';

  class MainLibraryScreen extends ConsumerStatefulWidget {
    const MainLibraryScreen({super.key, this.presetInput, this.initialType});

    final String? presetInput;
    final ItemType? initialType;

    @override
    ConsumerState<MainLibraryScreen> createState() => _MainLibraryScreenState();
  }

  class _MainLibraryScreenState extends ConsumerState<MainLibraryScreen>
      with TickerProviderStateMixin {
    late TextEditingController _searchController;
    bool _isSearch = false;

    static const _types = [
      ItemType.anime,
      ItemType.manga,
      ItemType.novel,
      ItemType.music,
      ItemType.game,
    ];

    late ItemType _currentType;

    @override
    void initState() {
      super.initState();
      _currentType = widget.initialType ?? ItemType.anime;
      _searchController = TextEditingController(text: widget.presetInput ?? '');
      if (widget.presetInput != null && widget.presetInput!.isNotEmpty) {
        _isSearch = true;
      }
      _searchController.addListener(() => setState(() {}));
    }

    @override
    void dispose() {
      _searchController.dispose();
      super.dispose();
    }

    IconData _typeIcon(ItemType t) {
      switch (t) {
        case ItemType.anime:
          return Icons.live_tv_outlined;
        case ItemType.manga:
          return Icons.auto_stories_outlined;
        case ItemType.novel:
          return Icons.local_library_outlined;
        case ItemType.music:
          return Icons.music_note_outlined;
        case ItemType.game:
          return Icons.sports_esports_outlined;
        default:
          return Icons.collections_bookmark_outlined;
      }
    }

    String _typeLabel(ItemType t, dynamic l10n) {
      switch (t) {
        case ItemType.anime:
          return l10n.watch;
        case ItemType.manga:
          return l10n.manga;
        case ItemType.novel:
          return l10n.novel;
        case ItemType.music:
          return 'Music';
        case ItemType.game:
          return 'Games';
        default:
          return l10n.library;
      }
    }

    void _showTypePicker(BuildContext context, dynamic l10n, ThemeData theme) {
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          final cs = theme.colorScheme;
          final isDark = theme.brightness == Brightness.dark;
          return Container(
            margin: EdgeInsets.fromLTRB(
              12, 0, 12, 12 + MediaQuery.of(ctx).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.black.withValues(alpha: 0.07),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                ..._types.map((t) {
                  final isSelected = t == _currentType;
                  return InkWell(
                    onTap: () {
                      setState(() => _currentType = t);
                      Navigator.pop(ctx);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      child: Row(
                        children: [
                          Icon(
                            _typeIcon(t),
                            size: 22,
                            color: isSelected
                                ? cs.primary
                                : cs.onSurface.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            _typeLabel(t, l10n),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? cs.primary
                                  : cs.onSurface.withValues(alpha: 0.85),
                            ),
                          ),
                          if (isSelected) ...[
                            const Spacer(),
                            Icon(Icons.check_rounded,
                                size: 18, color: cs.primary),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      );
    }

    void _openFilterSheet(Settings settings) {
      final mangaAsync = ref.read(
        getAllMangaStreamProvider(categoryId: null, itemType: _currentType),
      );
      final entries = mangaAsync.when(
        data: (v) => v,
        loading: () => <Manga>[],
        error: (_, __) => <Manga>[],
      );
      showLibrarySettingsSheet(
        context: context,
        vsync: this,
        settings: settings,
        itemType: _currentType,
        entries: entries,
      );
    }

    @override
    Widget build(BuildContext context) {
      final settingsStream = ref.watch(getSettingsStreamProvider);
      return settingsStream.when(
        data: (settingsList) => _buildBody(settingsList.first),
        loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator())),
        error: (e, _) =>
            Scaffold(body: Center(child: Text(e.toString()))),
      );
    }

    Widget _buildBody(Settings settings) {
      final l10n = context.l10n;
      final theme = Theme.of(context);

      return Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: _isSearch
              ? null
              : GestureDetector(
                  onTap: () => _showTypePicker(context, l10n, theme),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _typeIcon(_currentType),
                        size: 22,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _typeLabel(_currentType, l10n),
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: theme.colorScheme.primary.withValues(alpha: 0.7),
                        size: 20,
                      ),
                    ],
                  ),
                ),
          actions: [
            if (_isSearch)
              SeachFormTextField(
                onChanged: (_) => setState(() {}),
                onSuffixPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
                onPressed: () {
                  setState(() {
                    _isSearch = false;
                    _searchController.clear();
                  });
                },
                controller: _searchController,
              )
            else ...[
              IconButton(
                tooltip: l10n.search,
                splashRadius: 20,
                onPressed: () => setState(() => _isSearch = true),
                icon: Icon(
                  Icons.search_rounded,
                  color: theme.hintColor,
                ),
              ),
              // Download / Update library
              IconButton(
                tooltip: l10n.update_library,
                splashRadius: 20,
                onPressed: () {
                  final mangaAsync = ref.read(
                    getAllMangaStreamProvider(
                      categoryId: null,
                      itemType: _currentType,
                    ),
                  );
                  mangaAsync.whenData((list) {
                    updateLibrary(
                      ref: ref,
                      context: context,
                      mangaList: list,
                      itemType: _currentType,
                    );
                  });
                },
                icon: Icon(
                  Icons.download_rounded,
                  color: theme.hintColor,
                ),
              ),
              // Filter / Sort / Display
              IconButton(
                tooltip: 'Filter / Sort / Display',
                splashRadius: 20,
                onPressed: () => _openFilterSheet(settings),
                icon: Icon(
                  Icons.filter_list_sharp,
                  color: theme.hintColor,
                ),
              ),
              // 3-dot popup menu
              ArrowPopupMenuButton(
                popUpAnimationStyle: popupAnimationStyle,
                itemBuilder: (ctx) => [
                  PopupMenuItem<int>(
                    value: 1,
                    child: Text(l10n.open_random_entry),
                  ),
                  PopupMenuItem<int>(
                    value: 2,
                    child: Text(l10n.import),
                  ),
                ],
                onSelected: (value) {
                  final mangaAsync = ref.read(
                    getAllMangaStreamProvider(
                      categoryId: null,
                      itemType: _currentType,
                    ),
                  );
                  if (value == 1) {
                    mangaAsync.whenData((list) {
                      if (list.isEmpty) return;
                      final randomManga = (list..shuffle()).first;
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
                    showImportLocalDialog(context, _currentType);
                  }
                },
              ),
            ],
          ],
        ),
        body: LibraryScreen(
          itemType: _currentType,
          presetInput: null,
          hideOwnAppBar: true,
          externalSearchQuery: _searchController.text,
          key: ValueKey(_currentType.name),
        ),
      );
    }
  }
  