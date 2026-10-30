import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/eval/model/m_chapter.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/models/layout_component_registry.dart';
import 'package:watchtower/models/manga.dart' show ItemType;
import 'package:watchtower/models/source.dart';
import 'package:watchtower/models/ui_layout.dart';
import 'package:watchtower/modules/media/app_ui_components.dart';
import 'package:watchtower/modules/media/content_cards.dart';
import 'package:watchtower/modules/media/media_home_widgets.dart';
import 'package:watchtower/modules/media/media_content_sections.dart';
import 'package:watchtower/modules/manga/home/widgets/manga_home_card_adapter.dart';
import 'package:watchtower/modules/watch/home/extension_episode_card_adapter.dart';
import 'package:watchtower/modules/watch/home/extension_chapter_card_adapter.dart';
import 'package:watchtower/modules/widgets/manga_image_card_widget.dart';
import 'package:watchtower/services/get_custom_list.dart';
import 'package:watchtower/services/get_latest_updates.dart';
import 'package:watchtower/services/get_popular.dart';
import 'package:watchtower/services/extension_page_cache.dart';
import 'package:watchtower/services/layout_downloader.dart';
import 'package:watchtower/services/layout_registry.dart';
import 'package:watchtower/services/search.dart';
import 'package:watchtower/modules/watch/home/extension_collection_route.dart';
import 'package:watchtower/modules/watch/home/extension_person_route.dart';
import 'package:watchtower/modules/search/extension_search_screen.dart';
import 'package:watchtower/modules/watch/home/extension_video_preview.dart';
import 'package:watchtower/modules/watch/home/gallery_component_renderer.dart';
import 'package:watchtower/modules/more/settings/downloads/smart_library_screen.dart';
import 'package:watchtower/modules/dev/component_gallery_screen.dart';
import 'package:watchtower/modules/browse/extension/layout_json_editor_screen.dart';
import 'package:watchtower/modules/watch/home/extension_home_empty_state.dart';
import 'package:watchtower/utils/cached_network.dart';
import 'package:watchtower/utils/adaptive_overlay_menu.dart';
import 'package:watchtower/utils/headers.dart';
import 'package:watchtower/modules/media/extension_image_headers.dart';
import 'package:watchtower/widgets/kaomoji_empty.dart';

enum _LayoutEditorDestination { home, gallery, json }

/// The Watch extension home uses the same media composition as the Hub.
/// Only the data boundary is different: every card is supplied by the
/// selected extension instead of TMDB.
class WatchExtensionHomeScreen extends ConsumerStatefulWidget {
  final Source source;
  final bool isLocalLibrary;
  final ItemType? localItemType;
  final String? initialSearchQuery;
  final String? initialSectionId;
  final bool layoutEditorMode;

  /// Section stack used when the source ships no custom `home.sections`.
  /// Home screens (e.g. the manga home) inject gallery components here so a
  /// source without a layout still renders the curated cards.
  final List<UiSection> defaultSections;

  const WatchExtensionHomeScreen({
    required this.source,
    this.initialSearchQuery,
    this.initialSectionId,
    this.layoutEditorMode = false,
    this.defaultSections = const [],
    super.key,
  }) : isLocalLibrary = false,
       localItemType = null;

  WatchExtensionHomeScreen.localLibrary({required ItemType itemType, super.key})
    : source = Source(
        name: 'local_smart_library',
        lang: '',
        itemType: itemType,
      ),
      isLocalLibrary = true,
      localItemType = itemType,
      initialSearchQuery = null,
      initialSectionId = null,
      layoutEditorMode = false,
      defaultSections = const [];

  @override
  ConsumerState<WatchExtensionHomeScreen> createState() =>
      _WatchExtensionHomeScreenState();
}

class _WatchExtensionHomeScreenState
    extends ConsumerState<WatchExtensionHomeScreen> {
  final _feedController = ScrollController();
  bool _showCompactHeader = false;
  late bool _isSearching = widget.initialSearchQuery?.trim().isNotEmpty == true;
  bool _layoutReady = false;
  Object? _layoutError;
  UiLayout _layout = UiLayout.empty;
  Map<String, dynamic>? _layoutJson;
  Future<void>? _layoutLoadOperation;
  Future<void>? _refreshOperation;

  /// Last rendered failure, retained while a retry is in flight so the build
  /// keeps returning the same empty-state surface instead of swapping to the
  /// full-screen loading shimmer. The swap destroyed the inline challenge
  /// WebView and reloaded the page on every attempt.
  Object? _lastSectionError;
  _LayoutEditorDestination _editorDestination = _LayoutEditorDestination.home;
  bool _editorDockExpanded = false;
  String? _pendingReplacementSectionId;
  String? _pendingMangaCardSectionId;
  String? _pendingEpisodeCardSectionId;
  String? _pendingChapterCardSectionId;
  int _layoutEditorRevision = 0;
  final Set<String> _loggedRequestErrors = {};

  Source get source => widget.source;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );
    _feedController.addListener(_updateCompactHeader);
    if (!widget.isLocalLibrary) _loadLayout();
  }

  Future<void> _loadLayout() {
    final existing = _layoutLoadOperation;
    if (existing != null) return existing;

    final operation = _loadLayoutOnce();
    _layoutLoadOperation = operation;
    return operation;
  }

  Future<void> _loadLayoutOnce() async {
    try {
      await LayoutRegistry.instance.load(source);
      if (source.providesHome && !LayoutRegistry.instance.has(source)) {
        await LayoutDownloader.instance.download(source);
      }
      final rawLayout = await LayoutRegistry.instance.readJson(source);
      Map<String, dynamic>? decodedLayout = rawLayout == null
          ? null
          : jsonDecode(rawLayout) as Map<String, dynamic>;
      var loadedLayout = LayoutRegistry.instance.get(source);
      if (widget.layoutEditorMode && decodedLayout != null) {
        final rawHome = decodedLayout['home'];
        if (rawHome is Map<String, dynamic>) {
          final home = Map<String, dynamic>.from(rawHome);
          final sections = home['sections'];
          if (sections is! List || sections.isEmpty) {
            home['sections'] = [
              <String, dynamic>{
                'id': 'popular',
                'title': 'Popular',
                'component': 'grid',
              },
              <String, dynamic>{
                'id': 'latest',
                'title': 'Latest',
                'component': 'grid',
              },
            ];
            decodedLayout['home'] = home;
            loadedLayout = UiLayout.fromJson(decodedLayout);
          }
        }
      }
      if (loadedLayout.home.sections.isEmpty &&
          widget.defaultSections.isNotEmpty) {
        loadedLayout = UiLayout(
          schemaVersion: loadedLayout.schemaVersion,
          home: HomeLayout(sections: widget.defaultSections),
          browse: loadedLayout.browse,
          detail: loadedLayout.detail,
          player: loadedLayout.player,
        );
      }
      if (!mounted) return;
      setState(() {
        _layout = loadedLayout;
        _layoutJson = decodedLayout;
        _layoutReady = true;
        _layoutError = null;
      });
    } catch (error) {
      if (!mounted) return;
      _logRequestFailure('layout', error);
      setState(() => _layoutError = error);
    }
  }

  Future<void> _retryLayout() async {
    if (!mounted) return;
    _loggedRequestErrors.clear();
    setState(() {
      _layoutError = null;
      _layoutLoadOperation = null;
    });
    await _loadLayout();
  }

  void _logRequestFailure(String request, Object? error) {
    if (error == null) return;
    final detail = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    final summary = detail.length > 240
        ? '${detail.substring(0, 240)}…'
        : detail;
    final key = '$request:${error.runtimeType}:$summary';
    if (!_loggedRequestErrors.add(key)) return;
    debugPrint(
      '[WatchExtensionHome] request_failed '
      'source=${source.name ?? "unknown"} route=$request error=$summary',
    );
  }

  List<Map<String, dynamic>> _copyLayoutSections() {
    final home = _layoutJson?['home'];
    if (home is! Map<String, dynamic>) return [];
    final rawSections = home['sections'];
    if (rawSections is! List) return [];
    return rawSections
        .whereType<Map<String, dynamic>>()
        .map(Map<String, dynamic>.from)
        .toList(growable: true);
  }

  Future<bool> _saveLayoutSections(List<Map<String, dynamic>> sections) async {
    final original = _layoutJson;
    if (original == null) {
      _showEditorMessage('Le layout de cette extension est indisponible.');
      return false;
    }

    final updated = Map<String, dynamic>.from(original);
    final home = Map<String, dynamic>.from(
      updated['home'] as Map<String, dynamic>,
    );
    home['sections'] = sections
        .map((section) => Map<String, dynamic>.from(section))
        .toList(growable: false);
    updated['home'] = home;
    bool saved;
    try {
      saved = await LayoutRegistry.instance.save(
        source,
        const JsonEncoder.withIndent('  ').convert(updated),
      );
    } catch (error) {
      _showEditorMessage('Échec de l’enregistrement du layout : $error');
      return false;
    }
    if (!saved) {
      _showEditorMessage('Le layout n’a pas pu être enregistré.');
      return false;
    }
    if (!mounted) return false;
    setState(() {
      _layoutJson = updated;
      _layout = LayoutRegistry.instance.get(source);
      _layoutEditorRevision++;
    });
    return true;
  }

  void _showEditorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _moveEditorSection(int index, int offset) {
    final sections = _copyLayoutSections();
    final targetIndex = index + offset;
    if (index < 0 ||
        index >= sections.length ||
        targetIndex < 0 ||
        targetIndex >= sections.length) {
      return;
    }
    final section = sections.removeAt(index);
    sections.insert(targetIndex, section);
    unawaited(_saveLayoutSections(sections));
  }

  void _deleteEditorSection(int index) {
    final sections = _copyLayoutSections();
    if (index < 0 || index >= sections.length) return;
    sections.removeAt(index);
    unawaited(_saveLayoutSections(sections));
  }

  void _startSectionReplacement(String sectionId) {
    setState(() {
      _pendingReplacementSectionId = sectionId;
      _pendingMangaCardSectionId = null;
      _pendingEpisodeCardSectionId = null;
      _pendingChapterCardSectionId = null;
      _editorDestination = _LayoutEditorDestination.gallery;
      _editorDockExpanded = false;
    });
  }

  void _startMangaCardSelection(String sectionId) {
    setState(() {
      _pendingReplacementSectionId = null;
      _pendingMangaCardSectionId = sectionId;
      _pendingEpisodeCardSectionId = null;
      _pendingChapterCardSectionId = null;
      _editorDestination = _LayoutEditorDestination.gallery;
      _editorDockExpanded = false;
    });
  }

  void _startEpisodeCardSelection(String sectionId) {
    setState(() {
      _pendingReplacementSectionId = null;
      _pendingMangaCardSectionId = null;
      _pendingEpisodeCardSectionId = sectionId;
      _pendingChapterCardSectionId = null;
      _editorDestination = _LayoutEditorDestination.gallery;
      _editorDockExpanded = false;
    });
  }

  void _startChapterCardSelection(String sectionId) {
    setState(() {
      _pendingReplacementSectionId = null;
      _pendingMangaCardSectionId = null;
      _pendingEpisodeCardSectionId = null;
      _pendingChapterCardSectionId = sectionId;
      _editorDestination = _LayoutEditorDestination.gallery;
      _editorDockExpanded = false;
    });
  }

  Future<void> _applyLayoutComponent(String component) async {
    final sectionId = _pendingReplacementSectionId;
    if (sectionId == null) {
      _showEditorMessage(
        'Maintiens d’abord une section, puis choisis « Remplacer ».',
      );
      return;
    }
    final sections = _copyLayoutSections();
    final index = sections.indexWhere(
      (section) => section['id']?.toString() == sectionId,
    );
    if (index < 0) {
      _showEditorMessage('Cette section n’existe plus dans le layout.');
      return;
    }
    sections[index]['component'] = component;
    if (LayoutComponentRegistry.resolve(component)?.renderer !=
        LayoutComponentRenderer.grid) {
      sections[index].remove('cardComponent');
      sections[index].remove('episodeComponent');
      sections[index].remove('chapterComponent');
    }
    if (await _saveLayoutSections(sections) && mounted) {
      setState(() {
        _pendingReplacementSectionId = null;
        _editorDestination = _LayoutEditorDestination.home;
      });
    }
  }

  Future<void> _applyEpisodeCardComponent(String component) async {
    final sectionId = _pendingEpisodeCardSectionId;
    if (sectionId == null) return;
    if (source.itemType != ItemType.anime ||
        !LayoutComponentRegistry.supports(
          component,
          LayoutComponentContext.homeEpisodeCard,
        )) {
      _showEditorMessage(
        'Cette carte épisode n’est pas compatible avec cette sélection.',
      );
      return;
    }

    final sections = _copyLayoutSections();
    final index = sections.indexWhere(
      (section) => section['id']?.toString() == sectionId,
    );
    if (index < 0) {
      _showEditorMessage('Cette section n’existe plus dans le layout.');
      return;
    }
    final sectionComponent = sections[index]['component']?.toString() ?? 'grid';
    if (LayoutComponentRegistry.resolve(sectionComponent)?.renderer !=
        LayoutComponentRenderer.grid) {
      _showEditorMessage(
        'Les cartes épisode personnalisées sont disponibles sur les sections en grille.',
      );
      return;
    }

    sections[index].remove('cardComponent');
    sections[index].remove('chapterComponent');
    sections[index]['episodeComponent'] = component;
    if (await _saveLayoutSections(sections) && mounted) {
      setState(() {
        _pendingEpisodeCardSectionId = null;
        _editorDestination = _LayoutEditorDestination.home;
      });
    }
  }

  Future<void> _applyChapterCardComponent(String component) async {
    final sectionId = _pendingChapterCardSectionId;
    if (sectionId == null) return;
    if (source.itemType != ItemType.manga ||
        !LayoutComponentRegistry.supports(
          component,
          LayoutComponentContext.chapter,
        )) {
      _showEditorMessage(
        'Cette carte de chapitre n’est pas compatible avec cette sélection.',
      );
      return;
    }

    final sections = _copyLayoutSections();
    final index = sections.indexWhere(
      (section) => section['id']?.toString() == sectionId,
    );
    if (index < 0) {
      _showEditorMessage('Cette section n’existe plus dans le layout.');
      return;
    }
    final sectionComponent = sections[index]['component']?.toString() ?? 'grid';
    if (LayoutComponentRegistry.resolve(sectionComponent)?.renderer !=
        LayoutComponentRenderer.grid) {
      _showEditorMessage(
        'Les cartes de chapitre personnalisées sont disponibles sur les sections en grille.',
      );
      return;
    }

    sections[index].remove('cardComponent');
    sections[index].remove('episodeComponent');
    sections[index]['chapterComponent'] = component;
    if (await _saveLayoutSections(sections) && mounted) {
      setState(() {
        _pendingChapterCardSectionId = null;
        _editorDestination = _LayoutEditorDestination.home;
      });
    }
  }

  Future<void> _applyMangaCardComponent(String component) async {
    final sectionId = _pendingMangaCardSectionId;
    if (sectionId == null) return;
    if (source.itemType != ItemType.manga ||
        !LayoutComponentRegistry.supports(
          component,
          LayoutComponentContext.homeMangaCard,
        )) {
      _showEditorMessage(
        'Cette carte Manga n’est pas compatible avec cette sélection.',
      );
      return;
    }

    final sections = _copyLayoutSections();
    final index = sections.indexWhere(
      (section) => section['id']?.toString() == sectionId,
    );
    if (index < 0) {
      _showEditorMessage('Cette section n’existe plus dans le layout.');
      return;
    }
    final sectionComponent = sections[index]['component']?.toString() ?? 'grid';
    if (LayoutComponentRegistry.resolve(sectionComponent)?.renderer !=
        LayoutComponentRenderer.grid) {
      _showEditorMessage(
        'Les cartes Manga personnalisées sont disponibles sur les sections en grille.',
      );
      return;
    }

    sections[index]['cardComponent'] = component;
    sections[index].remove('episodeComponent');
    sections[index].remove('chapterComponent');
    if (await _saveLayoutSections(sections) && mounted) {
      setState(() {
        _pendingMangaCardSectionId = null;
        _editorDestination = _LayoutEditorDestination.home;
      });
    }
  }

  Future<void> _reloadLayoutAfterJsonSave() async {
    try {
      final rawLayout = await LayoutRegistry.instance.readJson(source);
      if (!mounted || rawLayout == null) return;
      setState(() {
        _layoutJson = jsonDecode(rawLayout) as Map<String, dynamic>;
        _layout = LayoutRegistry.instance.get(source);
      });
    } catch (error) {
      _showEditorMessage(
        'Layout enregistré, mais aperçu impossible à actualiser : $error',
      );
    }
  }

  void _updateCompactHeader() {
    if (!_feedController.hasClients) return;
    final heroHeight = (MediaQuery.sizeOf(context).height * .56).clamp(
      480.0,
      590.0,
    );
    // Hero is drawn heroHeight + 36 tall (notch overhang) — match it.
    final shouldShow = _feedController.offset >= heroHeight + 36;
    if (shouldShow != _showCompactHeader && mounted) {
      setState(() => _showCompactHeader = shouldShow);
    }
  }

  Future<void> _refresh() {
    final existing = _refreshOperation;
    if (existing != null) return existing;
    final operation = _refreshOnce();
    _refreshOperation = operation;
    return operation.whenComplete(() {
      if (identical(_refreshOperation, operation)) _refreshOperation = null;
    });
  }

  Future<void> _refreshOnce() async {
    _loggedRequestErrors.clear();
    extensionPageCache.invalidateSource(source);
    if (!_layoutReady && source.providesHome) {
      await _loadLayout();
      if (!mounted) return;
    }

    final futures = <Future<Object?>>[];
    final sections = _layout.home.sections;
    if (sections.isEmpty) {
      futures
        ..add(ref.refresh(getPopularProvider(source: source, page: 1).future))
        ..add(
          ref.refresh(getLatestUpdatesProvider(source: source, page: 1).future),
        );
    } else {
      for (final section in sections) {
        final future = switch (section.id) {
          'popular' => ref.refresh(
            getPopularProvider(source: source, page: 1).future,
          ),
          'latest' => ref.refresh(
            getLatestUpdatesProvider(source: source, page: 1).future,
          ),
          _ => ref.refresh(
            getCustomListProvider(
              source: source,
              listId: section.id,
              page: 1,
            ).future,
          ),
        };
        futures.add(future);
      }
    }
    await Future.wait(futures);
  }

  void _openItem(MManga item) {
    if (item.link == null || item.link!.isEmpty) return;
    final collection = ExtensionCollectionRoute.fromItem(item);
    if (collection == null && isExtensionPersonItem(item)) {
      openExtensionPersonScreen(context: context, source: source, item: item);
      return;
    }
    if (collection != null) {
      if (collection.listId.startsWith('playlist_')) {
        unawaited(_playFirstFromCollection(collection.listId));
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TmdbMoviesListScreen.extension(
            source: source,
            sectionId: collection.listId,
            title: item.name?.trim().isNotEmpty == true
                ? item.name!.trim()
                : source.name ?? 'Collection',
            initialExtensionItems: const [],
            cardStyle: collection.listId.startsWith('search_')
                ? 'landscape'
                : null,
          ),
        ),
      );
      return;
    }
    pushToMangaReaderDetail(
      ref: ref,
      context: context,
      getManga: item,
      lang: source.lang ?? '',
      source: source.name ?? '',
      sourceId: source.id,
      itemType: source.itemType,
    );
  }

  Future<void> _playFirstFromCollection(String listId) async {
    try {
      final pages = await ref.read(
        getCustomListProvider(source: source, listId: listId, page: 1).future,
      );
      MManga? first;
      for (final item in pages?.list ?? const <MManga>[]) {
        if (item.link?.trim().isNotEmpty == true) {
          first = item;
          break;
        }
      }
      if (!mounted) return;
      if (first == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucune vidéo disponible dans cette playlist.'),
          ),
        );
        return;
      }
      _openItem(first);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de charger la playlist : $error')),
      );
    }
  }

  @override
  void dispose() {
    _feedController
      ..removeListener(_updateCompactHeader)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final headers = ref.watch(
      headersProvider(
        source: source.name ?? '',
        lang: source.lang ?? '',
        sourceId: source.id,
      ),
    );
    return ExtensionImageHeaders(
      headers: headers,
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    // Smart Library is an on-device index, not an extension. Return before
    // watching any extension providers or loading a remote layout.
    if (widget.isLocalLibrary) {
      return SmartLibraryScreen(itemType: widget.localItemType);
    }

    if (_isSearching) {
      return ExtensionSearchScreen(
        source: source,
        initialQuery: widget.initialSearchQuery,
        onClose: () => setState(() => _isSearching = false),
        onOpen: _openItem,
      );
    }

    final initialSectionId = widget.initialSectionId;
    if (initialSectionId != null && !widget.isLocalLibrary) {
      return TmdbMoviesListScreen.extension(
        source: source,
        sectionId: initialSectionId,
        title: initialSectionId == 'latest' ? 'Latest' : initialSectionId,
        initialExtensionItems: const [],
      );
    }

    if (!_layoutReady && source.providesHome) {
      final layoutError = _layoutError;
      if (layoutError != null) {
        return _ExtensionEmpty(
          source: source,
          onRefresh: _retryLayout,
          error: layoutError,
        );
      }
      return _ExtensionHomeLoading(
        source: source,
        onSearch: () => setState(() => _isSearching = true),
        onRefresh: _refresh,
      );
    }

    final sections = _layout.home.sections;
    final hasDeclaredSections = sections.isNotEmpty;
    // A declarative home owns its data requests section by section. Watching
    // Popular/Latest here as well caused duplicate extension calls and made a
    // custom home wait for unrelated built-in rails.
    final sectionAsyncValues = [
      for (final section in sections)
        switch (section.params['dataSource'] ?? section.id) {
          'popular' => ref.watch(getPopularProvider(source: source, page: 1)),
          'latest' => ref.watch(
            getLatestUpdatesProvider(source: source, page: 1),
          ),
          _ => ref.watch(
            getCustomListProvider(source: source, listId: section.id, page: 1),
          ),
        },
    ];
    Object? sectionError;
    for (var index = 0; index < sectionAsyncValues.length; index++) {
      final result = sectionAsyncValues[index];
      if (!result.hasError) continue;
      final error = result.error;
      sectionError ??= error;
      _logRequestFailure(sections[index].id, error);
    }
    final hasSectionContent = sectionAsyncValues.any(
      (value) => value.value?.list.isNotEmpty == true,
    );
    final isLoadingSections = sectionAsyncValues.any(
      (value) => value.isLoading,
    );
    // Keep the previous failure across the retry that clears the AsyncError,
    // so the build returns the same empty state instead of bouncing to the
    // full-screen shimmer. Every bounce remounted the inline challenge WebView
    // and reloaded it, which is the loop the user sees. A settled call clears
    // the retained error so a later plain-empty state is not mislabelled.
    final Object? retainedSectionError;
    if (sectionError != null) {
      retainedSectionError = sectionError;
    } else if (isLoadingSections) {
      retainedSectionError = _lastSectionError;
    } else {
      retainedSectionError = null;
    }
    _lastSectionError = retainedSectionError;
    if (hasDeclaredSections && !widget.layoutEditorMode && !hasSectionContent) {
      if (sectionError != null || retainedSectionError != null) {
        return _ExtensionEmpty(
          source: source,
          onRefresh: _refresh,
          error: sectionError ?? retainedSectionError,
        );
      }
      if (isLoadingSections) {
        return _ExtensionHomeLoading(
          source: source,
          onSearch: () => setState(() => _isSearching = true),
          onRefresh: _refresh,
        );
      }
      return _ExtensionEmpty(source: source, onRefresh: _refresh);
    }

    final popularAsync = hasDeclaredSections
        ? null
        : ref.watch(getPopularProvider(source: source, page: 1));
    final latestAsync = hasDeclaredSections
        ? null
        : ref.watch(getLatestUpdatesProvider(source: source, page: 1));
    final popular =
        popularAsync?.whenOrNull(data: (pages) => pages)?.list ??
        const <MManga>[];
    final latest =
        latestAsync?.whenOrNull(data: (pages) => pages)?.list ??
        const <MManga>[];
    final isLoading =
        !hasDeclaredSections &&
        (popularAsync?.isLoading == true || latestAsync?.isLoading == true);

    final error = popularAsync?.error ?? latestAsync?.error;
    final hasError =
        popularAsync?.hasError == true || latestAsync?.hasError == true;

    // Mirror the retained-error behaviour above for sources without a declared
    // layout: while a retry runs, Riverpod clears the error and reports
    // loading, so remember the previous failure to keep the empty state (and
    // the inline challenge WebView) mounted instead of swapping in the shimmer.
    final Object? retainedError;
    if (hasError) {
      retainedError = error;
    } else if (isLoading && popular.isEmpty && latest.isEmpty) {
      retainedError = _lastSectionError;
    } else {
      retainedError = null;
    }
    _lastSectionError = retainedError;

    // Keep the empty state (and the inline bypass WebView it may host) mounted
    // while a retry is in flight: swapping to the full-screen loading shimmer
    // on every attempt remounted the whole surface — header, feed and WebView —
    // which read as the page reloading over and over.
    if (isLoading &&
        popular.isEmpty &&
        latest.isEmpty &&
        retainedError == null &&
        !hasError) {
      return _ExtensionHomeLoading(
        source: source,
        onSearch: () => setState(() => _isSearching = true),
        onRefresh: _refresh,
      );
    }

    if ((hasError || retainedError != null) &&
        popular.isEmpty &&
        latest.isEmpty) {
      _logRequestFailure(
        popularAsync?.hasError == true ? 'popular' : 'latest',
        error,
      );
      return _ExtensionEmpty(
        source: source,
        onRefresh: _refresh,
        error: error ?? retainedError,
      );
    }

    return _ExtensionFeed(
      source: source,
      popular: popular,
      latest: latest,
      layout: _layout,
      controller: _feedController,
      showCompactHeader: _showCompactHeader,
      onSearch: () => setState(() => _isSearching = true),
      onOpen: _openItem,
      onRefresh: _refresh,
      layoutEditorMode: widget.layoutEditorMode,
      editorDestination: _editorDestination,
      editorDockExpanded: _editorDockExpanded,
      onEditorDestinationChanged: (destination) => setState(() {
        if (destination == _LayoutEditorDestination.home &&
            _editorDestination == _LayoutEditorDestination.gallery) {
          _pendingReplacementSectionId = null;
          _pendingMangaCardSectionId = null;
          _pendingEpisodeCardSectionId = null;
          _pendingChapterCardSectionId = null;
        }
        _editorDestination = destination;
        _editorDockExpanded = false;
      }),
      onToggleEditorDock: () =>
          setState(() => _editorDockExpanded = !_editorDockExpanded),
      onMoveSection: _moveEditorSection,
      onDeleteSection: _deleteEditorSection,
      onReplaceSection: _startSectionReplacement,
      onCustomizeMangaCards: _startMangaCardSelection,
      onCustomizeEpisodeCards: _startEpisodeCardSelection,
      onCustomizeChapterCards: _startChapterCardSelection,
      isSelectingComponent:
          _pendingReplacementSectionId != null ||
          _pendingMangaCardSectionId != null ||
          _pendingEpisodeCardSectionId != null ||
          _pendingChapterCardSectionId != null,
      selectionContext: _pendingChapterCardSectionId != null
          ? LayoutComponentContext.chapter
          : _pendingEpisodeCardSectionId != null
          ? LayoutComponentContext.homeEpisodeCard
          : _pendingMangaCardSectionId != null
          ? LayoutComponentContext.homeMangaCard
          : LayoutComponentContext.home,
      layoutEditorInitialContent: _layoutJson == null
          ? null
          : const JsonEncoder.withIndent('  ').convert(_layoutJson),
      layoutEditorRevision: _layoutEditorRevision,
      onSelectLayoutComponent: (component) => unawaited(
        _pendingChapterCardSectionId != null
            ? _applyChapterCardComponent(component)
            : _pendingEpisodeCardSectionId != null
            ? _applyEpisodeCardComponent(component)
            : _pendingMangaCardSectionId != null
            ? _applyMangaCardComponent(component)
            : _applyLayoutComponent(component),
      ),
      onLayoutJsonSaved: _reloadLayoutAfterJsonSave,
    );
  }
}

class _ExtensionFeed extends StatelessWidget {
  final Source source;
  final List<MManga> popular;
  final List<MManga> latest;
  final UiLayout layout;
  final ScrollController controller;
  final bool showCompactHeader;
  final VoidCallback onSearch;
  final ValueChanged<MManga> onOpen;
  final Future<void> Function() onRefresh;
  final bool layoutEditorMode;
  final _LayoutEditorDestination editorDestination;
  final bool editorDockExpanded;
  final ValueChanged<_LayoutEditorDestination> onEditorDestinationChanged;
  final VoidCallback onToggleEditorDock;
  final void Function(int index, int offset) onMoveSection;
  final ValueChanged<int> onDeleteSection;
  final ValueChanged<String> onReplaceSection;
  final ValueChanged<String> onCustomizeMangaCards;
  final ValueChanged<String> onCustomizeEpisodeCards;
  final ValueChanged<String> onCustomizeChapterCards;
  final bool isSelectingComponent;
  final LayoutComponentContext selectionContext;
  final ValueChanged<String> onSelectLayoutComponent;
  final Future<void> Function() onLayoutJsonSaved;
  final String? layoutEditorInitialContent;
  final int layoutEditorRevision;

  const _ExtensionFeed({
    required this.source,
    required this.popular,
    required this.latest,
    required this.layout,
    required this.controller,
    required this.showCompactHeader,
    required this.onSearch,
    required this.onOpen,
    required this.onRefresh,
    required this.layoutEditorMode,
    required this.editorDestination,
    required this.editorDockExpanded,
    required this.onEditorDestinationChanged,
    required this.onToggleEditorDock,
    required this.onMoveSection,
    required this.onDeleteSection,
    required this.onReplaceSection,
    required this.onCustomizeMangaCards,
    required this.onCustomizeEpisodeCards,
    required this.onCustomizeChapterCards,
    required this.isSelectingComponent,
    required this.selectionContext,
    required this.onSelectLayoutComponent,
    required this.onLayoutJsonSaved,
    required this.layoutEditorInitialContent,
    required this.layoutEditorRevision,
  });

  List<MManga> get combined {
    final result = <MManga>[];
    final seen = <String>{};
    for (final item in [...popular, ...latest]) {
      final key = item.link ?? item.name ?? '${item.hashCode}';
      if (seen.add(key)) result.add(item);
    }
    return result;
  }

  void _showSectionActions(
    BuildContext context,
    int index,
    UiSection section,
    int sectionCount,
  ) {
    final title = section.title?.trim().isNotEmpty == true
        ? section.title!.trim()
        : section.id;
    final sectionDefinition = LayoutComponentRegistry.resolve(
      section.component,
    );
    final canCustomizeMangaCards =
        source.itemType == ItemType.manga &&
        sectionDefinition?.supportedContexts.contains(
              LayoutComponentContext.home,
            ) ==
            true &&
        sectionDefinition?.renderer == LayoutComponentRenderer.grid;
    final canCustomizeEpisodeCards =
        source.itemType == ItemType.anime &&
        sectionDefinition?.supportedContexts.contains(
              LayoutComponentContext.home,
            ) ==
            true &&
        sectionDefinition?.renderer == LayoutComponentRenderer.grid;
    final canCustomizeChapterCards =
        source.itemType == ItemType.manga &&
        sectionDefinition?.supportedContexts.contains(
              LayoutComponentContext.home,
            ) ==
            true &&
        sectionDefinition?.renderer == LayoutComponentRenderer.grid;
    final selectedCardLabel =
        LayoutComponentRegistry.resolve(section.cardComponent ?? '')?.label ??
        'Affiche standard';
    final selectedEpisodeCardLabel =
        LayoutComponentRegistry.resolve(
          section.episodeComponent ?? '',
        )?.label ??
        'Carte par défaut';
    final selectedChapterCardLabel =
        LayoutComponentRegistry.resolve(
          section.chapterComponent ?? '',
        )?.label ??
        'Carte par défaut';
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_with_rounded),
              title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: const Text('Actions sur cette section'),
            ),
            if (index > 0)
              ListTile(
                leading: const Icon(Icons.arrow_upward_rounded),
                title: const Text('Déplacer d’un niveau vers le haut'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onMoveSection(index, -1);
                },
              ),
            if (index < sectionCount - 1)
              ListTile(
                leading: const Icon(Icons.arrow_downward_rounded),
                title: const Text('Déplacer d’un niveau vers le bas'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onMoveSection(index, 1);
                },
              ),
            ListTile(
              leading: const Icon(Icons.widgets_outlined),
              title: const Text('Remplacer le composant'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onReplaceSection(section.id);
              },
            ),
            if (canCustomizeMangaCards)
              ListTile(
                leading: const Icon(Icons.style_outlined),
                title: const Text('Style des cartes manga'),
                subtitle: Text('Actuel : $selectedCardLabel'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onCustomizeMangaCards(section.id);
                },
              ),
            if (canCustomizeEpisodeCards)
              ListTile(
                leading: const Icon(Icons.movie_outlined),
                title: const Text('Style des cartes épisode'),
                subtitle: Text('Actuel : $selectedEpisodeCardLabel'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onCustomizeEpisodeCards(section.id);
                },
              ),
            if (canCustomizeChapterCards)
              ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: const Text('Style des cartes de chapitre'),
                subtitle: Text('Actuel : $selectedChapterCardLabel'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onCustomizeChapterCards(section.id);
                },
              ),
            ListTile(
              leading: Icon(
                Icons.delete_outline_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Supprimer la section',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Supprimer cette section ?'),
                    content: Text('« $title » sera retirée de cet accueil.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('Annuler'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: const Text('Supprimer'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) onDeleteSection(index);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = combined;
    final sections = layout.home.sections;
    final hasDeclaredSections = sections.isNotEmpty || layoutEditorMode;
    final hasContent = all.isNotEmpty || hasDeclaredSections;
    if (!hasContent && !layoutEditorMode) {
      return _ExtensionEmpty(source: source, onRefresh: onRefresh);
    }
    final homeFeed = Stack(
      children: [
        ExtensionAppleRefreshable(
          onRefresh: onRefresh,
          child: CustomScrollView(
            controller: controller,
            physics: const AlwaysScrollableScrollPhysics(
              // Keep the hero fixed while pulling to refresh. The custom
              // indicator is painted above the feed instead of relying on
              // iOS' expanding spinner/displacement.
              parent: ClampingScrollPhysics(),
            ),
            slivers: [
              if (!hasDeclaredSections)
                SliverToBoxAdapter(
                  child: (popular.isNotEmpty || latest.isNotEmpty)
                      ? MediaHeroCarousel(
                          items: (popular.isNotEmpty ? popular : latest)
                              .map(ContentItem.fromManga)
                              .toList(growable: false),
                          onOpen: (index) => onOpen(
                            (popular.isNotEmpty ? popular : latest)[index],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              if (layoutEditorMode && sections.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Aucune section. Utilise l’éditeur JSON pour en créer une.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              SliverList(
                delegate: SliverChildListDelegate.fixed(
                  hasDeclaredSections
                      ? List<Widget>.generate(sections.length, (index) {
                          final section = sections[index];
                          final rendered = _ExtensionLayoutSection(
                            source: source,
                            section: section,
                            onSearch: onSearch,
                            onOpen: onOpen,
                          );
                          if (!layoutEditorMode) return rendered;
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onLongPress: () => _showSectionActions(
                              context,
                              index,
                              section,
                              sections.length,
                            ),
                            child: Stack(
                              children: [
                                rendered,
                                const Positioned(
                                  right: 14,
                                  top: 8,
                                  child: IgnorePointer(
                                    child: Tooltip(
                                      message: 'Maintenir pour modifier',
                                      child: Icon(
                                        Icons.edit_rounded,
                                        size: 17,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        })
                      : [
                          MediaPosterRail(
                            title: 'Popular',
                            items: popular
                                .map(ContentItem.fromManga)
                                .toList(growable: false),
                            onOpen: (index) => onOpen(popular[index]),
                            onSeeAll: () => _openSection(
                              context,
                              source: source,
                              id: 'popular',
                              title: 'Popular',
                              initialItems: popular,
                            ),
                          ),
                          if (latest.isNotEmpty)
                            MediaPosterRail(
                              title: 'Latest',
                              items: latest
                                  .map(ContentItem.fromManga)
                                  .toList(growable: false),
                              onOpen: (index) => onOpen(latest[index]),
                              onSeeAll: () => _openSection(
                                context,
                                source: source,
                                id: 'latest',
                                title: 'Latest',
                                initialItems: latest,
                              ),
                            ),
                        ],
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 112)),
            ],
          ),
        ),
        if (!layoutEditorMode)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: showCompactHeader,
              child: AnimatedOpacity(
                opacity: showCompactHeader ? 0 : 1,
                duration: const Duration(milliseconds: 180),
                child: _ExtensionFeedTopHeader(
                  source: source,
                  onSearch: onSearch,
                  onLibrary: () => context.push('/Library'),
                  onSettings: () =>
                      context.push('/extension_detail', extra: source),
                  transparent: true,
                ),
              ),
            ),
          ),
        if (!layoutEditorMode)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: !showCompactHeader,
              child: AnimatedSlide(
                offset: showCompactHeader ? Offset.zero : const Offset(0, -1),
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: showCompactHeader ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: _ExtensionFeedOverlayHeader(
                    source: source,
                    onSearch: onSearch,
                    onLibrary: () => context.push('/Library'),
                    onSettings: () =>
                        context.push('/extension_detail', extra: source),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    final Widget selectedPage = IndexedStack(
      index: editorDestination.index,
      children: [
        homeFeed,
        ComponentGalleryScreen(
          embedded: true,
          selectionMode: isSelectingComponent,
          selectionContext: selectionContext,
          onSelectLayoutComponent: isSelectingComponent
              ? onSelectLayoutComponent
              : null,
          onClose: () =>
              onEditorDestinationChanged(_LayoutEditorDestination.home),
        ),
        LayoutJsonEditorScreen(
          key: ValueKey(layoutEditorRevision),
          source: source,
          initialContent: layoutEditorInitialContent,
          onSaved: onLayoutJsonSaved,
        ),
      ],
    );
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // L'édition se fait sur la page réelle : aucun chrome supplémentaire,
      // la seule surcouche est le dock flottant en bas à droite.
      body: layoutEditorMode ? selectedPage : homeFeed,
      floatingActionButton: layoutEditorMode
          ? _LayoutEditorDock(
              destination: editorDestination,
              expanded: editorDockExpanded,
              onToggle: onToggleEditorDock,
              onSelect: onEditorDestinationChanged,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

class _LayoutEditorDock extends StatelessWidget {
  final _LayoutEditorDestination destination;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<_LayoutEditorDestination> onSelect;

  const _LayoutEditorDock({
    required this.destination,
    required this.expanded,
    required this.onToggle,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (expanded)
            Material(
              color: colors.surfaceContainerHigh,
              elevation: 8,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _DockDestinationButton(
                      icon: Icons.home_rounded,
                      label: 'Accueil',
                      selected: destination == _LayoutEditorDestination.home,
                      onTap: () => onSelect(_LayoutEditorDestination.home),
                    ),
                    _DockDestinationButton(
                      icon: Icons.widgets_outlined,
                      label: 'Galerie composants',
                      selected: destination == _LayoutEditorDestination.gallery,
                      onTap: () => onSelect(_LayoutEditorDestination.gallery),
                    ),
                    _DockDestinationButton(
                      icon: Icons.data_object_rounded,
                      label: 'Éditeur JSON',
                      selected: destination == _LayoutEditorDestination.json,
                      onTap: () => onSelect(_LayoutEditorDestination.json),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'layout-editor-dock-toggle',
            tooltip: expanded
                ? 'Fermer le dock d\'édition'
                : 'Ouvrir le dock d\'édition',
            onPressed: onToggle,
            // Bouton flottant « < » qui déplie le dock de navigation.
            child: Icon(
              expanded ? Icons.close_rounded : Icons.expand_more_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _DockDestinationButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DockDestinationButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 230,
      child: TextButton.icon(
        onPressed: onTap,
        style: TextButton.styleFrom(
          alignment: Alignment.centerLeft,
          foregroundColor: selected ? colors.primary : colors.onSurface,
          backgroundColor: selected
              ? colors.primary.withValues(alpha: .12)
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        icon: Icon(icon, size: 19),
        label: Text(label),
      ),
    );
  }
}

void _openSection(
  BuildContext context, {
  required Source source,
  required String id,
  required String title,
  List<MManga> initialItems = const [],
  String? cardStyle,
  String? seeAllPage,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TmdbMoviesListScreen.extension(
        source: source,
        sectionId: id,
        title: title,
        initialExtensionItems: initialItems,
        cardStyle: cardStyle,
        seeAllPage: seeAllPage,
      ),
    ),
  );
}

class _ExtensionLayoutSection extends ConsumerStatefulWidget {
  final Source source;
  final UiSection section;
  final VoidCallback onSearch;
  final ValueChanged<MManga> onOpen;

  const _ExtensionLayoutSection({
    required this.source,
    required this.section,
    required this.onSearch,
    required this.onOpen,
  });

  @override
  ConsumerState<_ExtensionLayoutSection> createState() =>
      _ExtensionLayoutSectionState();
}

class _ExtensionLayoutSectionState
    extends ConsumerState<_ExtensionLayoutSection> {
  String? _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = _initialMonth();
  }

  @override
  void didUpdateWidget(covariant _ExtensionLayoutSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section.monthSelector?.initialMonth !=
        widget.section.monthSelector?.initialMonth) {
      _selectedMonth = _initialMonth();
    }
  }

  String _monthKey(DateTime month) =>
      '${month.year}-${month.month.toString().padLeft(2, '0')}';

  DateTime _latestCompletedMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month - 1, 1);
  }

  String _initialMonth() {
    final configured = widget.section.monthSelector?.initialMonth;
    final latest = _latestCompletedMonth();
    final parsed = configured == null
        ? null
        : DateTime.tryParse('$configured-01');
    if (parsed != null && !parsed.isAfter(latest)) return _monthKey(parsed);
    return _monthKey(latest);
  }

  List<String> _monthOptions() {
    final selector = widget.section.monthSelector!;
    final latest = _latestCompletedMonth();
    final count = selector.monthsBack.clamp(1, 120);
    final values = <String>{
      for (var offset = 0; offset < count; offset++)
        _monthKey(DateTime(latest.year, latest.month - offset, 1)),
      _selectedMonth ?? _initialMonth(),
    }.toList()..sort((a, b) => b.compareTo(a));
    return values;
  }

  String _monthLabel(String monthKey) {
    final date = DateTime.tryParse('$monthKey-01');
    if (date == null) return monthKey;
    const names = [
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre',
    ];
    final name = names[date.month - 1];
    return '${name[0].toUpperCase()}${name.substring(1)} ${date.year}';
  }

  String get _listId {
    final selector = widget.section.monthSelector;
    if (selector == null) return widget.section.id;
    return '${selector.listIdPrefix}${_selectedMonth ?? _initialMonth()}';
  }

  String get _title {
    final base = widget.section.title?.trim().isNotEmpty == true
        ? widget.section.title!.trim()
        : widget.section.id;
    return base.replaceAll(
      '{month}',
      _monthLabel(_selectedMonth ?? _initialMonth()),
    );
  }

  Widget _withMonthSelector(BuildContext context, Widget child) {
    final selector = widget.section.monthSelector;
    if (selector == null) return child;
    final selected = _selectedMonth ?? _initialMonth();
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppUI.pagePadding(context),
            0,
            AppUI.pagePadding(context),
            8,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF171820) : cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: .10)
                    : cs.outlineVariant,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  color: cs.onSurfaceVariant,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Choisir un mois',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selected,
                    dropdownColor: isDark
                        ? const Color(0xFF20212A)
                        : cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    items: [
                      for (final month in _monthOptions())
                        DropdownMenuItem(
                          value: month,
                          child: Text(_monthLabel(month)),
                        ),
                    ],
                    onChanged: (month) {
                      if (month == null || month == _selectedMonth) return;
                      setState(() => _selectedMonth = month);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }

  void _openItem(BuildContext context, MManga item) {
    final previewUrl = item.previewUrl?.trim() ?? '';
    if (widget.source.touchToPreview && previewUrl.isNotEmpty) {
      unawaited(
        showExtensionVideoPreview(
          context: context,
          item: item,
          previewUrl: previewUrl,
          onOpen: () => widget.onOpen(item),
        ),
      );
      return;
    }
    widget.onOpen(item);
  }

  @override
  Widget build(BuildContext context) {
    final content = switch (widget.section.params['dataSource'] ??
        widget.section.id) {
      'popular' => ref.watch(
        getPopularProvider(source: widget.source, page: 1),
      ),
      'latest' => ref.watch(
        getLatestUpdatesProvider(source: widget.source, page: 1),
      ),
      _ => ref.watch(
        getCustomListProvider(source: widget.source, listId: _listId, page: 1),
      ),
    };

    // Riverpod can expose a loading/error state while retaining the previous
    // value during refresh. Always render that value first so a carousel or
    // rail does not disappear just because another page is being fetched.
    final cachedItems = content.value?.list;
    if (cachedItems != null && cachedItems.isNotEmpty) {
      return _withMonthSelector(context, _buildSection(context, cachedItems));
    }

    final sectionContent = content.when(
      loading: () => _ExtensionLayoutSectionLoading(
        title: _title,
        component: widget.section.component,
      ),
      error: (error, _) => _ExtensionLayoutSectionError(
        title: _title,
        error: error,
        onRetry: _retry,
      ),
      data: (pages) {
        final items = pages?.list ?? const <MManga>[];
        if (items.isEmpty) {
          return _ExtensionLayoutSectionEmpty(title: _title, onRetry: _retry);
        }
        return _buildSection(context, items);
      },
    );
    return _withMonthSelector(context, sectionContent);
  }

  void _retry() {
    extensionPageCache.invalidateSource(widget.source);
    switch (widget.section.id) {
      case 'popular':
        ref.invalidate(getPopularProvider(source: widget.source, page: 1));
        break;
      case 'latest':
        ref.invalidate(
          getLatestUpdatesProvider(source: widget.source, page: 1),
        );
        break;
      default:
        ref.invalidate(
          getCustomListProvider(
            source: widget.source,
            listId: _listId,
            page: 1,
          ),
        );
    }
  }

  Widget _buildSection(BuildContext context, List<MManga> items) {
    final onSeeAll = () => _openSection(
      context,
      source: widget.source,
      id: _listId,
      title: _title,
      initialItems: items,
      cardStyle: widget.section.cardStyle,
      seeAllPage: widget.section.seeAllPage,
    );
    final sectionAction = widget.section.seeAll ? onSeeAll : null;
    // Three-dot overflow: same bulk-download entries as the "voir tout" page
    // (Télécharger, Tout télécharger, Télécharger 5/10/25…), so a section can
    // be queued straight from the home feed.
    final trailing = AdaptiveOverlayMenu<CatalogBulkDownloadAction>(
      tooltip: 'Options',
      icon: const Icon(Broken.more_2, size: 22),
      menuWidth: 240,
      onSelected: (action) => CatalogBulkDownload.handleMenu(
        context,
        ref,
        widget.source,
        items,
        action,
      ),
      itemBuilder: (_) => CatalogBulkDownload.menuItems(),
    );

    return ExtensionLayoutPreview(
      title: _title,
      component: widget.section.component,
      source: widget.source,
      items: items,
      onOpen: (item) => _openItem(context, item),
      onSeeAll: sectionAction,
      columns: widget.section.columns,
      rows: widget.section.rows,
      cardStyle: widget.section.cardStyle,
      cardComponent: widget.section.cardComponent,
      episodeComponent: widget.section.episodeComponent,
      chapterComponent: widget.section.chapterComponent,
      gridOrder: widget.section.gridOrder,
      scrollDirection: widget.section.scrollDirection,
      params: widget.section.params,
      trailing: trailing,
    );
  }
}

/// Shared renderer for an extension section.
///
/// The home screen uses this same entry point after loading its provider data.
/// The component gallery can therefore document the real extension layouts
/// without maintaining a second visual implementation.
class ExtensionLayoutPreview extends StatelessWidget {
  static final Set<String> _warnedUnsupportedComponentIds = <String>{};

  const ExtensionLayoutPreview({
    required this.title,
    required this.component,
    required this.items,
    required this.source,
    required this.onOpen,
    this.onSeeAll,
    this.columns,
    this.rows,
    this.cardStyle,
    this.cardComponent,
    this.episodeComponent,
    this.chapterComponent,
    this.gridOrder,
    this.scrollDirection,
    this.params = const {},
    this.trailing,
    super.key,
  });

  final String title;
  final String component;
  final List<MManga> items;
  final Source source;
  final ValueChanged<MManga> onOpen;
  final VoidCallback? onSeeAll;
  final int? columns;
  final int? rows;
  final String? cardStyle;
  final String? cardComponent;
  final String? episodeComponent;
  final String? chapterComponent;
  final String? gridOrder;
  final String? scrollDirection;
  final Map<String, dynamic> params;

  /// Three-dot overflow control shown at the right end of the section header.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final contentItems = items
        .map(ContentItem.fromManga)
        .toList(growable: false);
    final definition = LayoutComponentRegistry.resolve(component);
    if (definition == null ||
        !definition.supportedContexts.contains(LayoutComponentContext.home)) {
      if (_warnedUnsupportedComponentIds.add(component)) {
        debugPrint(
          '[ExtensionLayoutPreview] Unsupported component "$component"; '
          'using poster rail fallback.',
        );
      }
      return MediaPosterRail(
        title: title,
        items: contentItems,
        onOpen: (index) => onOpen(items[index]),
        onSeeAll: onSeeAll,
      );
    }

    final selectedCardComponent = cardComponent;
    final mangaCardComponent =
        source.itemType == ItemType.manga &&
            selectedCardComponent != null &&
            LayoutComponentRegistry.supports(
              selectedCardComponent,
              LayoutComponentContext.homeMangaCard,
            )
        ? selectedCardComponent
        : null;
    if (cardComponent != null && mangaCardComponent == null) {
      debugPrint(
        '[ExtensionLayoutPreview] Unsupported Manga card "$cardComponent"; '
        'using the default grid card.',
      );
    }

    final selectedEpisodeComponent = episodeComponent;
    final episodeCardComponent =
        source.itemType == ItemType.anime &&
            selectedEpisodeComponent != null &&
            LayoutComponentRegistry.supports(
              selectedEpisodeComponent,
              LayoutComponentContext.homeEpisodeCard,
            )
        ? selectedEpisodeComponent
        : null;
    if (episodeComponent != null && episodeCardComponent == null) {
      debugPrint(
        '[ExtensionLayoutPreview] Unsupported episode card '
        '"$episodeComponent"; using the default grid card.',
      );
    }

    final selectedChapterComponent = chapterComponent;
    final chapterCardComponent =
        source.itemType == ItemType.manga &&
            selectedChapterComponent != null &&
            LayoutComponentRegistry.supports(
              selectedChapterComponent,
              LayoutComponentContext.chapter,
            )
        ? selectedChapterComponent
        : null;
    if (chapterComponent != null && chapterCardComponent == null) {
      debugPrint(
        '[ExtensionLayoutPreview] Unsupported chapter card '
        '"$chapterComponent"; using the default grid card.',
      );
    }

    final episodeCards = episodeCardComponent == null
        ? const <_ExtensionEpisodeCardItem>[]
        : _buildEpisodeCardItems();
    final episodeCardsByKey = {
      for (final episode in episodeCards) episode.contentItem.key: episode,
    };
    final chapterCards = chapterCardComponent == null
        ? const <_ExtensionChapterCardItem>[]
        : _buildChapterCardItems();
    final chapterCardsByKey = {
      for (final chapter in chapterCards) chapter.contentItem.key: chapter,
    };
    late final List<ContentItem> gridItems;
    if (episodeCardComponent != null) {
      gridItems = episodeCards
          .map((episode) => episode.contentItem)
          .toList(growable: false);
    } else if (chapterCardComponent != null) {
      gridItems = chapterCards
          .map((chapter) => chapter.contentItem)
          .toList(growable: false);
    } else {
      gridItems = contentItems;
    }

    if (episodeCardComponent != null &&
        definition.renderer == LayoutComponentRenderer.grid &&
        episodeCards.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: title),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppUI.pagePadding(context),
            ),
            child: Text(
              'Aucun épisode numéroté avec une URL valide n’a été fourni par cette source.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    }

    if (chapterCardComponent != null &&
        definition.renderer == LayoutComponentRenderer.grid &&
        chapterCards.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: title),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppUI.pagePadding(context),
            ),
            child: Text(
              'Aucun chapitre avec un titre et une URL valides n’a été fourni par cette source.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    }

    Widget Function(BuildContext, ContentItem, double, VoidCallback)?
    gridCardBuilder;
    if (episodeCardComponent != null) {
      gridCardBuilder = (context, item, width, onTap) {
        final episode = episodeCardsByKey[item.key];
        if (episode == null) {
          return PosterCard(item: item, width: width, onTap: onTap);
        }
        return ExtensionEpisodeCardAdapter.build(
          series: episode.series,
          episode: episode.chapter,
          episodeNumber: episode.number,
          width: width,
          onTap: () => onOpen(episode.series),
        );
      };
    } else if (chapterCardComponent != null) {
      gridCardBuilder = (context, item, width, onTap) {
        final chapter = chapterCardsByKey[item.key];
        if (chapter == null) {
          return PosterCard(item: item, width: width, onTap: onTap);
        }
        return ExtensionChapterCardAdapter.build(
          manga: chapter.manga,
          chapter: chapter.chapter,
          width: width,
          onTap: () => onOpen(chapter.manga),
        );
      };
    } else if (mangaCardComponent != null) {
      gridCardBuilder = (context, item, width, onTap) =>
          MangaHomeCardAdapter.build(
            component: mangaCardComponent,
            item: item,
            width: width,
            onTap: onTap,
          ) ??
          PosterCard(item: item, width: width, onTap: onTap);
    }

    // Gallery components are data-bound through the shared renderer so both
    // home screens can select any card documented by the developer gallery.
    if (definition.galleryFamily != null) {
      final scoped = GalleryComponentContext(
        componentId: component,
        items: contentItems,
        title: title,
        params: {
          ...params,
          if (columns != null) 'columns': columns,
          if (rows != null) 'rows': rows,
          if (scrollDirection != null) 'layout': scrollDirection,
        },
        onOpen: (index) => onOpen(items[index]),
        onSeeAll: onSeeAll,
        trailing: trailing,
      );
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: GalleryComponentRenderer.section(scoped),
      );
    }

    return switch (definition.renderer) {
      LayoutComponentRenderer.spotlight => MediaHeroCarousel(
        items: contentItems,
        onOpen: (index) => onOpen(items[index]),
      ),
      LayoutComponentRenderer.banner => MediaBannerRail(
        title: title,
        items: contentItems,
        onOpen: (index) => onOpen(items[index]),
        onSeeAll: onSeeAll,
        trailing: trailing,
      ),
      LayoutComponentRenderer.ranked => MediaRankedRail(
        title: title,
        items: contentItems.take(20).toList(growable: false),
        onOpen: (index) => onOpen(items[index]),
        onSeeAll: onSeeAll,
      ),
      LayoutComponentRenderer.landscape => MediaLandscapeRail(
        title: title,
        items: contentItems,
        onOpen: (index) => onOpen(items[index]),
        onSeeAll: onSeeAll,
        trailing: trailing,
      ),
      LayoutComponentRenderer.grid => MediaGridSection(
        title: title,
        items: gridItems,
        trailing: trailing,
        onOpen: (index) {
          if (episodeCardComponent != null) {
            onOpen(episodeCards[index].series);
          } else if (chapterCardComponent != null) {
            onOpen(chapterCards[index].manga);
          } else {
            onOpen(items[index]);
          }
        },
        columns: columns,
        rows: rows,
        scrollDirection: scrollDirection,
        cardStyle: cardStyle,
        onSeeAll: episodeCardComponent == null && chapterCardComponent == null
            ? onSeeAll
            : null,
        itemCardBuilder: gridCardBuilder,
      ),
      LayoutComponentRenderer.collections => _ExtensionCollectionCardRail(
        title: title,
        items: items,
        onOpen: onOpen,
        onSeeAll: onSeeAll,
      ),
      LayoutComponentRenderer.posterRail => MediaPosterRail(
        title: title,
        items: contentItems,
        onOpen: (index) => onOpen(items[index]),
        onSeeAll: onSeeAll,
        trailing: trailing,
      ),
      LayoutComponentRenderer.mangaFeaturedCard => MediaPosterRail(
        title: title,
        items: contentItems,
        onOpen: (index) => onOpen(items[index]),
        onSeeAll: onSeeAll,
      ),
      LayoutComponentRenderer.mangaChapterCard => MediaPosterRail(
        title: title,
        items: contentItems,
        onOpen: (index) => onOpen(items[index]),
        onSeeAll: onSeeAll,
      ),
      LayoutComponentRenderer.homeEpisodeCard => MediaPosterRail(
        title: title,
        items: contentItems,
        onOpen: (index) => onOpen(items[index]),
        onSeeAll: onSeeAll,
      ),
      LayoutComponentRenderer.chapterCard => MediaPosterRail(
        title: title,
        items: contentItems,
        onOpen: (index) => onOpen(items[index]),
        onSeeAll: onSeeAll,
      ),
    };
  }

  List<_ExtensionEpisodeCardItem> _buildEpisodeCardItems() {
    final result = <_ExtensionEpisodeCardItem>[];
    for (final series in items) {
      final seriesName = series.name?.trim();
      final seriesLink = series.link?.trim();
      if (seriesName == null ||
          seriesName.isEmpty ||
          seriesLink == null ||
          seriesLink.isEmpty) {
        continue;
      }

      for (final chapter in series.chapters ?? const <MChapter>[]) {
        final episodeName = chapter.name?.trim();
        final episodeUrl = chapter.url?.trim();
        final episodeNumber = ExtensionEpisodeCardAdapter.parseEpisodeNumber(
          episodeName,
        );
        if (episodeName == null ||
            episodeName.isEmpty ||
            episodeUrl == null ||
            episodeUrl.isEmpty ||
            episodeNumber == null) {
          continue;
        }

        final contentItem = ContentItem(
          key: 'extension-episode-${result.length}',
          title: episodeName,
          posterUrl: chapter.thumbnailUrl,
          backdropUrl: series.previewUrl ?? series.imageUrl,
          description: chapter.description,
        );
        result.add(
          _ExtensionEpisodeCardItem(
            series: series,
            chapter: chapter,
            number: episodeNumber,
            contentItem: contentItem,
          ),
        );
      }
    }
    return result;
  }

  List<_ExtensionChapterCardItem> _buildChapterCardItems() {
    final result = <_ExtensionChapterCardItem>[];
    for (final manga in items) {
      final mangaName = manga.name?.trim();
      final mangaLink = manga.link?.trim();
      if (mangaName == null ||
          mangaName.isEmpty ||
          mangaLink == null ||
          mangaLink.isEmpty) {
        continue;
      }

      for (final chapter in manga.chapters ?? const <MChapter>[]) {
        final chapterName = chapter.name?.trim();
        final chapterUrl = chapter.url?.trim();
        if (chapterName == null ||
            chapterName.isEmpty ||
            chapterUrl == null ||
            chapterUrl.isEmpty) {
          continue;
        }

        final contentItem = ContentItem(
          key: 'extension-chapter-${result.length}',
          title: chapterName,
          posterUrl: chapter.thumbnailUrl,
          backdropUrl: manga.imageUrl,
          description: chapter.description,
        );
        result.add(
          _ExtensionChapterCardItem(
            manga: manga,
            chapter: chapter,
            contentItem: contentItem,
          ),
        );
      }
    }
    return result;
  }
}

class _ExtensionEpisodeCardItem {
  const _ExtensionEpisodeCardItem({
    required this.series,
    required this.chapter,
    required this.number,
    required this.contentItem,
  });

  final MManga series;
  final MChapter chapter;
  final int number;
  final ContentItem contentItem;
}

class _ExtensionChapterCardItem {
  const _ExtensionChapterCardItem({
    required this.manga,
    required this.chapter,
    required this.contentItem,
  });

  final MManga manga;
  final MChapter chapter;
  final ContentItem contentItem;
}

class _ExtensionLayoutSectionLoading extends StatelessWidget {
  final String title;
  final String component;

  const _ExtensionLayoutSectionLoading({
    required this.title,
    required this.component,
  });

  @override
  Widget build(BuildContext context) {
    final preview =
        LayoutComponentRegistry.resolve(component)?.loadingPreview ??
        LayoutComponentLoadingPreview.row;
    final titleWidth = title.length.clamp(86, 180).toDouble();

    return switch (preview) {
      LayoutComponentLoadingPreview.hero => AppHeroShimmer(
        height: (MediaQuery.sizeOf(context).height * .56).clamp(480.0, 590.0),
      ),
      LayoutComponentLoadingPreview.ranked => _ExtensionSkeletonSection(
        titleWidth: titleWidth,
        child: const _ExtensionRankedWideShimmer(),
      ),
      LayoutComponentLoadingPreview.landscape => _ExtensionSkeletonSection(
        titleWidth: titleWidth,
        child: const _ExtensionShowcaseShimmer(),
      ),
      LayoutComponentLoadingPreview.collections => _ExtensionSkeletonSection(
        titleWidth: titleWidth,
        child: const ExtensionCollectionCardShimmer(),
      ),
      LayoutComponentLoadingPreview.grid => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: title),
          const SizedBox(height: 250, child: AppMediaGridShimmer()),
        ],
      ),
      LayoutComponentLoadingPreview.categoryPills => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: title),
          SizedBox(
            height: 58,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(
                horizontal: AppUI.pagePadding(context),
              ),
              scrollDirection: Axis.horizontal,
              itemCount: 7,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, _) => const SizedBox(
                width: 84,
                height: 32,
                child: AppShimmerBlock(radius: 18),
              ),
            ),
          ),
        ],
      ),
      LayoutComponentLoadingPreview.row => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: title),
          const SizedBox(height: 220, child: AppMediaRowShimmer()),
        ],
      ),
    };
  }
}

class _ExtensionLayoutSectionError extends StatelessWidget {
  final String title;
  final Object error;
  final VoidCallback onRetry;

  const _ExtensionLayoutSectionError({
    required this.title,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppUI.pagePadding(context),
        4,
        AppUI.pagePadding(context),
        10,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: .035)
              : cs.onSurface.withValues(alpha: .045),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: .09)
                : cs.onSurface.withValues(alpha: .10),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_off_rounded, color: cs.error, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${extensionErrorTitle(error)} · $title',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    extensionRequestFailureMessage(error) ??
                        'La source est momentanément indisponible.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Réessayer',
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              color: cs.primary,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtensionLayoutSectionEmpty extends StatelessWidget {
  final String title;
  final VoidCallback onRetry;

  const _ExtensionLayoutSectionEmpty({
    required this.title,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    // Same shape as a populated section (heading + content) so an empty
    // "Historique" reads like the other sections. The glyph is a kaomoji
    // rather than the shared Lottie: inside a rail it only needs to say
    // "nothing here", and text stays sharp and cheap where the animation
    // would dominate the row.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title: title),
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppUI.pagePadding(context),
            4,
            AppUI.pagePadding(context),
            18,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const KaomojiEmpty(
                  kaomoji: '(´・ω・`)',
                  size: 22,
                  message: 'Aucun contenu',
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Réessayer'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ExtensionFeedTopHeader extends StatelessWidget {
  final Source source;
  final VoidCallback onSearch;
  final VoidCallback onLibrary;
  final VoidCallback onSettings;
  final bool transparent;
  final bool showSearch;

  const _ExtensionFeedTopHeader({
    required this.source,
    required this.onSearch,
    required this.onLibrary,
    required this.onSettings,
    this.transparent = false,
    this.showSearch = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: transparent ? Colors.transparent : cs.surface,
      elevation: transparent ? 0 : 1,
      shadowColor: Colors.black.withValues(alpha: .12),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppUI.pagePadding(context),
            ),
            child: Row(
              children: [
                _ExtensionSourceIcon(source: source, size: 30),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    source.name?.trim().isNotEmpty == true
                        ? source.name!.trim()
                        : 'Extension',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (showSearch)
                  _ExtensionIconButton(
                    icon: Broken.search_normal,
                    onPressed: onSearch,
                    tooltip: 'Rechercher',
                  ),
                _ExtensionIconButton(
                  icon: Broken.bookmark,
                  onPressed: onLibrary,
                  tooltip: 'Library',
                ),
                _ExtensionIconButton(
                  icon: Broken.setting_2,
                  onPressed: onSettings,
                  tooltip: 'Paramètres de l’extension',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExtensionFeedOverlayHeader extends StatelessWidget {
  final Source source;
  final VoidCallback onSearch;
  final VoidCallback onLibrary;
  final VoidCallback onSettings;
  final bool transparent;

  const _ExtensionFeedOverlayHeader({
    required this.source,
    required this.onSearch,
    required this.onLibrary,
    required this.onSettings,
    this.transparent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: transparent ? Colors.transparent : const Color(0xFF0B0B11),
      elevation: transparent ? 0 : 1,
      shadowColor: Colors.black.withValues(alpha: .12),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 58,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppUI.pagePadding(context),
            ),
            child: Row(
              children: [
                _ExtensionSourceIcon(source: source, size: 28),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    source.name?.trim().isNotEmpty == true
                        ? source.name!.trim()
                        : 'Extension',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Rechercher',
                  onPressed: onSearch,
                  icon: const Icon(Broken.search_normal),
                ),
                IconButton(
                  tooltip: 'Library',
                  onPressed: onLibrary,
                  icon: const Icon(Broken.bookmark),
                ),
                IconButton(
                  tooltip: 'Paramètres de l’extension',
                  onPressed: onSettings,
                  icon: const Icon(Broken.setting_2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExtensionCollectionCardRail extends StatelessWidget {
  final String title;
  final List<MManga> items;
  final ValueChanged<MManga> onOpen;
  final VoidCallback? onSeeAll;

  const _ExtensionCollectionCardRail({
    required this.title,
    required this.items,
    required this.onOpen,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: title,
          actionLabel: 'All >',
          onAction: onSeeAll,
        ),
        SizedBox(
          height: 112,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: AppUI.pagePadding(context),
            ),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, index) => _ExtensionCollectionCard(
              item: items[index],
              onTap: () => onOpen(items[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExtensionCollectionCard extends StatelessWidget {
  final MManga item;
  final VoidCallback onTap;

  const _ExtensionCollectionCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isPlaylist =
        item.collectionId?.startsWith('playlist_') == true ||
        ExtensionCollectionRoute.fromItem(
              item,
            )?.listId.startsWith('playlist_') ==
            true;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 190,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            colors: isPlaylist
                ? const [Color(0xFF303A70), Color(0xFF5964C8)]
                : const [Color(0xFF174C50), Color(0xFF237F78)],
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (item.imageUrl?.trim().isNotEmpty == true)
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 84,
                  child: _ExtensionImage(
                    url: item.imageUrl,
                    fit: BoxFit.cover,
                    radius: 0,
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 132,
                padding: const EdgeInsets.fromLTRB(12, 12, 9, 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      (isPlaylist
                              ? const Color(0xFF5964C8)
                              : const Color(0xFF237F78))
                          .withValues(alpha: .98),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isPlaylist
                          ? Icons.playlist_play_rounded
                          : Icons.local_offer_rounded,
                      color: Colors.white70,
                      size: 19,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.name?.trim().isNotEmpty == true
                          ? item.name!.trim()
                          : 'Collection',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtensionImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  final double radius;

  const _ExtensionImage({
    required this.url,
    this.fit = BoxFit.cover,
    this.radius = AppUI.cardRadius,
  });

  @override
  Widget build(BuildContext context) =>
      ContentImage(url: url, fit: fit, radius: radius);
}

class _ExtensionSourceIcon extends StatelessWidget {
  final Source source;
  final double size;

  const _ExtensionSourceIcon({required this.source, required this.size});

  @override
  Widget build(BuildContext context) {
    final url = source.iconUrl?.trim() ?? '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * .28),
      child: SizedBox(
        width: size,
        height: size,
        child: url.isEmpty
            ? const ColoredBox(
                color: Color(0xFF263238),
                child: Icon(Icons.extension_rounded, color: Colors.white70),
              )
            : cachedNetworkImage(
                imageUrl: url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorWidget: const ColoredBox(
                  color: Color(0xFF263238),
                  child: Icon(Icons.extension_rounded, color: Colors.white70),
                ),
              ),
      ),
    );
  }
}

class _ExtensionIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  const _ExtensionIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: .22),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _ExtensionHomeLoading extends StatelessWidget {
  final Source source;
  final VoidCallback onSearch;
  final Future<void> Function() onRefresh;

  const _ExtensionHomeLoading({
    required this.source,
    required this.onSearch,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: ExtensionAppleRefreshable(
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ExtensionFeedTopHeader(
                source: source,
                onSearch: onSearch,
                onLibrary: () => context.push('/Library'),
                onSettings: () =>
                    context.push('/extension_detail', extra: source),
              ),
              AppHeroShimmer(
                height: (MediaQuery.sizeOf(context).height * .56).clamp(
                  480.0,
                  590.0,
                ),
              ),
              _ExtensionSkeletonSection(
                titleWidth: 154,
                child: const _ExtensionRankedWideShimmer(),
              ),
              _ExtensionSkeletonSection(
                titleWidth: 112,
                child: const _ExtensionShowcaseShimmer(),
              ),
              _ExtensionSkeletonSection(
                titleWidth: 126,
                child: const ExtensionCollectionCardShimmer(),
              ),
              _ExtensionSkeletonSection(
                titleWidth: 94,
                child: SizedBox(height: 206, child: AppLandscapeRowShimmer()),
              ),
              const SizedBox(height: 112),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExtensionRankedWideShimmer extends StatelessWidget {
  const _ExtensionRankedWideShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < 4; index++)
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppUI.pagePadding(context),
              index == 0 ? 4 : 0,
              AppUI.pagePadding(context),
              12,
            ),
            child: SizedBox(
              height: 88,
              child: Row(
                children: [
                  const SizedBox(
                    width: 156,
                    height: 88,
                    child: AppShimmerBlock(radius: 12),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: SizedBox(
                      height: 38,
                      child: AppShimmerBlock(radius: 6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 32,
                    height: 38,
                    child: AppShimmerBlock(radius: 6),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ExtensionShowcaseShimmer extends StatelessWidget {
  const _ExtensionShowcaseShimmer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppUI.pagePadding(context)),
      child: SizedBox(
        height: 202,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1B21),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                const Expanded(
                  child: Row(
                    children: [
                      SizedBox(width: 92, child: AppShimmerBlock(radius: 10)),
                      SizedBox(width: 10),
                      Expanded(child: AppShimmerBlock(radius: 10)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Expanded(
                      child: SizedBox(
                        height: 18,
                        child: AppShimmerBlock(radius: 5),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 84,
                      height: 38,
                      child: AppShimmerBlock(radius: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ExtensionCollectionCardShimmer extends StatelessWidget {
  const ExtensionCollectionCardShimmer();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: AppUI.pagePadding(context)),
        scrollDirection: Axis.horizontal,
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, _) => const SizedBox(
          width: 190,
          height: 112,
          child: AppShimmerBlock(radius: 15),
        ),
      ),
    );
  }
}

class _ExtensionSkeletonSection extends StatelessWidget {
  final double titleWidth;
  final Widget child;

  const _ExtensionSkeletonSection({
    required this.titleWidth,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
            child: SizedBox(
              width: titleWidth,
              height: 16,
              child: const AppShimmerBlock(radius: 5),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _ExtensionEmpty extends StatelessWidget {
  final Source source;
  final Future<void> Function() onRefresh;
  final Object? error;

  const _ExtensionEmpty({
    required this.source,
    required this.onRefresh,
    this.error,
  });

  @override
  Widget build(BuildContext context) => ExtensionHomeEmptyState(
    onRetry: onRefresh,
    onRefresh: onRefresh,
    error: error,
    challengeUrl: source.baseUrl,
    sourceId: source.id,
    header: _ExtensionFeedTopHeader(
      source: source,
      onSearch: () {},
      onLibrary: () => context.push('/Library'),
      onSettings: () => context.push('/extension_detail', extra: source),
      showSearch: false,
    ),
  );
}

class _ExtensionSearchView extends ConsumerStatefulWidget {
  final Source source;
  final VoidCallback onClose;
  final ValueChanged<MManga> onOpen;

  const _ExtensionSearchView({
    required this.source,
    required this.onClose,
    required this.onOpen,
  });

  @override
  ConsumerState<_ExtensionSearchView> createState() =>
      _ExtensionSearchViewState();
}

class _ExtensionSearchViewState extends ConsumerState<_ExtensionSearchView> {
  final _controller = TextEditingController();
  String _submittedQuery = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _submittedQuery = query);
  }

  @override
  Widget build(BuildContext context) {
    final result = _submittedQuery.isEmpty
        ? null
        : ref.watch(
            searchProvider(
              source: widget.source,
              query: _submittedQuery,
              page: 1,
              filterList: const [],
            ),
          );

    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        leading: IconButton(
          onPressed: widget.onClose,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _submit(),
          style: TextStyle(color: cs.onSurface),
          decoration: InputDecoration(
            hintText: 'Rechercher dans ${widget.source.name ?? 'l’extension'}',
            border: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _submit,
            tooltip: 'Rechercher',
            icon: const Icon(Broken.search_normal),
          ),
        ],
      ),
      body: _submittedQuery.isEmpty
          ? Center(
              child: Text(
                'Recherchez une vidéo dans cette extension',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            )
          : result!.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        color: cs.onSurfaceVariant,
                        size: 44,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        extensionErrorTitle(error),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        extensionRequestFailureMessage(error) ?? '',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: () {
                          ref.invalidate(
                            searchProvider(
                              source: widget.source,
                              query: _submittedQuery,
                              page: 1,
                              filterList: const [],
                            ),
                          );
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (pages) {
                final items = pages?.list ?? const <MManga>[];
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      'Aucun résultat',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 150,
                    mainAxisExtent: 215,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, index) => MangaImageCardWidget(
                    source: widget.source,
                    itemType: widget.source.itemType,
                    getMangaDetail: items[index],
                    isComfortableGrid: false,
                  ),
                );
              },
            ),
    );
  }
}
