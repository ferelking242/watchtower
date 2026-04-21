import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/more/settings/reader/providers/reader_state_provider.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:watchtower/modules/browse/extension/extension_screen.dart';
import 'package:watchtower/modules/browse/sources/sources_screen.dart';
import 'package:watchtower/modules/library/widgets/search_text_form_field.dart';
import 'package:watchtower/services/fetch_sources_list.dart';
import 'package:watchtower/utils/item_type_localization.dart';

class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

enum BrowseTabKind { sources, extensions }

class BrowseTab {
  final ItemType type;
  final BrowseTabKind kind;

  const BrowseTab(this.type, this.kind);
}

class _BrowseScreenState extends ConsumerState<BrowseScreen>
    with TickerProviderStateMixin {
  late final hideItems = ref.read(hideItemsStateProvider);
  final _textEditingController = TextEditingController();
  late TabController _tabBarController;

  late final List<BrowseTab> _tabList = [
    if (!hideItems.contains("/MangaLibrary"))
      BrowseTab(ItemType.manga, BrowseTabKind.sources),
    if (!hideItems.contains("/AnimeLibrary"))
      BrowseTab(ItemType.anime, BrowseTabKind.sources),
    if (!hideItems.contains("/NovelLibrary"))
      BrowseTab(ItemType.novel, BrowseTabKind.sources),

    if (!hideItems.contains("/MangaLibrary"))
      BrowseTab(ItemType.manga, BrowseTabKind.extensions),
    if (!hideItems.contains("/AnimeLibrary"))
      BrowseTab(ItemType.anime, BrowseTabKind.extensions),
    if (!hideItems.contains("/NovelLibrary"))
      BrowseTab(ItemType.novel, BrowseTabKind.extensions),
  ];

  @override
  void initState() {
    super.initState();
    _tabBarController = TabController(length: _tabList.length, vsync: this);
    _tabBarController.addListener(() {
      _chekPermission();
      setState(() {
        _textEditingController.clear();
        _isSearch = false;
      });
    });
  }

  Future<void> _chekPermission() async {
    await StorageProvider().requestPermission();
  }

  @override
  void dispose() {
    _tabBarController.dispose();
    _textEditingController.dispose();
    super.dispose();
  }

  bool _isSearch = false;
  @override
  Widget build(BuildContext context) {
    if (_tabList.isEmpty) {
      return SizedBox.shrink();
    }
    final currentTab = _tabList[_tabBarController.index];
    final isExtensionTab = currentTab.kind == BrowseTabKind.extensions;

    final l10n = l10nLocalizations(context)!;
    return Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text(
            l10n.browse,
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
          actions: [
            _isSearch
                ? SeachFormTextField(
                    onChanged: (value) {
                      setState(() {});
                    },
                    onSuffixPressed: () {
                      _textEditingController.clear();
                    },
                    onPressed: () {
                      setState(() {
                        _isSearch = false;
                      });
                      _textEditingController.clear();
                    },
                    controller: _textEditingController,
                  )
                : Row(
                    children: [
                      if (isExtensionTab)
                        IconButton(
                          onPressed: () {
                            context.push('/createExtension');
                          },
                          icon: Icon(
                            Icons.add_outlined,
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                      IconButton(
                        splashRadius: 20,
                        onPressed: () {
                          if (isExtensionTab) {
                            setState(() {
                              _isSearch = true;
                            });
                          } else {
                            context.push(
                              '/globalSearch',
                              extra: (null, currentTab.type),
                            );
                          }
                        },
                        icon: Icon(
                          !isExtensionTab
                              ? Icons.travel_explore_rounded
                              : Icons.search_rounded,
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                    ],
                  ),
            GestureDetector(
              onLongPress: isExtensionTab
                  ? () => _isolateDeviceLanguage(context, currentTab.type)
                  : null,
              child: IconButton(
                splashRadius: 20,
                onPressed: () {
                  context.push(
                    isExtensionTab ? '/ExtensionLang' : '/sourceFilter',
                    extra: currentTab.type,
                  );
                },
                icon: Icon(
                  !isExtensionTab
                      ? Icons.filter_list_sharp
                      : Icons.translate_rounded,
                  color: Theme.of(context).hintColor,
                ),
              ),
            ),
          ],
          bottom: TabBar(
            indicatorSize: TabBarIndicatorSize.label,
            isScrollable: true,
            controller: _tabBarController,
            tabs: _tabList.map((tab) {
              final type = tab.type;
              final isExt = tab.kind == BrowseTabKind.extensions;

              IconData tabIcon;
              switch (type) {
                case ItemType.manga:
                  tabIcon = isExt
                      ? Icons.extension_outlined
                      : Icons.auto_stories_outlined;
                  break;
                case ItemType.anime:
                  tabIcon = isExt
                      ? Icons.extension_outlined
                      : Icons.live_tv_outlined;
                  break;
                case ItemType.novel:
                  tabIcon = isExt
                      ? Icons.extension_outlined
                      : Icons.text_snippet_outlined;
                  break;
              }

              return Tab(
                child: Row(
                  children: [
                    Icon(tabIcon, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      isExt
                          ? type.localizedExtensions(l10n)
                          : type.localizedSources(l10n),
                    ),
                    if (isExt) ...[
                      const SizedBox(width: 8),
                      _extensionUpdateNumbers(ref, type),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        body: TabBarView(
          controller: _tabBarController,
          children: _tabList.map((tab) {
            if (tab.kind == BrowseTabKind.sources) {
              return SourcesScreen(
                itemType: tab.type,
                tabs: _tabList,
                tabIndex: (index) => _tabBarController.animateTo(index),
              );
            } else {
              return ExtensionScreen(
                query: _textEditingController.text,
                itemType: tab.type,
              );
            }
          }).toList(),
        ),
      ),
    );
  }
}

/// Long-press shortcut on the translate icon: keeps only the device's
/// language active (and English as a fallback). Long-press again to restore
/// every language.
void _isolateDeviceLanguage(BuildContext context, ItemType itemType) {
  String deviceLang;
  try {
    deviceLang = Platform.localeName.split(RegExp('[_-]')).first.toLowerCase();
  } catch (_) {
    deviceLang = 'en';
  }
  final entries = isar.sources
      .filter()
      .idIsNotNull()
      .and()
      .itemTypeEqualTo(itemType)
      .findAllSync();

  final isolated = entries.any((s) =>
      (s.isActive ?? false) &&
      s.lang!.toLowerCase() != deviceLang &&
      s.lang!.toLowerCase() != 'en' &&
      s.lang!.toLowerCase() != 'all');
  final shouldIsolate = isolated; // if currently mixed, isolate; else restore

  isar.writeTxnSync(() {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final s in entries) {
      final lang = s.lang!.toLowerCase();
      final keep = lang == deviceLang || lang == 'en' || lang == 'all';
      isar.sources.putSync(
        s
          ..isActive = shouldIsolate ? keep : true
          ..updatedAt = now,
      );
    }
  });

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 2),
      content: Text(
        shouldIsolate
            ? 'Sources limitées à ${deviceLang.toUpperCase()} + EN'
            : 'Toutes les langues réactivées',
      ),
    ),
  );
}

Widget _extensionUpdateNumbers(WidgetRef ref, ItemType itemType) {
  return StreamBuilder(
    stream: isar.sources
        .filter()
        .idIsNotNull()
        .and()
        .isActiveEqualTo(true)
        .itemTypeEqualTo(itemType)
        .watch(fireImmediately: true),
    builder: (context, snapshot) {
      if (snapshot.hasData && snapshot.data!.isNotEmpty) {
        final entries = snapshot.data!
            .where(
              (element) =>
                  compareVersions(element.version!, element.versionLast!) < 0,
            )
            .toList();
        return entries.isEmpty
            ? SizedBox.shrink()
            : Badge(
                backgroundColor: Theme.of(context).focusColor,
                label: Text(
                  entries.length.toString(),
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall!.color,
                  ),
                ),
              );
      }
      return Container();
    },
  );
}
