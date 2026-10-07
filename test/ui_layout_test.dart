import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/models/layout_component_registry.dart';
import 'package:watchtower/models/ui_layout.dart';
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
    });

    expect(section.cardComponent, 'mangaFeaturedCard');
    expect(section.episodeComponent, 'homeEpisodeCard');
    expect(section.toLegacyMap()['cardComponent'], 'mangaFeaturedCard');
    expect(section.toLegacyMap()['episodeComponent'], 'homeEpisodeCard');
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
  });
}