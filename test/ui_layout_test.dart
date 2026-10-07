import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/models/layout_component_registry.dart';
import 'package:watchtower/models/ui_layout.dart';
import 'package:watchtower/modules/media/content_cards.dart';
import 'package:watchtower/modules/manga/home/widgets/manga_home_card_adapter.dart';
import 'package:watchtower/modules/watch/home/extension_episode_card_adapter.dart';

void main() {
  test('keeps the extension section order and presentation metadata', () {
    final layout = UiLayout.fromJson({
      'schemaVersion': 2,
      'home': {
        'sections': [
          {
            'id': 'trending',
            'component': 'grid',
            'title': 'Tendances',
            'columns': 4,
          },
          {
            'id': 'latest',
            'component': 'landscapeStacked',
            'title': 'Nouveautés',
          },
        ],
      },
    });

    expect(layout.schemaVersion, 2);
    expect(layout.home.sections.map((section) => section.id), [
      'trending',
      'latest',
    ]);
    expect(layout.home.sections.first.component, 'grid');
    expect(layout.home.sections.first.columns, 4);
    expect(layout.home.sections.last.component, 'landscapeStacked');
  });

  test('maps declarative components without replacing their section ids', () {
    final section = UiSection.fromJson({
      'id': 'for_you',
      'component': 'compactRow',
      'title': 'Pour vous',
      'accent': 'primary',
      'seeAll': true,
    });

    final legacy = section.toLegacyMap();

    expect(legacy['id'], 'for_you');
    expect(legacy['component'], 'compactRow');
    expect(legacy['layout'], 'compact');
    expect(legacy['name'], 'Pour vous');
    expect(legacy['color'], 'primary');
    expect(legacy['seeAll'], 'for_you');
  });

  test('keeps Manga card components separate from Home section components', () {
    final section = UiSection.fromJson({
      'id': 'popular',
      'component': 'grid',
      'cardComponent': 'mangaFeaturedCard',
      'episodeComponent': 'homeEpisodeCard',
      'chapterComponent': 'chapterCard',
    });

    expect(section.cardComponent, 'mangaFeaturedCard');
    expect(section.episodeComponent, 'homeEpisodeCard');
    expect(section.chapterComponent, 'chapterCard');
    expect(section.toLegacyMap()['cardComponent'], 'mangaFeaturedCard');
    expect(section.toLegacyMap()['episodeComponent'], 'homeEpisodeCard');
    expect(section.toLegacyMap()['chapterComponent'], 'chapterCard');
    expect(
      LayoutComponentRegistry.supports(
        'mangaFeaturedCard',
        LayoutComponentContext.homeMangaCard,
      ),
      isTrue,
    );
    expect(
      LayoutComponentRegistry.supports(
        'mangaFeaturedCard',
        LayoutComponentContext.home,
      ),
      isFalse,
    );
    expect(
      LayoutComponentRegistry.forContext(
        LayoutComponentContext.homeMangaCard,
        selectableOnly: true,
      ).map((definition) => definition.id),
      ['mangaFeaturedCard', 'mangaChapterCard'],
    );
    expect(
      LayoutComponentRegistry.supports(
        'homeEpisodeCard',
        LayoutComponentContext.homeEpisodeCard,
      ),
      isTrue,
    );
    expect(
      LayoutComponentRegistry.supports(
        'homeEpisodeCard',
        LayoutComponentContext.home,
      ),
      isFalse,
    );
    expect(
      LayoutComponentRegistry.forContext(
        LayoutComponentContext.homeEpisodeCard,
        selectableOnly: true,
      ).map((definition) => definition.id),
      ['homeEpisodeCard'],
    );
    expect(
      LayoutComponentRegistry.supports(
        'chapterCard',
        LayoutComponentContext.chapter,
      ),
      isTrue,
    );
    expect(
      LayoutComponentRegistry.supports('chapterCard', LayoutComponentContext.home),
      isFalse,
    );
    expect(
      LayoutComponentRegistry.forContext(
        LayoutComponentContext.chapter,
        selectableOnly: true,
      ).map((definition) => definition.id),
      ['chapterCard'],
    );
  });

  test('does not expose components without a real Detail renderer', () {
    expect(
      LayoutComponentRegistry.forContext(
        LayoutComponentContext.detail,
        selectableOnly: true,
      ),
      isEmpty,
    );
    for (final component in [
      'mangaFeaturedCard',
      'mangaChapterCard',
      'homeEpisodeCard',
      'chapterCard',
    ]) {
      expect(
        LayoutComponentRegistry.supports(
          component,
          LayoutComponentContext.detail,
        ),
        isFalse,
        reason: '$component has no renderer wired to the Detail model',
      );
    }
  });

  test('preserves existing Detail layout style identifiers', () {
    final posterLayout = DetailLayout.fromJson({
      'hero': 'poster',
      'episodeList': 'compact',
      'showRecommendations': false,
    });
    final backdropLayout = DetailLayout.fromJson({
      'hero': 'backdrop',
      'episodeList': 'vertical',
      'showRecommendations': true,
    });

    expect(posterLayout.hero, 'poster');
    expect(posterLayout.episodeList, 'compact');
    expect(posterLayout.showRecommendations, isFalse);
    expect(backdropLayout.hero, 'backdrop');
    expect(backdropLayout.episodeList, 'vertical');
    expect(backdropLayout.showRecommendations, isTrue);
  });

  test('does not expose reader cards without a real reader adapter', () {
    expect(
      LayoutComponentRegistry.forContext(
        LayoutComponentContext.reader,
        selectableOnly: true,
      ),
      isEmpty,
    );
  });

  test('offers only renderable Manga cards in the Search context', () {
    expect(
      LayoutComponentRegistry.forContext(
        LayoutComponentContext.search,
        selectableOnly: true,
      ).map((definition) => definition.id),
      ['mangaFeaturedCard', 'mangaChapterCard'],
    );
    expect(
      LayoutComponentRegistry.forContext(
        LayoutComponentContext.browse,
        selectableOnly: true,
      ),
      isEmpty,
    );
    expect(
      LayoutComponentRegistry.forContext(
        LayoutComponentContext.player,
        selectableOnly: true,
      ),
      isEmpty,
    );
  });

  test('adds a Search card without changing legacy grid presentation', () {
    final layout = UiLayout.fromJson({
      'schemaVersion': 1,
      'home': {'sections': []},
      'browse': {
        'search': {
          'results': {
            'component': 'grid',
            'columns': 3,
            'cardComponent': 'mangaFeaturedCard',
          },
          'filters': 'chips',
        },
      },
    });
    final results = layout.browse?.search?.results;

    expect(results?.component, 'grid');
    expect(results?.columns, 3);
    expect(results?.cardComponent, 'mangaFeaturedCard');
    expect(layout.browse?.search?.filters, 'chips');
  });

  test('Search adapter builds both registered cards from ContentItem data', () {
    const item = ContentItem(key: 'search-result', title: 'Search result');
    for (final component in ['mangaFeaturedCard', 'mangaChapterCard']) {
      expect(
        MangaHomeCardAdapter.build(
          component: component,
          componentContext: LayoutComponentContext.search,
          item: item,
          width: 168,
          onTap: () {},
        ),
        isNotNull,
      );
    }
    expect(
      MangaHomeCardAdapter.build(
        component: 'mangaFeaturedCard',
        componentContext: LayoutComponentContext.reader,
        item: item,
        width: 168,
        onTap: () {},
      ),
      isNull,
    );
  });

  test('parses episode numbers from episode labels without inventing one', () {
    expect(
      ExtensionEpisodeCardAdapter.parseEpisodeNumber('S2E05 - The Arrival'),
      5,
    );
    expect(
      ExtensionEpisodeCardAdapter.parseEpisodeNumber('Episode 12'),
      12,
    );
    expect(
      ExtensionEpisodeCardAdapter.parseEpisodeNumber('The Arrival'),
      isNull,
    );
    expect(
      ExtensionEpisodeCardAdapter.parseEpisodeNumber('Arcane 4'),
      isNull,
    );
  });
}