import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
  import 'package:path/path.dart' as p;

  /// Parses a DexMovie filename into structured metadata.
  ///
  /// Supported patterns (spaces replaced by underscores):
  ///   SeriesName_[Language]_QualityP_SXX_EXX.mp4
  ///   SeriesName_QualityP_SXX_EXX.mp4
  ///   MovieName_[Language]_QualityP.mp4
  ///   MovieName_QualityP.mp4
  ///   SeriesName_QualityP_SXX_EXX_N.mp4   (N = part number)
  class DexMovieEntry {
    final String title;
    final String? language;
    final String quality;
    final int? season;
    final int? episode;
    final int? part;
    final String filePath;
    final bool isMovie;

    const DexMovieEntry({
      required this.title,
      this.language,
      required this.quality,
      this.season,
      this.episode,
      this.part,
      required this.filePath,
      required this.isMovie,
    });

    /// Human-readable episode key, e.g. "S01E06" or "Film".
    String get episodeKey {
      if (isMovie) return 'Film';
      final s = season?.toString().padLeft(2, '0') ?? '01';
      final e = episode?.toString().padLeft(2, '0') ?? '01';
      final pt = part != null ? '_${part}' : '';
      return 'S${s}E${e}$pt';
    }

    @override
    String toString() =>
        'DexMovieEntry(title=$title, lang=$language, q=$quality, '
        's=$season, e=$episode, part=$part, movie=$isMovie)';
  }

  class DexMovieScanner {
    // Regex: Title_[Lang]_QualityP[_SXX_EXX[_part]].mp4
    // Groups: 1=title, 2=lang(no brackets), 3=quality, 4=season, 5=episode, 6=part
    static final _re = RegExp(
      r'''^(.+?)_(?:\[(.+?)\]_)?([0-9]{3,4}[Pp])(?:_(S[0-9]+)_(E[0-9]+(?:_[0-9]+)?))?(?:_([0-9]+))?\.mp4$''',
      caseSensitive: false,
    );

    /// Parse a single filename (not path) into a [DexMovieEntry].
    /// Returns null if the filename doesn't match the expected pattern.
    static DexMovieEntry? parseFilename(String filename, String fullPath) {
      final m = _re.firstMatch(filename);
      if (m == null) return null;

      final rawTitle = m.group(1)!;
      final lang = m.group(2);
      final quality = m.group(3)!;
      final rawSeason = m.group(4);
      final rawEpisode = m.group(5);
      final rawPart = m.group(6);

      // Decode underscores back to spaces (DexMovie uses _ as word separator)
      final title = rawTitle.replaceAll('_', ' ').trim();

      int? season, episode, part;
      bool isMovie = rawSeason == null && rawEpisode == null;

      if (rawSeason != null) {
        season = int.tryParse(rawSeason.replaceAll(RegExp(r'[Ss]'), ''));
      }
      if (rawEpisode != null) {
        // Episode might be "E06_1" (part suffix after underscore)
        final parts = rawEpisode.replaceAll(RegExp(r'[Ee]'), '').split('_');
        episode = int.tryParse(parts[0]);
        if (parts.length > 1) part = int.tryParse(parts[1]);
      }
      if (rawPart != null && part == null) {
        part = int.tryParse(rawPart);
      }

      return DexMovieEntry(
        title: title,
        language: lang,
        quality: quality.toUpperCase(),
        season: season,
        episode: episode,
        part: part,
        filePath: fullPath,
        isMovie: isMovie,
      );
    }

    /// Scan a folder and return all recognized DexMovie entries.
    /// [folderPath] should be the full path to a folder like "DexMovie/Movie".
    static Future<List<DexMovieEntry>> scanFolder(String folderPath) async {
      final dir = Directory(folderPath);
      if (!await dir.exists()) return [];

      final entries = <DexMovieEntry>[];
      await for (final entity in dir.list(recursive: false, followLinks: false)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (!name.toLowerCase().endsWith('.mp4')) continue;
        final entry = parseFilename(name, entity.path);
        if (entry != null) entries.add(entry);
      }

      // Sort: by title, then season, then episode
      entries.sort((a, b) {
        final t = a.title.compareTo(b.title);
        if (t != 0) return t;
        final s = (a.season ?? 0).compareTo(b.season ?? 0);
        if (s != 0) return s;
        return (a.episode ?? 0).compareTo(b.episode ?? 0);
      });
      return entries;
    }

    /// Group entries by title (series/movie name).
    static Map<String, List<DexMovieEntry>> groupByTitle(List<DexMovieEntry> entries) {
      final map = <String, List<DexMovieEntry>>{};
      for (final e in entries) {
        (map[e.title] ??= []).add(e);
      }
      return map;
    }

    /// Candidate paths to scan for DexMovie content on Android.
    static List<String> candidatePaths() => [
      '/storage/emulated/0/DexMovie/Movie',
      '/sdcard/DexMovie/Movie',
      '/storage/emulated/0/Movies/DexMovie/Movie',
      '/storage/emulated/0/Download/DexMovie/Movie',
    ];

    /// Candidate paths for the Watchtower local source folder.
    static List<String> watchtowerLocalPaths() => [
      '/storage/emulated/0/Watchtower',
      '/storage/emulated/0/0/Watchtower',
      '/sdcard/Watchtower',
      '/sdcard/0/Watchtower',
    ];

    /// Finds and returns the first existing DexMovie folder on the device.
    static Future<String?> findDexMovieFolder() async {
      for (final path in candidatePaths()) {
        if (await Directory(path).exists()) return path;
      }
      return null;
    }

    /// Finds or creates the Watchtower local source folder.
    static Future<String?> findOrCreateWatchtowerFolder() async {
      for (final path in watchtowerLocalPaths()) {
        if (await Directory(path).exists()) return path;
      }
      // Try to create in the most likely location
      try {
        final dir = Directory('/storage/emulated/0/Watchtower');
        await dir.create(recursive: true);
        return dir.path;
      } catch (_) {}
      return null;
    }
  }
  