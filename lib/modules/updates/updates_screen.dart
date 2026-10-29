import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/models/changed.dart';
import 'package:watchtower/modules/more/settings/sync/providers/sync_providers.dart';
import 'package:watchtower/modules/widgets/animated_empty_state.dart';
import 'package:watchtower/modules/widgets/base_library_tab_screen.dart';
import 'package:watchtower/modules/widgets/custom_sliver_grouped_list_view.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/update.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/updates/widgets/update_chapter_list_tile_widget.dart';
import 'package:watchtower/modules/history/providers/isar_providers.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/services/library_updater.dart';
import 'package:watchtower/utils/date.dart';
import 'package:watchtower/modules/widgets/error_text.dart';
import 'package:watchtower/modules/widgets/progress_center.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';

class UpdatesScreen extends ConsumerStatefulWidget {
  const UpdatesScreen({super.key});

  @override
  ConsumerState<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends BaseLibraryTabScreenState<UpdatesScreen> {
  bool _isLoading = false;

  @override
  String get title => l10nLocalizations(context)!.updates;

  @override
  IconData get titleIcon => Broken.notification;

  @override
  Widget buildTab(ItemType type) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: UpdateTab(
        itemType: type,
        query: textEditingController.text,
        isLoading: _isLoading,
      ),
    );
  }

  @override
  Widget buildTabLabel(ItemType type, String label) {
    IconData icon;
    switch (type) {
      case ItemType.anime:
        icon = Broken.video_play;
        break;
      case ItemType.manga:
        icon = Broken.note;
        break;
      case ItemType.novel:
        icon = Broken.book;
        break;
      case ItemType.music:
        icon = Broken.music_play;
        break;
      case ItemType.game:
        icon = Broken.gameboy;
        break;
      case ItemType.plugin:
        icon = Broken.element_plus;
        break;
    }
    return Tab(icon: _tabIconWithBadge(ref, type, icon), text: label);
  }

  @override
  List<Widget> buildExtraActions(BuildContext context) {
    final l10n = l10nLocalizations(context)!;

    return [
      IconButton(
        splashRadius: 20,
        iconSize: 20,
        icon: Icon(Broken.refresh_2, color: Theme.of(context).hintColor),
        onPressed: _updateLibrary,
      ),
      IconButton(
        splashRadius: 20,
        iconSize: 20,
        icon: Icon(Broken.trash, color: Theme.of(context).hintColor),
        onPressed: () {
          showDialog(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(l10n.remove_everything),
              content: Text(l10n.remove_all_update_msg),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.cancel),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    await _clearUpdates();
                  },
                  child: Text(l10n.ok),
                ),
              ],
            ),
          );
        },
      ),
    ];
  }

  Future<void> _updateLibrary() async {
    setState(() => _isLoading = true);
    final itemType = getCurrentItemType();
    final mangaList = isar.mangas
        .filter()
        .favoriteEqualTo(true)
        .and()
        .itemTypeEqualTo(itemType)
        .and()
        .isLocalArchiveEqualTo(false)
        .findAllSync();
    await updateLibrary(
      ref: ref,
      context: context,
      mangaList: mangaList,
      itemType: itemType,
    );
    setState(() => _isLoading = false);
  }

  Future<void> _clearUpdates() async {
    List<Update> updates = await isar.updates
        .filter()
        .chapter((q) => q.manga((q) => q.itemTypeEqualTo(getCurrentItemType())))
        .findAll();
    final idsToDelete = <Id>[];
    isar.writeTxnSync(() {
      for (var update in updates) {
        idsToDelete.add(update.id!);
        ref
            .read(synchingProvider(syncId: 1).notifier)
            .addChangedPart(ActionType.removeUpdate, update.id, "{}", false);
      }
    });
    await isar.writeTxn(() => isar.updates.deleteAll(idsToDelete));
  }
}

class UpdateTab extends ConsumerStatefulWidget {
  final String query;
  final ItemType itemType;
  final bool isLoading;
  const UpdateTab({
    required this.itemType,
    required this.query,
    required this.isLoading,
    super.key,
  });

  @override
  ConsumerState<UpdateTab> createState() => _UpdateTabState();
}

class _UpdateTabState extends ConsumerState<UpdateTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = l10nLocalizations(context)!;
    final update = ref.watch(
      getAllUpdateStreamProvider(
        itemType: widget.itemType,
        search: widget.query,
      ),
    );
    return Stack(
      children: [
        update.when(
          data: (entries) {
            final lastUpdatedList = entries
                .map((e) => e.chapter.value!.manga.value!.lastUpdate!)
                .toList();
            lastUpdatedList.sort((a, b) => b.compareTo(a));
            final lastUpdated = lastUpdatedList.firstOrNull;
            if (entries.isNotEmpty) {
              return CustomScrollView(
                slivers: [
                  if (lastUpdated != null)
                    SliverPadding(
                      padding: const EdgeInsets.only(
                        left: 10,
                        right: 10,
                        top: 10,
                        bottom: 20,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate.fixed([
                          Text(
                            l10n.library_last_updated(
                              dateFormat(
                                lastUpdated.toString(),
                                ref: ref,
                                context: context,
                                showHOURorMINUTE: true,
                              ),
                            ),
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: context.secondaryColor,
                            ),
                          ),
                        ]),
                      ),
                    ),
                  CustomSliverGroupedListView<Update, String>(
                    elements: entries,
                    groupBy: (element) => dateFormat(
                      element.date!,
                      context: context,
                      ref: ref,
                      forHistoryValue: true,
                      useRelativeTimesTamps: false,
                    ),
                    groupSeparatorBuilder: (String groupByValue) => Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 12),
                      child: Row(
                        children: [
                          Text(
                            dateFormat(
                              null,
                              context: context,
                              stringDate: groupByValue,
                              ref: ref,
                            ),
                          ),
                        ],
                      ),
                    ),
                    itemBuilder: (context, element) {
                      final chapter = element.chapter.value!;
                      return UpdateChapterListTileWidget(
                        chapter: chapter,
                        sourceExist: true,
                      );
                    },
                    itemComparator: (item1, item2) =>
                        item1.date!.compareTo(item2.date!),
                    order: GroupedListOrder.DESC,
                  ),
                ],
              );
            }
            return AnimatedEmptyState(
              message: l10n.no_recent_updates,
              icon: Broken.notification,
            );
          },
          error: (Object error, StackTrace stackTrace) {
            return ErrorText(error);
          },
          loading: () {
            return const ProgressCenter();
          },
        ),
        if (widget.isLoading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: RefreshProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

Widget _tabIconWithBadge(WidgetRef ref, ItemType itemType, IconData icon) {
  return StreamBuilder(
    stream: isar.updates
        .filter()
        .chapter((q) => q.manga((q) => q.itemTypeEqualTo(itemType)))
        .watch(fireImmediately: true),
    builder: (context, snapshot) {
      final count = snapshot.data?.length ?? 0;
      return Badge(
        isLabelVisible: count > 0,
        backgroundColor: Theme.of(context).focusColor,
        label: Text(
          count.toString(),
          style: TextStyle(
            color: Theme.of(context).textTheme.bodySmall!.color,
          ),
        ),
        child: Icon(icon, size: 18),
      );
    },
  );
}

