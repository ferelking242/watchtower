import 'package:watchtower/l10n/generated/app_localizations.dart';

/// A platform a source application runs on.
enum MigrationPlatform { android, ios, windows, macos, linux }

/// Which dock tab an app belongs to.
///
/// [universal] collects the apps that are not tied to a single medium: the
/// manga/anime/novel clients such as Mangayomi, Aniyomi or LNReader.
enum MigrationCategory { manga, anime, universal }

/// A pro or con of a source application.
///
/// Kept as an enum rather than a string so every fact is translated through
/// [migrationFactLabel] and no locale can fall back to English by accident.
enum MigFact {
  // Pros
  mangaReader,
  animeWatcher,
  lightNovelReader,
  bothAnimeManga,
  animeLnManga,
  manySources,
  manySourcesShort,
  openSource,
  activelyDeveloped,
  longTrackRecord,
  crossPlatform,
  desktopPlatforms,
  openExtensionSystem,
  niceUi,
  integration,
  tracker,
  trackReleases,
  ebookOutput,
  sameAsMihon,
  combinesForks,
  mangadexClient,
  eh,
  // Cons
  androidOnly,
  desktopOnly,
  needExtension,
  extensionSeparate,
  originalUnmaintained,
  notIosStore,
  needPlugins,
  lessPopular,
  newApp,
  onlyMangadex,
  cannotReadOffline,
  archived,
  torrent,
  iosDonors,
  relativelyNew,
  missingNewFeatures,
}

/// Translates one [MigFact] with the active locale.
String migrationFactLabel(AppLocalizations l10n, MigFact fact) =>
    switch (fact) {
      MigFact.mangaReader => l10n.migProMangaReader,
      MigFact.animeWatcher => l10n.migProAnimeWatcher,
      MigFact.lightNovelReader => l10n.migProLightNovelReader,
      MigFact.bothAnimeManga => l10n.migProBothAnimeManga,
      MigFact.animeLnManga => l10n.migProAnimeLnManga,
      MigFact.manySources => l10n.migProManySources,
      MigFact.manySourcesShort => l10n.migProManySourcesShort,
      MigFact.openSource => l10n.migProOpenSource,
      MigFact.activelyDeveloped => l10n.migProActivelyDeveloped,
      MigFact.longTrackRecord => l10n.migProLongTrackRecord,
      MigFact.crossPlatform => l10n.migProCrossPlatform,
      MigFact.desktopPlatforms => l10n.migProDesktopPlatforms,
      MigFact.openExtensionSystem => l10n.migProOpenExtensionSystem,
      MigFact.niceUi => l10n.migProNiceUi,
      MigFact.integration => l10n.migProIntegration,
      MigFact.tracker => l10n.migProTracker,
      MigFact.trackReleases => l10n.migProTrackReleases,
      MigFact.ebookOutput => l10n.migProEbookOutput,
      MigFact.sameAsMihon => l10n.migProSameAsMihon,
      MigFact.combinesForks => l10n.migProCombinesForks,
      MigFact.mangadexClient => l10n.migProMangadexClient,
      MigFact.eh => l10n.migProEh,
      MigFact.androidOnly => l10n.migConAndroidOnly,
      MigFact.desktopOnly => l10n.migConDesktopOnly,
      MigFact.needExtension => l10n.migConNeedExtension,
      MigFact.extensionSeparate => l10n.migConExtensionSeparate,
      MigFact.originalUnmaintained => l10n.migConOriginalUnmaintained,
      MigFact.notIosStore => l10n.migConNotIosStore,
      MigFact.needPlugins => l10n.migConNeedPlugins,
      MigFact.lessPopular => l10n.migConLessPopular,
      MigFact.newApp => l10n.migConNewApp,
      MigFact.onlyMangadex => l10n.migConOnlyMangadex,
      MigFact.cannotReadOffline => l10n.migConCannotReadOffline,
      MigFact.archived => l10n.migConArchived,
      MigFact.torrent => l10n.migConTorrent,
      MigFact.iosDonors => l10n.migConIosDonors,
      MigFact.relativelyNew => l10n.migConRelativelyNew,
      MigFact.missingNewFeatures => l10n.migConMissingNewFeatures,
    };

/// Short platform names. These are product names, so they are not translated.
String migrationPlatformLabel(MigrationPlatform platform) => switch (platform) {
  MigrationPlatform.android => 'Android',
  MigrationPlatform.ios => 'iOS',
  MigrationPlatform.windows => 'Windows',
  MigrationPlatform.macos => 'macOS',
  MigrationPlatform.linux => 'Linux',
};

/// One source application a user may be migrating from.
class MigrationApp {
  const MigrationApp({
    required this.id,
    required this.name,
    required this.category,
    required this.platforms,
    required this.logoAsset,
    required this.site,
    this.backupFormat,
    this.pros = const [],
    this.cons = const [],
  });

  final String id;
  final String name;
  final MigrationCategory category;
  final List<MigrationPlatform> platforms;
  final String logoAsset;
  final String site;

  /// The backup file extension the app exports, when it exports one.
  final String? backupFormat;

  final List<MigFact> pros;
  final List<MigFact> cons;

  /// Whether Watchtower can read this app's library backup today.
  ///
  /// The `.tachibk` / `.proto.gz` stream produced by the Mihon family is the
  /// format `restoreMihonBackup` parses, so the badge is limited to it.
  bool get importSupported =>
      backupFormat == '.tachibk' || backupFormat == '.proto.gz';

  bool get isOpenSource => pros.contains(MigFact.openSource);

  bool matchesQuery(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return name.toLowerCase().contains(q) ||
        platforms.any(
          (p) => migrationPlatformLabel(p).toLowerCase().contains(q),
        );
  }
}

/// The catalogue shown in the migration page.
///
/// Facts are the ones each project publishes about itself (see the migration
/// guide); they are rendered through [migrationFactLabel] so nothing is
/// hard-coded in a widget.
const List<MigrationApp> migrationApps = [
  // ── Manga ──────────────────────────────────────────────────────────────
  MigrationApp(
    id: 'mihon',
    name: 'Mihon',
    category: MigrationCategory.manga,
    platforms: [MigrationPlatform.android],
    logoAsset: 'assets/images/migration/apps/mihon.png',
    site: 'https://mihon.app/',
    backupFormat: '.tachibk',
    pros: [
      MigFact.mangaReader,
      MigFact.manySources,
      MigFact.longTrackRecord,
      MigFact.activelyDeveloped,
      MigFact.openSource,
    ],
    cons: [
      MigFact.needExtension,
      MigFact.extensionSeparate,
      MigFact.androidOnly,
    ],
  ),
  MigrationApp(
    id: 'tachiyomisy',
    name: 'TachiyomiSY',
    category: MigrationCategory.manga,
    platforms: [MigrationPlatform.android],
    logoAsset: 'assets/images/migration/apps/tachiyomisy.png',
    site: 'https://mihon.app/forks/TachiyomiSY/',
    backupFormat: '.tachibk',
    pros: [MigFact.sameAsMihon, MigFact.eh, MigFact.openSource],
    cons: [MigFact.lessPopular],
  ),
  MigrationApp(
    id: 'neko',
    name: 'Neko',
    category: MigrationCategory.manga,
    platforms: [MigrationPlatform.android],
    logoAsset: 'assets/images/migration/apps/neko.png',
    site: 'https://github.com/nekomangaorg/Neko',
    backupFormat: '.tachibk',
    pros: [
      MigFact.mangaReader,
      MigFact.longTrackRecord,
      MigFact.mangadexClient,
      MigFact.activelyDeveloped,
      MigFact.openSource,
    ],
    cons: [MigFact.onlyMangadex, MigFact.androidOnly],
  ),
  MigrationApp(
    id: 'komikku',
    name: 'Komikku',
    category: MigrationCategory.manga,
    platforms: [MigrationPlatform.android],
    logoAsset: 'assets/images/migration/apps/komikku.png',
    site: 'https://github.com/komikku-app/komikku',
    backupFormat: '.tachibk',
    pros: [MigFact.sameAsMihon, MigFact.combinesForks, MigFact.openSource],
    cons: [MigFact.lessPopular],
  ),
  MigrationApp(
    id: 'kotatsu',
    name: 'Kotatsu',
    category: MigrationCategory.manga,
    platforms: [MigrationPlatform.android],
    logoAsset: 'assets/images/migration/apps/kotatsu.png',
    site: 'https://github.com/Kotatsu-Redo/Kotatsu-Redo/',
    backupFormat: '.json',
    pros: [
      MigFact.mangaReader,
      MigFact.manySourcesShort,
      MigFact.niceUi,
      MigFact.openSource,
    ],
    cons: [MigFact.androidOnly, MigFact.archived],
  ),
  MigrationApp(
    id: 'suwayomi',
    name: 'Suwayomi',
    category: MigrationCategory.manga,
    platforms: [
      MigrationPlatform.windows,
      MigrationPlatform.macos,
      MigrationPlatform.linux,
    ],
    logoAsset: 'assets/images/migration/apps/suwayomi.png',
    site: 'https://github.com/Suwayomi/Suwayomi-Server',
    pros: [
      MigFact.mangaReader,
      MigFact.manySources,
      MigFact.desktopPlatforms,
      MigFact.openSource,
    ],
    cons: [MigFact.desktopOnly],
  ),
  MigrationApp(
    id: 'houdoku',
    name: 'Houdoku',
    category: MigrationCategory.manga,
    platforms: [
      MigrationPlatform.windows,
      MigrationPlatform.macos,
      MigrationPlatform.linux,
    ],
    logoAsset: 'assets/images/migration/apps/houdoku.png',
    site: 'https://houdoku.org/',
    backupFormat: '.json',
    pros: [
      MigFact.mangaReader,
      MigFact.desktopPlatforms,
      MigFact.manySourcesShort,
      MigFact.niceUi,
      MigFact.openSource,
    ],
    cons: [MigFact.desktopOnly],
  ),
  // ── Anime ──────────────────────────────────────────────────────────────
  MigrationApp(
    id: 'hayase',
    name: 'Hayase',
    category: MigrationCategory.anime,
    platforms: [
      MigrationPlatform.android,
      MigrationPlatform.ios,
      MigrationPlatform.windows,
      MigrationPlatform.macos,
      MigrationPlatform.linux,
    ],
    logoAsset: 'assets/images/migration/apps/hayase.png',
    site: 'https://hayase.watch/',
    pros: [
      MigFact.animeWatcher,
      MigFact.niceUi,
      MigFact.activelyDeveloped,
      MigFact.crossPlatform,
      MigFact.openSource,
    ],
    cons: [
      MigFact.torrent,
      MigFact.iosDonors,
      MigFact.needExtension,
      MigFact.extensionSeparate,
    ],
  ),
  MigrationApp(
    id: 'shiru',
    name: 'Shiru',
    category: MigrationCategory.anime,
    platforms: [
      MigrationPlatform.android,
      MigrationPlatform.windows,
      MigrationPlatform.macos,
      MigrationPlatform.linux,
    ],
    logoAsset: 'assets/images/migration/apps/shiru.png',
    site: 'https://github.com/RockinChaos/Shiru',
    pros: [
      MigFact.animeWatcher,
      MigFact.desktopPlatforms,
      MigFact.niceUi,
      MigFact.openSource,
    ],
    cons: [MigFact.missingNewFeatures],
  ),
  // ── Universal ──────────────────────────────────────────────────────────
  MigrationApp(
    id: 'mangayomi',
    name: 'Mangayomi',
    category: MigrationCategory.universal,
    platforms: [
      MigrationPlatform.android,
      MigrationPlatform.ios,
      MigrationPlatform.windows,
      MigrationPlatform.macos,
      MigrationPlatform.linux,
    ],
    logoAsset: 'assets/images/migration/apps/mangayomi.png',
    site: 'https://github.com/kodjodevf/mangayomi',
    backupFormat: '.json',
    pros: [
      MigFact.bothAnimeManga,
      MigFact.crossPlatform,
      MigFact.openExtensionSystem,
      MigFact.activelyDeveloped,
      MigFact.openSource,
    ],
    cons: [
      MigFact.needExtension,
      MigFact.extensionSeparate,
      MigFact.notIosStore,
    ],
  ),
  MigrationApp(
    id: 'aniyomi',
    name: 'Aniyomi',
    category: MigrationCategory.universal,
    platforms: [MigrationPlatform.android],
    logoAsset: 'assets/images/migration/apps/aniyomi.png',
    site: 'https://aniyomi.org/',
    backupFormat: '.tachibk',
    pros: [
      MigFact.bothAnimeManga,
      MigFact.manySources,
      MigFact.activelyDeveloped,
      MigFact.openSource,
    ],
    cons: [
      MigFact.androidOnly,
      MigFact.needExtension,
      MigFact.extensionSeparate,
      MigFact.originalUnmaintained,
    ],
  ),
  MigrationApp(
    id: 'kototoro',
    name: 'Kototoro',
    category: MigrationCategory.universal,
    platforms: [
      MigrationPlatform.android,
      MigrationPlatform.ios,
      MigrationPlatform.windows,
    ],
    logoAsset: 'assets/images/migration/apps/kototoro.png',
    site: 'https://kototoro-app.github.io/Kototoro/',
    backupFormat: '.json',
    pros: [
      MigFact.animeLnManga,
      MigFact.integration,
      MigFact.crossPlatform,
      MigFact.openSource,
    ],
    cons: [MigFact.newApp],
  ),
  MigrationApp(
    id: 'lnreader',
    name: 'LNReader',
    category: MigrationCategory.universal,
    platforms: [MigrationPlatform.android],
    logoAsset: 'assets/images/migration/apps/lnreader.png',
    site: 'https://www.lnreader.app/',
    backupFormat: '.json',
    pros: [
      MigFact.lightNovelReader,
      MigFact.manySourcesShort,
      MigFact.activelyDeveloped,
      MigFact.openSource,
    ],
    cons: [MigFact.androidOnly, MigFact.needPlugins],
  ),
  MigrationApp(
    id: 'tsundoku',
    name: 'Tsundoku',
    category: MigrationCategory.universal,
    platforms: [MigrationPlatform.android],
    logoAsset: 'assets/images/migration/apps/tsundoku.png',
    site: 'https://tsundoku-otaku.github.io/',
    backupFormat: '.json',
    pros: [
      MigFact.lightNovelReader,
      MigFact.manySourcesShort,
      MigFact.activelyDeveloped,
      MigFact.openSource,
    ],
    cons: [MigFact.androidOnly, MigFact.needExtension, MigFact.relativelyNew],
  ),
  MigrationApp(
    id: 'quicknovel',
    name: 'QuickNovel',
    category: MigrationCategory.universal,
    platforms: [MigrationPlatform.android],
    logoAsset: 'assets/images/migration/apps/quicknovel.png',
    site: 'https://github.com/LagradOst/QuickNovel',
    pros: [
      MigFact.lightNovelReader,
      MigFact.manySourcesShort,
      MigFact.openSource,
    ],
    cons: [MigFact.androidOnly, MigFact.cannotReadOffline],
  ),
  MigrationApp(
    id: 'lncrawl',
    name: 'Lightnovel Crawler',
    category: MigrationCategory.universal,
    platforms: [MigrationPlatform.windows, MigrationPlatform.linux],
    logoAsset: 'assets/images/migration/apps/lncrawl.png',
    site: 'https://github.com/lncrawl/lightnovel-crawler',
    pros: [
      MigFact.lightNovelReader,
      MigFact.manySourcesShort,
      MigFact.ebookOutput,
      MigFact.openSource,
    ],
    cons: [MigFact.desktopOnly],
  ),
];

/// The apps that belong to [category].
List<MigrationApp> migrationAppsFor(MigrationCategory category) =>
    migrationApps.where((app) => app.category == category).toList();
