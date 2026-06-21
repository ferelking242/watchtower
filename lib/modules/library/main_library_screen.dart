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
    late ItemType _currentType;

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

    IconData _typeIcon(ItemType t) => switch (t) {
      ItemType.anime  => Icons.live_tv_outlined,
      ItemType.manga  => Icons.auto_stories_outlined,
      ItemType.novel  => Icons.local_library_outlined,
      ItemType.music  => Icons.music_note_outlined,
      ItemType.game   => Icons.sports_esports_outlined,
      _               => Icons.collections_bookmark_outlined,
    };

    String _typeLabel(ItemType t, dynamic l10n) => switch (t) {
      ItemType.anime  => l10n.watch as String,
      ItemType.manga  => l10n.manga as String,
      ItemType.novel  => l10n.novel as String,
      ItemType.music  => 'Music',
      ItemType.game   => 'Games',
      _               => l10n.library as String,
    };

    void _showTypePicker(BuildContext context, dynamic l10n, ColorScheme cs, bool isDark) {
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
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
                blurRadius: 28, offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              ..._types.map((t) {
                final sel = t == _currentType;
                return InkWell(
                  onTap: () { setState(() => _currentType = t); Navigator.pop(ctx); },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(children: [
                      Icon(_typeIcon(t), size: 22,
                        color: sel ? cs.primary : cs.onSurface.withValues(alpha: 0.6)),
                      const SizedBox(width: 16),
                      Text(_typeLabel(t, l10n), style: TextStyle(
                        fontSize: 16,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? cs.primary : cs.onSurface.withValues(alpha: 0.85),
                      )),
                      if (sel) ...[
                        const Spacer(),
                        Icon(Icons.check_rounded, size: 18, color: cs.primary),
                      ],
                    ]),
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    }

    // ── Circular icon button matching screenshot style ──────────────────────────
    Widget _circleBtn(BuildContext context, {
      required IconData icon,
      required VoidCallback? onTap,
      bool active = false,
      String? tooltip,
    }) {
      final cs = Theme.of(context).colorScheme;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Tooltip(
          message: tooltip ?? '',
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(50),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active
                    ? cs.primary.withValues(alpha: 0.18)
                    : cs.onSurface.withValues(alpha: 0.09),
                border: Border.all(
                  color: active
                      ? cs.primary.withValues(alpha: 0.55)
                      : cs.onSurface.withValues(alpha: 0.14),
                  width: 1.3,
                ),
              ),
              child: Icon(icon, size: 18,
                color: active ? cs.primary : cs.onSurface.withValues(alpha: 0.80)),
            ),
          ),
        ),
      );
    }

    void _openFilterSheet(Settings settings) {
      final mangaAsync = ref.read(
        getAllMangaStreamProvider(categoryId: null, itemType: _currentType));
      final entries = mangaAsync.when(
        data: (v) => v, loading: () => <Manga>[], error: (_, __) => <Manga>[]);
      showLibrarySettingsSheet(
        context: context, vsync: this,
        settings: settings, itemType: _currentType, entries: entries);
    }

    @override
    Widget build(BuildContext context) {
      final settingsStream = ref.watch(getSettingsStreamProvider);
      return settingsStream.when(
        data: (s) => _buildBody(s.first),
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(body: Center(child: Text(e.toString()))),
      );
    }

    Widget _buildBody(Settings settings) {
      final l10n = context.l10n;
      final theme = Theme.of(context);
      final cs = theme.colorScheme;
      final isDark = theme.brightness == Brightness.dark;

      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            automaticallyImplyLeading: false,
            titleSpacing: 16,
            title: _isSearch
                ? SeachFormTextField(
                    onChanged: (_) => setState(() {}),
                    onSuffixPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                    onPressed: () {
                      setState(() { _isSearch = false; _searchController.clear(); });
                    },
                    controller: _searchController,
                  )
                : GestureDetector(
                    onTap: () => _showTypePicker(context, l10n, cs, isDark),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _typeLabel(_currentType, l10n),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white.withValues(alpha: 0.55),
                          size: 22,
                        ),
                      ],
                    ),
                  ),
            actions: _isSearch
                ? []
                : [
                    _circleBtn(context,
                      icon: Icons.search_rounded,
                      tooltip: l10n.search,
                      onTap: () => setState(() => _isSearch = true)),
                    _circleBtn(context,
                      icon: Icons.download_rounded,
                      tooltip: l10n.update_library,
                      onTap: () {
                        ref.read(getAllMangaStreamProvider(
                          categoryId: null, itemType: _currentType)).whenData((list) {
                          updateLibrary(
                            ref: ref, context: context,
                            mangaList: list, itemType: _currentType);
                        });
                      }),
                    _circleBtn(context,
                      icon: Icons.filter_list_sharp,
                      tooltip: 'Filtrer / Trier',
                      onTap: () => _openFilterSheet(settings)),
                    // 3-dot in circle
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: PopupMenuButton<int>(
                        tooltip: '',
                        offset: const Offset(0, 48),
                        child: Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: cs.onSurface.withValues(alpha: 0.09),
                            border: Border.all(
                              color: cs.onSurface.withValues(alpha: 0.14),
                              width: 1.3),
                          ),
                          child: Icon(Icons.more_vert_rounded, size: 18,
                            color: cs.onSurface.withValues(alpha: 0.80)),
                        ),
                        itemBuilder: (ctx) => [
                          PopupMenuItem<int>(value: 0, child: Text(l10n.update_library)),
                          PopupMenuItem<int>(value: 1, child: Text(l10n.open_random_entry)),
                          PopupMenuItem<int>(value: 2, child: Text(l10n.import)),
                        ],
                        onSelected: (value) {
                          final mangaAsync = ref.read(getAllMangaStreamProvider(
                            categoryId: null, itemType: _currentType));
                          if (value == 0) {
                            mangaAsync.whenData((list) => updateLibrary(
                              ref: ref, context: context,
                              mangaList: list, itemType: _currentType));
                          } else if (value == 1) {
                            mangaAsync.whenData((list) {
                              if (list.isEmpty) return;
                              final rng = (list..shuffle()).first;
                              pushToMangaReaderDetail(
                                ref: ref,
                                archiveId: rng.isLocalArchive ?? false ? rng.id : null,
                                context: context, lang: rng.lang!,
                                mangaM: rng, source: rng.source!, sourceId: rng.sourceId);
                            });
                          } else if (value == 2) {
                            showImportLocalDialog(context, _currentType);
                          }
                        },
                      ),
                    ),
                  ],
          ),
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
  