import 'package:flutter/material.dart';
  import 'package:flutter_hooks/flutter_hooks.dart';
  import 'package:hooks_riverpod/hooks_riverpod.dart';
  import 'package:watchtower/modules/music/extensions/constrains.dart';
  import 'package:watchtower/modules/music/modules/stats/top/albums.dart';
  import 'package:watchtower/modules/music/modules/stats/top/artists.dart';
  import 'package:watchtower/modules/music/modules/stats/top/tracks.dart';
  import 'package:watchtower/modules/music/extensions/context.dart';

  import 'package:watchtower/modules/music/provider/history/top.dart';

  class StatsPageTopSection extends HookConsumerWidget {
    const StatsPageTopSection({super.key});

    @override
    Widget build(BuildContext context, ref) {
      final selectedIndex = useState(0);
      final tabController = useTabController(initialLength: 3);
      final historyDuration = ref.watch(playbackHistoryTopDurationProvider);
      final historyDurationNotifier =
          ref.watch(playbackHistoryTopDurationProvider.notifier);

      useEffect(() {
        void listener() {
          selectedIndex.value = tabController.index;
        }
        tabController.addListener(listener);
        return () => tabController.removeListener(listener);
      }, [tabController]);

      final translations = <HistoryDuration, String>{
        HistoryDuration.days7: context.l10n.this_week,
        HistoryDuration.days30: context.l10n.this_month,
        HistoryDuration.months6: context.l10n.last_6_months,
        HistoryDuration.year: context.l10n.this_year,
        HistoryDuration.years2: context.l10n.last_2_years,
        HistoryDuration.allTime: context.l10n.all_time,
      };

      final dropdown = DropdownButton<HistoryDuration>(
        value: historyDuration,
        isDense: true,
        items: HistoryDuration.values
            .map((item) => DropdownMenuItem(
                  value: item,
                  child: Text(translations[item]!),
                ))
            .toList(),
        onChanged: (value) {
          if (value == null) return;
          historyDurationNotifier.update((_) => value);
        },
      );

      return SliverLayoutBuilder(builder: (context, constraints) {
        return SliverMainAxisGroup(
          slivers: [
            SliverAppBar(
              floating: true,
              elevation: 0,
              backgroundColor: Theme.of(context).colorScheme.surface,
              automaticallyImplyLeading: false,
              flexibleSpace: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    TabBar(
                      controller: tabController,
                      tabs: [
                        Tab(child: Text(context.l10n.top_tracks)),
                        Tab(child: Text(context.l10n.top_artists)),
                        Tab(child: Text(context.l10n.top_albums)),
                      ],
                    ),
                    if (constraints.mdAndUp) ...[
                      const Spacer(),
                      dropdown,
                    ]
                  ],
                ),
              ),
            ),
            if (constraints.smAndDown)
              SliverToBoxAdapter(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: dropdown,
                ),
              ),
            switch (selectedIndex.value) {
              1 => const TopArtists(),
              2 => const TopAlbums(),
              _ => const TopTracks(),
            },
          ],
        );
      });
    }
  }
  