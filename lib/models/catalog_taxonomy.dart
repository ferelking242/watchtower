import 'package:watchtower/l10n/generated/app_localizations.dart';

/// Canonical marketplace vocabulary.
///
/// The Marketplace shelves are built from the `tags` field of the extension
/// catalogue, not from substring matches on an extension's name. This file is
/// the Dart mirror of `tools/catalog_taxonomy.mjs` in the
/// `watchtower-extensions` repository: both must agree, and the extension
/// repository's validator fails when an index entry carries a tag that is not
/// listed here.
///
/// Tags are split into three independent axes because they answer different
/// questions:
///
///   content  what the extension serves ("this source serves manga").
///   genre    what the extension can filter on ("this source can filter on
///            fantasy"), derived from the filters the extension really
///            declares, never from the site's marketing copy.
///   language the languages the catalogue declares.
///
/// plus a curation axis (`featured`, `new`) that only an explicit opt-in or a
/// real catalogue date can produce.
///
/// `popular` and `trending` exist in the vocabulary for completeness but are
/// never written into the catalogue: there is no usage statistic behind them,
/// so claiming one would be a fabrication. Shelves labelled "Populaire" use
/// [CatalogRanking], which is deterministic and documented.
class CatalogTaxonomy {
  CatalogTaxonomy._();

  /// Content tags, in display order.
  static const List<String> contentTags = [
    'watch',
    'read',
    'manga',
    'manhwa',
    'manhua',
    'webtoon',
    'comics',
    'novel',
    'anime',
    'animation',
    'movies',
    'series',
    'documentary',
    'jav',
    'music',
    'game',
  ];

  /// Genre tags, in display order.
  static const List<String> genreTags = [
    'action',
    'adventure',
    'fantasy',
    'science-fiction',
    'romance',
    'mystery',
    'drama',
    'comedy',
    'horror',
    'thriller',
    'historical',
    'slice-of-life',
    'mecha',
    'sports',
  ];

  /// Language tags, in display order.
  static const List<String> languageTags = [
    'multilingual',
    'french',
    'english',
    'spanish',
    'german',
    'italian',
    'portuguese',
    'japanese',
    'korean',
    'chinese',
    'arabic',
    'russian',
    'turkish',
    'thai',
    'indonesian',
    'hindi',
    'vietnamese',
    'polish',
    'dutch',
  ];

  /// Curation tags. Only an explicit opt-in or a real date may produce these.
  static const List<String> curationTags = [
    'featured',
    'popular',
    'trending',
    'new',
  ];

  static const List<String> allTags = [
    ...contentTags,
    ...genreTags,
    ...languageTags,
    ...curationTags,
  ];

  static final Set<String> _tagSet = allTags.toSet();

  /// The tag a catalogue entry gets from the catalogue it lives in.
  ///
  /// Mirrors `ITEM_TYPE_TO_CONTENT` in the extension tooling: `itemType` is the
  /// index the entry was published under, so it is a fact rather than a guess.
  static const Map<int, String> itemTypeToContent = {
    0: 'read', // manga / comic
    1: 'watch', // video
    2: 'read', // novel / ebook
    3: 'music',
    4: 'game',
    5: 'read', // plugin entries that ship reading sources
    7: 'watch', // subtitle tracks accompany watchable media
  };

  /// ISO-639-1 (and common BCP-47) code → canonical language tag.
  static const Map<String, String> langCodeToTag = {
    'fr': 'french',
    'fr-fr': 'french',
    'fr-ca': 'french',
    'en': 'english',
    'en-us': 'english',
    'en-gb': 'english',
    'es': 'spanish',
    'es-419': 'spanish',
    'de': 'german',
    'it': 'italian',
    'pt': 'portuguese',
    'pt-br': 'portuguese',
    'ja': 'japanese',
    'ko': 'korean',
    'zh': 'chinese',
    'zh-hk': 'chinese',
    'zh-tw': 'chinese',
    'zh-cn': 'chinese',
    'ar': 'arabic',
    'ru': 'russian',
    'tr': 'turkish',
    'th': 'thai',
    'id': 'indonesian',
    'hi': 'hindi',
    'vi': 'vietnamese',
    'pl': 'polish',
    'nl': 'dutch',
    'all': 'multilingual',
    'multi': 'multilingual',
  };

  static String normalize(String tag) => tag.trim().toLowerCase();

  static bool isKnownTag(String tag) => _tagSet.contains(normalize(tag));

  static bool isLanguageTag(String tag) =>
      languageTags.contains(normalize(tag));

  /// Canonical language tag for a BCP-47 code, or null when unmapped.
  static String? languageTagFor(String code) =>
      langCodeToTag[code.trim().toLowerCase()];

  /// Medium a catalogue belongs to: `watch`, `read`, or the tag itself.
  static String? mediumFor(int itemType) {
    final content = itemTypeToContent[itemType];
    if (content == 'watch' || content == 'read') return content;
    return content;
  }

  /// Ordered, de-duplicated tag list.
  ///
  /// Order follows the vocabulary rather than the input, so a card always shows
  /// its content tag before its genre and language tags and the rendering stays
  /// stable between rebuilds.
  static List<String> orderTags(Iterable<String> tags) {
    final wanted = tags.map(normalize).toSet();
    return allTags.where(wanted.contains).toList(growable: false);
  }

  /// Keeps only tags this version understands, preserving vocabulary order.
  ///
  /// An older application build reading a newer index must ignore the tags it
  /// does not know instead of failing to parse the entry.
  static List<String> filterKnown(Iterable<String> tags) =>
      orderTags(tags.where(isKnownTag));

  /// Localised label for a tag.
  static String label(AppLocalizations l10n, String tag) =>
      switch (normalize(tag)) {
        'watch' => l10n.catalog_tag_watch,
        'read' => l10n.catalog_tag_read,
        'manga' => l10n.catalog_tag_manga,
        'manhwa' => l10n.catalog_tag_manhwa,
        'manhua' => l10n.catalog_tag_manhua,
        'webtoon' => l10n.catalog_tag_webtoon,
        'comics' => l10n.catalog_tag_comics,
        'novel' => l10n.catalog_tag_novel,
        'anime' => l10n.catalog_tag_anime,
        'animation' => l10n.catalog_tag_animation,
        'movies' => l10n.catalog_tag_movies,
        'series' => l10n.catalog_tag_series,
        'documentary' => l10n.catalog_tag_documentary,
        'jav' => l10n.catalog_tag_jav,
        'music' => l10n.catalog_tag_music,
        'game' => l10n.catalog_tag_game,
        'action' => l10n.catalog_tag_action,
        'adventure' => l10n.catalog_tag_adventure,
        'fantasy' => l10n.catalog_tag_fantasy,
        'science-fiction' => l10n.catalog_tag_science_fiction,
        'romance' => l10n.catalog_tag_romance,
        'mystery' => l10n.catalog_tag_mystery,
        'drama' => l10n.catalog_tag_drama,
        'comedy' => l10n.catalog_tag_comedy,
        'horror' => l10n.catalog_tag_horror,
        'thriller' => l10n.catalog_tag_thriller,
        'historical' => l10n.catalog_tag_historical,
        'slice-of-life' => l10n.catalog_tag_slice_of_life,
        'mecha' => l10n.catalog_tag_mecha,
        'sports' => l10n.catalog_tag_sports,
        'multilingual' => l10n.catalog_tag_multilingual,
        'french' => l10n.catalog_tag_french,
        'english' => l10n.catalog_tag_english,
        'spanish' => l10n.catalog_tag_spanish,
        'german' => l10n.catalog_tag_german,
        'italian' => l10n.catalog_tag_italian,
        'portuguese' => l10n.catalog_tag_portuguese,
        'japanese' => l10n.catalog_tag_japanese,
        'korean' => l10n.catalog_tag_korean,
        'chinese' => l10n.catalog_tag_chinese,
        'arabic' => l10n.catalog_tag_arabic,
        'russian' => l10n.catalog_tag_russian,
        'turkish' => l10n.catalog_tag_turkish,
        'thai' => l10n.catalog_tag_thai,
        'indonesian' => l10n.catalog_tag_indonesian,
        'hindi' => l10n.catalog_tag_hindi,
        'vietnamese' => l10n.catalog_tag_vietnamese,
        'polish' => l10n.catalog_tag_polish,
        'dutch' => l10n.catalog_tag_dutch,
        'featured' => l10n.catalog_tag_featured,
        'new' => l10n.catalog_tag_new,
        'popular' => l10n.catalog_tag_popular,
        'trending' => l10n.catalog_tag_trending,
        _ => tag,
      };
}
