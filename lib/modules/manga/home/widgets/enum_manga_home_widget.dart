import 'package:flutter/material.dart';

import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/modules/media/app_ui_components.dart';
import 'package:watchtower/modules/media/content_cards.dart';
import 'package:watchtower/modules/manga/home/widgets/manga_home_cards.dart';

/// Every card layout available on the manga home screen.
enum EnumMangaHomeWidget {
  hero('Spotlight', Icons.auto_awesome_rounded),
  featured('À la une', Icons.local_fire_department_rounded),
  chapterCards('Nouveaux chapitres', Icons.menu_book_outlined),
  continueReading('Reprendre la lecture', Icons.play_circle_outline_rounded),
  genres('Genres', Icons.category_outlined),
  banner('Bannière', Icons.panorama_outlined),
  top3('Top 3', Icons.emoji_events_outlined),
  updatesList('Dernières mises à jour', Icons.update_rounded),
  latestUpdates('Latest Chapter Updates', Icons.schedule_rounded),
  ranking('Top Ranking', Icons.emoji_events_rounded),
  vote('Vote communautaire', Icons.how_to_vote_outlined),
  collectionShowcase('Collection communautaire', Icons.collections_bookmark_outlined),
  trendingLists('Listes tendance', Icons.trending_up_rounded),
  scanGroups('Groupes de scan', Icons.groups_outlined);

  const EnumMangaHomeWidget(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Selector widget: renders one manga-home card layout from the enum.
///
/// The home screen maps each [EnumMangaHomeWidget] to a section, and the
/// component gallery previews every layout through this single entry point.
class EnumMangaHomeWidgetCard extends StatelessWidget {
  const EnumMangaHomeWidgetCard({
    required this.type,
    required this.items,
    required this.onOpen,
    this.title,
    this.subtitle,
    this.onSeeAll,
    super.key,
  });

  final EnumMangaHomeWidget type;
  final List<ContentItem> items;
  final ValueChanged<int> onOpen;
  final String? title;
  final String? subtitle;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final safeItems = items.take(12).toList(growable: false);
    if (safeItems.isEmpty) return const SizedBox.shrink();

    return switch (type) {
      EnumMangaHomeWidget.hero => Padding(
        padding: EdgeInsets.symmetric(horizontal: AppUI.pagePadding(context)),
        child: MangaSpotlightCard(
          item: safeItems.first,
          onTap: () => onOpen(0),
        ),
      ),
      EnumMangaHomeWidget.featured => _MangaSectionScaffold(
        title: title ?? 'À la une',
        onSeeAll: onSeeAll,
        child: SizedBox(
          height: 254,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: AppUI.pagePadding(context),
            ),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: safeItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, index) => MangaFeaturedCard(
              item: safeItems[index],
              onTap: () => onOpen(index),
            ),
          ),
        ),
      ),
      EnumMangaHomeWidget.chapterCards => _MangaSectionScaffold(
        title: title ?? 'Nouveaux chapitres',
        onSeeAll: onSeeAll,
        child: SizedBox(
          height: 210,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: AppUI.pagePadding(context),
            ),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: safeItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, index) => MangaChapterCard(
              item: safeItems[index],
              badge: '${(index + 1) * 12}',
              onTap: () => onOpen(index),
            ),
          ),
        ),
      ),
      EnumMangaHomeWidget.continueReading => _MangaSectionScaffold(
        title: title ?? 'Reprendre la lecture',
        onSeeAll: onSeeAll,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppUI.pagePadding(context),
          ),
          child: MangaResumeCard(
            item: safeItems.first,
            subtitle: subtitle,
            progress: 0.42,
            onTap: () => onOpen(0),
          ),
        ),
      ),
      EnumMangaHomeWidget.genres => _MangaSectionScaffold(
        title: title ?? 'Genres',
        onSeeAll: onSeeAll,
        child: SizedBox(
          height: 84,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: AppUI.pagePadding(context),
            ),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: safeItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, index) => MangaGenreCard(
              label: safeItems[index].title,
              imageUrl: safeItems[index].posterUrl,
              onTap: () => onOpen(index),
            ),
          ),
        ),
      ),
      EnumMangaHomeWidget.banner => Padding(
        padding: EdgeInsets.symmetric(horizontal: AppUI.pagePadding(context)),
        child: MangaBannerCard(item: safeItems.first, onTap: () => onOpen(0)),
      ),
      EnumMangaHomeWidget.top3 => _MangaSectionScaffold(
        title: title ?? 'Top 3',
        onSeeAll: onSeeAll,
        child: SizedBox(
          height: 148,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: AppUI.pagePadding(context),
            ),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: (safeItems.length / 3).ceil().clamp(1, 8),
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, index) => MangaTop3Card(
              items: safeItems.skip(index * 3).toList(growable: false),
              rank: index + 1,
              onTap: onOpen,
            ),
          ),
        ),
      ),
      EnumMangaHomeWidget.updatesList => _MangaSectionScaffold(
        title: title ?? 'Dernières mises à jour',
        onSeeAll: onSeeAll,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppUI.pagePadding(context),
          ),
          child: Column(
            children: [
              for (var i = 0; i < safeItems.length && i < 4; i++)
                Padding(
                  padding: EdgeInsets.only(bottom: i < 3 ? 10 : 0),
                  child: MangaUpdateRow(
                    item: safeItems[i],
                    subtitle: i.isEven ? 'Chapitre ${(i + 11) * 3}' : null,
                    time: ['2 h', '5 h', '1 j', '3 j'][i % 4],
                    onTap: () => onOpen(i),
                  ),
                ),
            ],
          ),
        ),
      ),
      EnumMangaHomeWidget.latestUpdates => _MangaSectionScaffold(
        title: title ?? 'Latest Chapter Updates',
        onSeeAll: onSeeAll,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppUI.pagePadding(context),
          ),
          child: Column(
            children: [
              for (var i = 0; i < safeItems.length && i < 3; i++)
                Padding(
                  padding: EdgeInsets.only(bottom: i < 2 ? 16 : 0),
                  child: MangaLatestUpdateCard(
                    item: safeItems[i],
                    time: ['10m', '22m', '1h'][i % 3],
                    chapters: [
                      'Ch. ${(i + 2) * 47} - ${safeItems[i].title}',
                      'Vol. ${(i + 1)} Ch. ${(i + 1) * 47}',
                    ],
                    onChapterTap: (_) => onOpen(i),
                    onTap: () => onOpen(i),
                  ),
                ),
            ],
          ),
        ),
      ),
      EnumMangaHomeWidget.ranking => Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppUI.pagePadding(context),
        ),
        child: MangaRankingCard(
          items: safeItems,
          onOpen: onOpen,
        ),
      ),
      EnumMangaHomeWidget.vote => Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppUI.pagePadding(context),
        ),
        child: MangaVoteCard(
          title: 'Goonable tiers',
          imageUrl: safeItems.first.posterUrl,
          status: 'Voting closed',
          entries: 9,
          posts: 1,
          onTap: () => onOpen(0),
        ),
      ),
      EnumMangaHomeWidget.collectionShowcase => Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppUI.pagePadding(context),
        ),
        child: MangaCollectionShowcaseCard(
          title: "Romance I'll never get to experience",
          covers: safeItems.map((e) => e.posterUrl).nonNulls.toList(),
          views: '104377',
          likes: '824',
          reads: '47',
          author: 'ShiroX',
          authorAvatar: safeItems.first.posterUrl,
          onTap: () => onOpen(0),
        ),
      ),
      EnumMangaHomeWidget.trendingLists => Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppUI.pagePadding(context),
        ),
        child: Column(
          children: [
            for (var i = 0; i < safeItems.length && i < 3; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i < 2 ? 18 : 0),
                child: MangaTrendingListCard(
                  rank: i + 1,
                  title: ['Favorites', 'Sorry (ish)', 'Tooth rotting fluff'][i],
                  author: ['hideki1974', 'z99zzd', 'palourde'][i],
                  authorAvatar: safeItems[i].posterUrl,
                  covers: safeItems.map((e) => e.posterUrl).nonNulls.toList(),
                  titleCount: ['28 titles', '36 titles', '10 titles'][i],
                  votes: [1, 2, 2][i],
                  onTap: () => onOpen(i),
                ),
              ),
          ],
        ),
      ),
      EnumMangaHomeWidget.scanGroups => Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppUI.pagePadding(context),
        ),
        child: Column(
          children: [
            for (var i = 0; i < safeItems.length && i < 3; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i < 2 ? 18 : 0),
                child: MangaScanGroupCard(
                  rank: i + 1,
                  name: ['No-group', 'Official', 'Art Lapsa'][i],
                  covers: safeItems.map((e) => e.posterUrl).nonNulls.toList(),
                  likes: [3, 13, 9][i],
                  followers: ['3', '13', '9'][i],
                  titles: ['8.1k', '2.3k', '879'][i],
                  staff: '0',
                  lastRelease: ['2 days ago', 'today', 'today'][i],
                  onTap: () => onOpen(i),
                ),
              ),
          ],
        ),
      ),
    };
  }
}

/// Section header + body shared by the composed manga-home sections.
class _MangaSectionScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback? onSeeAll;

  const _MangaSectionScaffold({
    required this.title,
    required this.child,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppUI.pagePadding(context),
            0,
            AppUI.pagePadding(context),
            8,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Tout voir >',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
        child,
      ],
    );
  }
}

/// Convenience mapping for callers that hold [MManga] lists directly
/// (extension data) instead of prebuilt [ContentItem]s.
List<ContentItem> mangaHomeItemsFrom(List<MManga> items) =>
    items.map(ContentItem.fromManga).toList(growable: false);
