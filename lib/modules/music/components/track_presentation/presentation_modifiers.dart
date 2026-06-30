import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/components/track_presentation/sort_tracks_dropdown.dart';
import 'package:watchtower/modules/music/components/track_presentation/presentation_actions.dart';
import 'package:watchtower/modules/music/components/track_presentation/presentation_props.dart';
import 'package:watchtower/modules/music/components/track_presentation/presentation_state.dart';
import 'package:watchtower/modules/music/extensions/constrains.dart';
import 'package:watchtower/modules/music/extensions/context.dart';

class TrackPresentationModifiersSection extends HookConsumerWidget {
  final FocusNode? focusNode;
  const TrackPresentationModifiersSection({
    super.key,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context, ref) {
    final options = TrackPresentationOptions.of(context);
    final state = ref.watch(presentationStateProvider(options.collection));
    final notifier = ref.watch(
      presentationStateProvider(options.collection).notifier,
    );

    final controller = useTextEditingController();
    final scale = 1.0;

    return LayoutBuilder(builder: (context, constrains) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: (constrains.mdAndUp ? 16 : 8) * scale,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: state.selectedTracks.length == options.tracks.length
                      ? true
                      : false,
                  onChanged: (value) {
                    if (value == true) {
                      notifier.selectAllTracks();
                    } else {
                      notifier.deselectAllTracks();
                    }
                  },
                ),
              ],
            ),
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  Flexible(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 320 * scale,
                        maxHeight: 38 * scale,
                      ),
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        placeholder: Text(context.l10n.search_tracks),
                        onChanged: (value) {
                          if (value.isEmpty) {
                            notifier.clearFilter();
                          } else {
                            notifier.filterTracks(value);
                          }
                        },
                        features: [
                          InputFeature.leading(
                            Icon(
                              SpotubeIcons.search,
                              color: Theme.of(context).colorScheme.mutedForeground,
                            ),
                          ),
                          InputFeature.trailing(
                            ListenableBuilder(
                                listenable: controller,
                                builder: (context, _) {
                                  return AnimatedCrossFade(
                                    duration: const Duration(milliseconds: 300),
                                    crossFadeState: controller.text.isEmpty
                                        ? CrossFadeState.showFirst
                                        : CrossFadeState.showSecond,
                                    firstChild:
                                        const SizedBox.square(dimension: 20),
                                    secondChild: AnimatedScale(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      scale: controller.text.isEmpty ? 0 : 1,
                                      child: IconButton(
                                        icon: const Icon(SpotubeIcons.close),
                                        onPressed: () {
                                          controller.clear();
                                          notifier.clearFilter();
                                        },
                                      ),
                                    ),
                                  );
                                }),
                          )
                        ],
                      ),
                    ),
                  ),
                  SortTracksDropdown(
                    value: state.sortBy,
                    onChanged: (value) {
                      notifier.sortTracks(value);
                    },
                  ),
                  const TrackPresentationActionsSection(),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}
