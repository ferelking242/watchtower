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
  late final TabController _controller;
  late final TextEditingController _searchController;
  bool _isSearch = false;

  static const _types = [
    ItemType.anime,
    ItemType.manga,
    ItemType.novel,
    ItemType.music,
    ItemType.game,
  ];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialType ?? ItemType.anime;
    final initIndex = _types.indexOf(initial).clamp(0, _types.length - 1);
    _controller = TabController(
      length: _types.length,
      vsync: this,
      initialIndex: initIndex,
    );
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
    _searchController = TextEditingController(text: widget.presetInput ?? '');
    if (widget.presetInput != null && widget.presetInput!.isNotEmpty) {
      _isSearch = true;
    }
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  ItemType get _currentType => _types[_controller.index];

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
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text(e.toString()))),
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
            : Text(
                l10n.library,
                style: TextStyle(color: theme.hintColor),
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
            IconButton(
              tooltip: 'Filter / Sort / Display',
              splashRadius: 20,
              onPressed: () => _openFilterSheet(settings),
              icon: Icon(
                Icons.filter_list_sharp,
                color: theme.hintColor,
              ),
            ),
            ArrowPopupMenuButton(
              popUpAnimationStyle: popupAnimationStyle,
              itemBuilder: (ctx) => [
                PopupMenuItem<int>(
                  value: 0,
                  child: Text(l10n.update_library),
                ),
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
                if (value == 0) {
                  mangaAsync.whenData((list) {
                    updateLibrary(
                      ref: ref,
                      context: context,
                      mangaList: list,
                      itemType: _currentType,
                    );
                  });
                } else if (value == 1) {
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
        bottom: TabBar(
          controller: _controller,
          indicatorSize: TabBarIndicatorSize.tab,
          tabAlignment: TabAlignment.fill,
          dividerColor: Colors.transparent,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.hintColor,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          isScrollable: true,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.live_tv_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text(l10n.watch),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_stories_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text(l10n.manga),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_library_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text(l10n.novel),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.music_note_outlined, size: 16),
                  const SizedBox(width: 6),
                  const Text('Music'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sports_esports_outlined, size: 16),
                  const SizedBox(width: 6),
                  const Text('Games'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _controller,
        physics: const BouncingScrollPhysics(),
        children: [
          LibraryScreen(
            itemType: ItemType.anime,
            presetInput: null,
            hideOwnAppBar: true,
            externalSearchQuery: _searchController.text,
            key: const ValueKey('anime-lib'),
          ),
          LibraryScreen(
            itemType: ItemType.manga,
            presetInput: null,
            hideOwnAppBar: true,
            externalSearchQuery: _searchController.text,
            key: const ValueKey('manga-lib'),
          ),
          LibraryScreen(
            itemType: ItemType.novel,
            presetInput: null,
            hideOwnAppBar: true,
            externalSearchQuery: _searchController.text,
            key: const ValueKey('novel-lib'),
          ),
          LibraryScreen(
            itemType: ItemType.music,
            presetInput: null,
            hideOwnAppBar: true,
            externalSearchQuery: _searchController.text,
            key: const ValueKey('music-lib'),
          ),
          LibraryScreen(
            itemType: ItemType.game,
            presetInput: null,
            hideOwnAppBar: true,
            externalSearchQuery: _searchController.text,
            key: const ValueKey('game-lib'),
          ),
        ],
      ),
    );
  }
}
