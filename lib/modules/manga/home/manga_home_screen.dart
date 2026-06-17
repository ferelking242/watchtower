import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/eval/model/m_pages.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/anti_bot/cloudflare_error_widget.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/library/providers/library_state_provider.dart';
import 'package:watchtower/modules/manga/home/providers/state_provider.dart';
import 'package:watchtower/modules/manga/home/widget/filter_widget.dart';
import 'package:watchtower/modules/widgets/listview_widget.dart';
import 'package:watchtower/modules/widgets/progress_center.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/services/get_custom_list.dart';
import 'package:watchtower/services/get_custom_lists.dart';
import 'package:watchtower/services/get_filter_list.dart';
import 'package:watchtower/services/get_latest_updates.dart';
import 'package:watchtower/services/get_popular.dart';
import 'package:watchtower/services/get_source_baseurl.dart';
import 'package:watchtower/services/search.dart';
import 'package:watchtower/services/supports_latest.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';
import 'package:watchtower/modules/library/widgets/search_text_form_field.dart';
import 'package:watchtower/modules/manga/home/widget/mangas_card_selector.dart';
import 'package:watchtower/modules/widgets/error_text.dart';
import 'package:watchtower/modules/widgets/gridview_widget.dart';
import 'package:watchtower/modules/widgets/manga_image_card_widget.dart';
import 'package:watchtower/utils/arrow_popup_menu.dart';
import 'package:watchtower/utils/global_style.dart';
import 'package:watchtower/utils/item_type_localization.dart';
import 'package:marquee/marquee.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:flutter_popup/flutter_popup.dart';

enum _HomeMenuAction { openBrowser, cookies, settings, diagnostic }

class MangaHomeScreen extends ConsumerStatefulWidget {
  final Source source;
  final bool isSearch;
  final bool isLatest;
  final String query;
  const MangaHomeScreen({
    required this.source,
    this.query = "",
    this.isSearch = false,
    this.isLatest = false,
    super.key,
  });

  @override
  ConsumerState<MangaHomeScreen> createState() => _MangaHomeScreenState();
}

class TypeMangaSelector {
  final IconData icon;
  final String title;
  TypeMangaSelector(this.icon, this.title);
}

class _MangaHomeScreenState extends ConsumerState<MangaHomeScreen> {
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();
  int _fullDataLength = 50;
  int _page = 1;
  bool _hasNextPage = true;
  late int _selectedIndex = widget.isLatest
      ? 1
      : widget.isSearch
      ? 2
      : 0;
  late Source source = widget.source;
  late bool isLocal = source.name == "local" && source.lang == "";
  late List<dynamic> filters = isLocal ? [] : getFilterList(source: source);
  final List<MManga> _mangaList = [];

  // Extra browse tabs declared by the extension (e.g. Films, Séries TV …)
  late final List<Map<String, dynamic>> _customLists =
      isLocal ? [] : getCustomLists(source: source);

  // Index 0=Popular 1=Latest 2=Filter 3+=custom lists
  static const _kPopularIdx = 0;
  static const _kLatestIdx = 1;
  static const _kFilterIdx = 2;
  static const _kCustomBase = 3;

  String? get _activeCustomListId {
    if (_selectedIndex >= _kCustomBase && !isLocal) {
      final cIdx = _selectedIndex - _kCustomBase;
      if (cIdx < _customLists.length) {
        return _customLists[cIdx]['id'] as String?;
      }
    }
    return null;
  }

  List<TypeMangaSelector> _types(BuildContext context) {
    final l10n = l10nLocalizations(context)!;
    return [
      TypeMangaSelector(Icons.favorite, l10n.popular),
      TypeMangaSelector(Icons.new_releases_outlined, l10n.latest),
      TypeMangaSelector(Icons.filter_list_outlined, l10n.filter),
      ..._customLists.map(
        (cl) => TypeMangaSelector(
          Icons.category_outlined,
          cl['name'] as String? ?? cl['id'] as String,
        ),
      ),
    ];
  }

  Future<MPages?> _loadMore() async {
    MPages? mangaRes;
    if (_isLoading) {
      if (source.isFullData!) {
        await Future.delayed(const Duration(milliseconds: 500));
        _fullDataLength = _fullDataLength + 50;
      } else {
        final customId = _activeCustomListId;
        if (_selectedIndex == _kPopularIdx && !_isSearch && _query.isEmpty) {
          mangaRes = await ref.watch(
            getPopularProvider(source: source, page: _page + 1).future,
          );
        } else if (_selectedIndex == _kLatestIdx && !_isSearch && _query.isEmpty) {
          mangaRes = await ref.watch(
            getLatestUpdatesProvider(source: source, page: _page + 1).future,
          );
        } else if (_selectedIndex == _kFilterIdx &&
            (_isSearch && _query.isNotEmpty) || _isFiltering) {
          mangaRes = await ref.watch(
            searchProvider(
              source: source,
              query: _query,
              page: _page + 1,
              filterList: filters,
            ).future,
          );
        } else if (customId != null) {
          mangaRes = await ref.watch(
            getCustomListProvider(
              source: source,
              listId: customId,
              page: _page + 1,
            ).future,
          );
        }
      }
      if (mangaRes != null && mangaRes.list.isNotEmpty) {
        if (mounted) {
          setState(() {
            _page = _page + 1;
            _hasNextPage = mangaRes!.hasNextPage;
          });
        }
      }
    }

    return mangaRes;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textEditingController.dispose();
    super.dispose();
  }

  late final _textEditingController = TextEditingController(text: widget.query);
  late String _query = widget.query;
  late bool _isSearch = widget.isSearch;

  Future<void> _handleHomeMenuAction(
      BuildContext ctx, _HomeMenuAction action) async {
    switch (action) {
      case _HomeMenuAction.openBrowser:
        final baseUrl = ref.read(sourceBaseUrlProvider(source: source));
        ctx.push('/mangawebview', extra: {
          'url': baseUrl,
          'sourceId': source.id.toString(),
          'title': '',
        });
      case _HomeMenuAction.cookies:
        ctx.push('/extension-cookies');
      case _HomeMenuAction.settings:
        final res = await ctx.push('/extension_detail', extra: source);
        if (res != null && mounted) setState(() => source = res as Source);
      case _HomeMenuAction.diagnostic:
        ctx.push('/extensionDiagnostic', extra: source.itemType);
    }
  }
  AsyncValue<MPages?>? _getManga;
  int _length = 0;
  bool _isFiltering = false;
  late final supportsLatest = isLocal
      ? true
      : ref.watch(supportsLatestProvider(source: source));
  late final filterList = isLocal ? [] : getFilterList(source: source);
  @override
  Widget build(BuildContext context) {
    final _activeId = _activeCustomListId;
    if ((_selectedIndex == _kFilterIdx && (_isSearch && _query.isNotEmpty)) ||
        _isFiltering) {
      _getManga = ref.watch(
        searchProvider(
          source: source,
          query: _query,
          page: 1,
          filterList: filters,
        ),
      );
    } else if (_selectedIndex == _kLatestIdx && !_isSearch && _query.isEmpty) {
      _getManga = ref.watch(getLatestUpdatesProvider(source: source, page: 1));
    } else if (_activeId != null) {
      _getManga = ref.watch(
        getCustomListProvider(source: source, listId: _activeId, page: 1),
      );
    } else {
      _getManga = ref.watch(getPopularProvider(source: source, page: 1));
    }
    final l10n = context.l10n;
    final displayType = ref.watch(mangaHomeDisplayTypeStateProvider);
    final displayTypeIcon = switch (displayType) {
      DisplayType.compactGrid => Icons.grid_view,
      DisplayType.comfortableGrid => Icons.view_module,
      DisplayType.coverOnlyGrid => Icons.image_outlined,
      DisplayType.largeGrid => Icons.dashboard_outlined,
      DisplayType.list => Icons.view_list,
      DisplayType.wideList => Icons.view_agenda_outlined,
    };
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: _isSearch
            ? null
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    !isLocal
                        ? "${source.name}"
                        : "${context.l10n.local_source} ${source.itemType.localized(context.l10n)}",
                  ),
                  source.notes != null && source.notes!.isNotEmpty
                      ? SizedBox(
                          height: 20,
                          child: Marquee(
                            text: l10n.extension_notes(source.notes!),
                            style: const TextStyle(fontSize: 12),
                            blankSpace: 40.0,
                            velocity: 30.0,
                            pauseAfterRound: const Duration(seconds: 1),
                            startPadding: 10.0,
                          ),
                        )
                      : Container(),
                ],
              ),
        leading: !_isSearch ? null : Container(),
        actions: [
          _isSearch
              ? SeachFormTextField(
                  onFieldSubmitted: (submit) {
                    _mangaList.clear();
                    setState(() {
                      if (submit.isNotEmpty) {
                        _selectedIndex = 2;

                        _query = submit;
                      } else {
                        _selectedIndex = 0;
                      }
                      _page = 1;
                    });
                  },
                  onChanged: (value) {},
                  onSuffixPressed: () {
                    _textEditingController.clear();
                    _mangaList.clear();
                    _query = "";
                    setState(() {});
                  },
                  onPressed: () {
                    setState(() {
                      if (_textEditingController.text.isEmpty) {
                        _isSearch = false;
                        _query = "";
                        _isFiltering = false;
                        _selectedIndex = 0;
                        _page = 1;
                        _textEditingController.clear();
                        _mangaList.clear();
                      } else {
                        Navigator.pop(context);
                      }
                    });
                  },
                  controller: _textEditingController,
                )
              : IconButton(
                  splashRadius: 20,
                  onPressed: () {
                    setState(() {
                      _isSearch = true;
                    });
                  },
                  icon: Icon(Icons.search, color: Theme.of(context).hintColor),
                ),
          Builder(
            builder: (ctx) => CustomPopup(
              backgroundColor:
                  Theme.of(ctx).colorScheme.surfaceContainerHigh,
              contentPadding: EdgeInsets.zero,
              content: Consumer(
                builder: (ctx2, ref2, _) {
                  final displayType =
                      ref2.watch(mangaHomeDisplayTypeStateProvider);
                  final notifier = ref2
                      .read(mangaHomeDisplayTypeStateProvider.notifier);
                  Widget tile(
                          IconData icon, String label, DisplayType val) =>
                      RadioListTile<DisplayType>(
                        secondary: Icon(icon, size: 20),
                        title:
                            Text(label, style: const TextStyle(fontSize: 14)),
                        value: val,
                        groupValue: displayType,
                        dense: true,
                        onChanged: (v) => notifier.setMangaHomeDisplayType(v!),
                      );
                  return IntrinsicWidth(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        tile(Icons.grid_view, ctx2.l10n.compact_grid,
                            DisplayType.compactGrid),
                        tile(Icons.view_module, ctx2.l10n.comfortable_grid,
                            DisplayType.comfortableGrid),
                        tile(Icons.image_outlined, ctx2.l10n.cover_only_grid,
                            DisplayType.coverOnlyGrid),
                        tile(Icons.dashboard_outlined, 'Grille large',
                            DisplayType.largeGrid),
                        tile(Icons.view_list, ctx2.l10n.list, DisplayType.list),
                        tile(Icons.view_agenda_outlined, 'Liste étendue',
                            DisplayType.wideList),
                      ],
                    ),
                  );
                },
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(displayTypeIcon, color: Theme.of(ctx).hintColor),
              ),
            ),
          ),
          const SizedBox(width: 2),
          if (!isLocal)
            Builder(
              builder: (ctx) => ArrowPopupMenuButton<_HomeMenuAction>(
                padding: const EdgeInsets.all(10),
                icon: Icon(Icons.more_vert, color: Theme.of(ctx).hintColor),
                onSelected: (action) => _handleHomeMenuAction(ctx, action),
                itemBuilder: (menuCtx) => [
                  PopupMenuItem(
                    value: _HomeMenuAction.openBrowser,
                    child: Row(children: [
                      const Icon(Icons.open_in_browser_rounded, size: 20),
                      const SizedBox(width: 12),
                      Flexible(child: Text(menuCtx.l10n.open_in_browser,
                          style: const TextStyle(fontSize: 14))),
                    ]),
                  ),
                  PopupMenuItem(
                    value: _HomeMenuAction.cookies,
                    child: Row(children: [
                      const Icon(Icons.cookie_outlined, size: 20),
                      const SizedBox(width: 12),
                      const Text('Cookies', style: TextStyle(fontSize: 14)),
                    ]),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: _HomeMenuAction.settings,
                    child: Row(children: [
                      const Icon(Icons.settings_outlined, size: 20),
                      const SizedBox(width: 12),
                      Flexible(child: Text(menuCtx.l10n.settings,
                          style: const TextStyle(fontSize: 14))),
                    ]),
                  ),
                  PopupMenuItem(
                    value: _HomeMenuAction.diagnostic,
                    child: Row(children: [
                      const Icon(Icons.bug_report_outlined, size: 20),
                      const SizedBox(width: 12),
                      const Text('Diagnostic',
                          style: TextStyle(fontSize: 14)),
                    ]),
                  ),
                ],
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(AppBar().preferredSize.height * 0.8),
          child: Column(
            children: [
              SizedBox(
                width: context.width(1),
                height: 45,
                child: SuperListView.builder(
                  scrollDirection: Axis.horizontal,
                  shrinkWrap: true,
                  itemCount: 3 + _customLists.length,
                  itemBuilder: (context, index) {
                    if (filterList.isEmpty && index == _kFilterIdx) {
                      return const SizedBox.shrink();
                    }
                    if (!supportsLatest && index == _kLatestIdx) {
                      return const SizedBox.shrink();
                    }
                    return MangasCardSelector(
                      icon: _types(context)[index].icon,
                      selected: _selectedIndex == index,
                      text: _types(context)[index].title,
                      onPressed: () async {
                        if (filters.isEmpty) {
                          filters = filterList;
                        }
                        if (index == _kFilterIdx) {
                          final result = await showModalBottomSheet(
                            context: context,
                            builder: (context) => StatefulBuilder(
                              builder: (context, setState) {
                                return Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Row(
                                        children: [
                                          TextButton(
                                            onPressed: () {
                                              setState(() {
                                                filters = getFilterList(
                                                  source: source,
                                                );
                                              });
                                            },
                                            child: Text(l10n.reset),
                                          ),
                                          const Spacer(),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  context.primaryColor,
                                            ),
                                            onPressed: () {
                                              Navigator.pop(context, 'filter');
                                            },
                                            child: Text(
                                              l10n.filter,
                                              style: TextStyle(
                                                color: Theme.of(
                                                  context,
                                                ).scaffoldBackgroundColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Divider(),
                                    Expanded(
                                      child: FilterWidget(
                                        filterList: filters,
                                        onChanged: (values) {
                                          setState(() {
                                            filters = values;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          );
                          if (result == 'filter') {
                            _mangaList.clear();
                            if (mounted) {
                              setState(() {
                                _selectedIndex = 2;
                                _isFiltering = true;
                                _page = 1;
                                _isLoading = false;
                              });
                            }

                            _getManga = ref.refresh(
                              searchProvider(
                                source: source,
                                query: _query,
                                page: 1,
                                filterList: filters,
                              ),
                            );
                          }
                        } else {
                          _mangaList.clear();
                          setState(() {
                            _selectedIndex = index;
                            _isFiltering = false;
                            _isSearch = false;
                            _query = "";
                            _textEditingController.clear();
                            _page = 1;
                            _isLoading = false;
                          });
                        }
                      },
                    );
                  },
                ),
              ),
              Container(
                color: context.primaryColor,
                height: 0.3,
                width: context.width(1),
              ),
            ],
          ),
        ),
      ),
      body: _getManga!.isLoading
          ? const ProgressCenter()
          : _getManga!.when(
              data: (data) {
                if (_hasNextPage) {
                  if (!data!.hasNextPage) {
                    if (mounted) {
                      setState(() {
                        _hasNextPage = false;
                      });
                    }
                  }
                }
                if (_mangaList.isEmpty && data!.list.isNotEmpty) {
                  _mangaList.addAll(data.list);
                }
                Widget buildProgressIndicator() {
                  return !(data!.list.isNotEmpty &&
                          (data.hasNextPage || _hasNextPage))
                      ? Container()
                      : _isLoading
                      ? const Center(
                          child: SizedBox(
                            height: 100,
                            width: 200,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.all(4),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                            onPressed: () {
                              if (!_getManga!.isLoading) {
                                if (mounted) {
                                  setState(() {
                                    _isLoading = true;
                                  });
                                }
                                _loadMore().then((value) {
                                  if (mounted && value != null) {
                                    setState(() {
                                      _mangaList.addAll(value.list);
                                      _isLoading = false;
                                    });
                                  }
                                });
                              }
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  l10n.load_more,
                                  style: const TextStyle(
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  maxLines: 2,
                                ),
                                const Icon(Icons.arrow_forward_outlined),
                              ],
                            ),
                          ),
                        );
                }

                if (data!.list.isEmpty) {
                  return Center(child: Text(l10n.no_result));
                }
                _scrollController.addListener(() {
                  if (_scrollController.position.pixels ==
                      _scrollController.position.maxScrollExtent) {
                    if (_mangaList.isNotEmpty &&
                        (_hasNextPage) &&
                        !_isLoading &&
                        !_getManga!.isLoading) {
                      if (mounted) {
                        setState(() {
                          _isLoading = true;
                        });
                      }
                      _loadMore().then((value) {
                        if (mounted && value != null) {
                          setState(() {
                            _mangaList.addAll(value.list);
                            _isLoading = false;
                          });
                        }
                      });
                    }
                  }
                });

                _length = source.isFullData!
                    ? _fullDataLength
                    : _mangaList.length;
                _length = (_mangaList.length < _length
                    ? _mangaList.length
                    : _length);
                final isListMode = displayType == DisplayType.list || displayType == DisplayType.wideList;
                final isComfortableGrid =
                    displayType == DisplayType.comfortableGrid ||
                    displayType == DisplayType.largeGrid;
                final childAspectRatio = switch (displayType) {
                  DisplayType.comfortableGrid => 0.642,
                  DisplayType.largeGrid => 0.6,
                  DisplayType.coverOnlyGrid => 0.85,
                  _ => 0.69,
                };
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    children: [
                      Flexible(
                        child: isListMode
                            ? SuperListViewWidget(
                                controller: _scrollController,
                                itemCount: _length + 1,
                                itemBuilder: (context, index) {
                                  if (index == _length) {
                                    return buildProgressIndicator();
                                  }
                                  return MangaHomeImageCardListTile(
                                    itemType: source.itemType,
                                    manga: _mangaList[index],
                                    source: source,
                                  );
                                },
                              )
                            : Consumer(
                                builder: (context, ref, child) {
                                  final gridSize = displayType == DisplayType.largeGrid
                                      ? 2
                                      : ref.watch(
                                          libraryGridSizeStateProvider(
                                            itemType: source.itemType,
                                          ),
                                        );

                                  return GridViewWidget(
                                    gridSize: gridSize,
                                    controller: _scrollController,
                                    itemCount: _length + 1,
                                    childAspectRatio: childAspectRatio,
                                    itemBuilder: (context, index) {
                                      if (index == _length) {
                                        return buildProgressIndicator();
                                      }
                                      return MangaHomeImageCard(
                                        itemType: source.itemType,
                                        manga: _mangaList[index],
                                        source: source,
                                        isComfortableGrid: isComfortableGrid,
                                      );
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
              error: (error, stackTrace) => Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          children: [
                            IconButton(
                              onPressed: () {
                                if (_selectedIndex == 2 &&
                                        (_isSearch && _query.isNotEmpty) ||
                                    _isFiltering) {
                                  ref.invalidate(
                                    searchProvider(
                                      source: source,
                                      query: _query,
                                      page: 1,
                                      filterList: filters,
                                    ),
                                  );
                                } else if (_selectedIndex == 1 &&
                                    !_isSearch &&
                                    _query.isEmpty) {
                                  ref.invalidate(
                                    getLatestUpdatesProvider(
                                      source: source,
                                      page: 1,
                                    ),
                                  );
                                } else if (_selectedIndex == 0 &&
                                    !_isSearch &&
                                    _query.isEmpty) {
                                  ref.invalidate(
                                    getPopularProvider(source: source, page: 1),
                                  );
                                }
                              },
                              icon: const Icon(Icons.refresh),
                            ),
                            Text(l10n.refresh),
                          ],
                        ),
                        const SizedBox(width: 20),
                        Column(
                          children: [
                            IconButton(
                              onPressed: () async {
                                final baseUrl = ref.watch(
                                  sourceBaseUrlProvider(source: source),
                                );
                                Map<String, dynamic> data = {
                                  'url': baseUrl,
                                  'sourceId': source.id.toString(),
                                  'title': '',
                                  "hasCloudFlare":
                                      source.hasCloudflare ?? false,
                                };
                                context.push("/mangawebview", extra: data);
                              },
                              icon: Icon(
                                Icons.public,
                                size: 22,
                                color: context.secondaryColor,
                              ),
                            ),
                            const Text("Webview"),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isCloudflareError(error.toString()))
                    Expanded(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: CloudflareErrorWidget(
                            errorText: error.toString(),
                            url: source.baseUrl ?? '',
                            onRetry: () {
                              if (_selectedIndex == 2 &&
                                      (_isSearch && _query.isNotEmpty) ||
                                  _isFiltering) {
                                ref.invalidate(searchProvider(
                                  source: source,
                                  query: _query,
                                  page: 1,
                                  filterList: filters,
                                ));
                              } else if (_selectedIndex == 1 &&
                                  !_isSearch &&
                                  _query.isEmpty) {
                                ref.invalidate(getLatestUpdatesProvider(
                                  source: source,
                                  page: 1,
                                ));
                              } else {
                                ref.invalidate(
                                    getPopularProvider(source: source, page: 1));
                              }
                            },
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(child: ErrorText(error)),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
    );
  }
}

class MangaHomeImageCard extends ConsumerStatefulWidget {
  final MManga manga;
  final ItemType itemType;
  final Source source;
  final bool isComfortableGrid;
  const MangaHomeImageCard({
    super.key,
    required this.manga,
    required this.source,
    required this.itemType,
    required this.isComfortableGrid,
  });

  @override
  ConsumerState<MangaHomeImageCard> createState() => _MangaHomeImageCardState();
}

class _MangaHomeImageCardState extends ConsumerState<MangaHomeImageCard>
    with AutomaticKeepAliveClientMixin<MangaHomeImageCard> {
  @override
  Widget build(BuildContext context) {
    super.build(context);

    return MangaImageCardWidget(
      getMangaDetail: widget.manga,
      source: widget.source,
      itemType: widget.itemType,
      isComfortableGrid: widget.isComfortableGrid,
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class MangaHomeImageCardListTile extends ConsumerStatefulWidget {
  final MManga manga;
  final ItemType itemType;
  final Source source;
  const MangaHomeImageCardListTile({
    super.key,
    required this.manga,
    required this.source,
    required this.itemType,
  });

  @override
  ConsumerState<MangaHomeImageCardListTile> createState() =>
      _MangaHomeImageCardListTileState();
}

class _MangaHomeImageCardListTileState
    extends ConsumerState<MangaHomeImageCardListTile>
    with AutomaticKeepAliveClientMixin<MangaHomeImageCardListTile> {
  @override
  Widget build(BuildContext context) {
    super.build(context);

    return MangaImageCardListTileWidget(
      getMangaDetail: widget.manga,
      source: widget.source,
      itemType: widget.itemType,
    );
  }

  @override
  bool get wantKeepAlive => true;
}
