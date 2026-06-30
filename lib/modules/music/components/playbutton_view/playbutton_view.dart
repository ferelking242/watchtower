import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_undraw/flutter_undraw.dart';
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/components/playbutton_view/playbutton_card.dart';
import 'package:watchtower/modules/music/components/playbutton_view/playbutton_tile.dart';
import 'package:watchtower/modules/music/components/waypoint.dart';
import 'package:watchtower/modules/music/extensions/constrains.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:very_good_infinite_list/very_good_infinite_list.dart';

const _dummyPlaybuttonCard = PlaybuttonCard(
  imageUrl: 'https://placehold.co/150x150.png',
  isLoading: false,
  isPlaying: false,
  title: "Playbutton",
  description: "A really cool playbutton",
  isOwner: false,
);

const _dummyPlaybuttonTile = PlaybuttonTile(
  imageUrl: 'https://placehold.co/150x150.png',
  isLoading: false,
  isPlaying: false,
  title: "Playbutton",
  description: "A really cool playbutton",
  isOwner: false,
);

/// A [PlaybuttonCard] grid/list view (selectable) sliver widget
/// with support for infinite scrolling
class PlaybuttonView extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) gridItemBuilder;
  final Widget Function(BuildContext context, int index) listItemBuilder;
  final bool hasMore;
  final bool isLoading;
  final VoidCallback onRequestMore;
  final ScrollController controller;

  final Widget? leading;

  const PlaybuttonView({
    super.key,
    required this.itemCount,
    required this.gridItemBuilder,
    required this.listItemBuilder,
    required this.hasMore,
    required this.isLoading,
    required this.onRequestMore,
    required this.controller,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final scale = 1.0;

    return SliverLayoutBuilder(
      builder: (context, constrains) => HookBuilder(builder: (context) {
        final isGrid = useState(constrains.mdAndUp);
        final hasUserInteracted = useRef(false);

        useEffect(() {
          if (hasUserInteracted.value) return null;
          if (isGrid.value != constrains.mdAndUp) {
            isGrid.value = constrains.mdAndUp;
          }
          return null;
        }, [constrains]);

        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (leading != null) leading!,
                  IconButton(
                    onPressed: () {
                      isGrid.value = true;
                      hasUserInteracted.value = true;
                    },
                    style: isGrid.value
                        ? IconButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primaryContainer)
                        : null,
                    icon: const Icon(SpotubeIcons.grid),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      isGrid.value = false;
                      hasUserInteracted.value = true;
                    },
                    style: !isGrid.value
                        ? IconButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primaryContainer)
                        : null,
                    icon: const Icon(SpotubeIcons.list),
                  ),
                ],
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 10)),
            // Toggle between grid and list view
            switch ((isGrid.value, isLoading)) {
              (true, _) => !isLoading && itemCount == 0
                  ? SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 10,
                          children: [
                            Undraw(
                              height: 200 * 1.0,
                              illustration: UndrawIllustration.taken,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            Text(
                              context.l10n.nothing_found,
                              textAlign: TextAlign.center,
                            )
                          ],
                        ),
                      ),
                    )
                  : SliverGrid.builder(
                      itemCount: isLoading ? 6 : itemCount + 1,
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 150 * scale,
                        mainAxisExtent: 225 * scale,
                        crossAxisSpacing: 12 * scale,
                        mainAxisSpacing: 12 * scale,
                      ),
                      itemBuilder: (context, index) {
                        if (isLoading) {
                          return const Skeletonizer(enabled: true,
                            child: _dummyPlaybuttonCard,
                          );
                        }

                        if (index == itemCount) {
                          if (!hasMore) return const SizedBox.shrink();
                          return Waypoint(
                            controller: controller,
                            isGrid: true,
                            onTouchEdge: onRequestMore,
                            child: const Skeletonizer(enabled: true,
                              child: _dummyPlaybuttonCard,
                            ),
                          );
                        }

                        return gridItemBuilder(context, index);
                      },
                    ),
              (false, true) => Skeletonizer.sliver(
                  enabled: true,
                  child: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _dummyPlaybuttonTile,
                      childCount: 6,
                    ),
                  ),
                ),
              (false, false) => SliverInfiniteList(
                  itemCount: itemCount,
                  loadingBuilder: (context) => const Skeletonizer(enabled: true,
                    child: _dummyPlaybuttonTile,
                  ),
                  itemBuilder: listItemBuilder,
                  onFetchData: onRequestMore,
                  hasReachedMax: !hasMore,
                  isLoading: isLoading,
                  emptyBuilder: (context) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 10,
                      children: [
                        Undraw(
                          height: 200 * 1.0,
                          illustration: UndrawIllustration.taken,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        Text(
                          context.l10n.nothing_found,
                          textAlign: TextAlign.center,
                        )
                      ],
                    );
                  },
                ),
            }
          ],
        );
      }),
    );
  }
}
