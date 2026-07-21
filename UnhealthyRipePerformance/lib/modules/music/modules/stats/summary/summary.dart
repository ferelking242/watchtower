import 'package:auto_route/auto_route.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:watchtower/modules/music/collections/fake.dart';
import 'package:watchtower/modules/music/collections/formatters.dart';
import 'package:watchtower/modules/music/collections/routes.gr.dart';
import 'package:watchtower/modules/music/modules/stats/summary/summary_card.dart';
import 'package:watchtower/modules/music/extensions/constrains.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/provider/history/summary.dart';

class StatsPageSummarySection extends HookConsumerWidget {
  const StatsPageSummarySection({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final summary = ref.watch(playbackHistorySummaryProvider);
    final summaryData = summary.asData?.value ?? FakeData.historySummary;

    return Skeletonizer.sliver(
      enabled: summary.isLoading,
      child: SliverPadding(
        padding: const EdgeInsets.all(10),
        sliver: SliverLayoutBuilder(builder: (context, constrains) {
          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: constrains.isXs
                  ? 2
                  : constrains.smAndDown
                      ? 3
                      : constrains.mdAndDown
                          ? 4
                          : constrains.lgAndDown
                              ? 5
                              : 6,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: constrains.isXs ? 1.3 : 1.5,
            ),
            delegate: SliverChildListDelegate([
              SummaryCard(
                title: summaryData.duration.inMinutes.toDouble(),
                unit: context.l10n.summary_minutes,
                description: context.l10n.summary_listened_to_music,
                color: Colors.indigo,
                onTap: () {
                  context.navigateTo(const StatsMinutesRoute());
                },
              ),
              SummaryCard(
                title: summaryData.tracks.toDouble(),
                unit: context.l10n.summary_songs,
                description: context.l10n.summary_streamed_overall,
                color: Colors.blue,
                onTap: () {
                  context.navigateTo(const StatsStreamsRoute());
                },
              ),
              SummaryCard.unformatted(
                title: usdFormatter.format(summaryData.fees.toDouble()),
                unit: "",
                description: context.l10n.summary_owed_to_artists,
                color: Colors.green,
                onTap: () {
                  context.navigateTo(const StatsStreamFeesRoute());
                },
              ),
              SummaryCard(
                title: summaryData.artists.toDouble(),
                unit: context.l10n.summary_artists,
                description: context.l10n.summary_music_reached_you,
                color: Colors.yellow,
                onTap: () {
                  context.navigateTo(const StatsArtistsRoute());
                },
              ),
              SummaryCard(
                title: summaryData.albums.toDouble(),
                unit: context.l10n.summary_full_albums,
                description: context.l10n.summary_got_your_love,
                color: Colors.pink,
                onTap: () {
                  context.navigateTo(const StatsAlbumsRoute());
                },
              ),
              SummaryCard(
                title: summaryData.playlists.toDouble(),
                unit: context.l10n.summary_playlists,
                description: context.l10n.summary_were_on_repeat,
                color: Colors.teal,
                onTap: () {
                  context.navigateTo(const StatsPlaylistsRoute());
                },
              ),
            ]),
          );
        }),
      ),
    );
  }
}
