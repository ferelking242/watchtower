import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/video.dart';
import 'package:watchtower/modules/manga/download/providers/download_provider.dart'
    show chapterPreferredLang, prepareVideoQualityDownloadChapter;
import 'package:watchtower/services/download_manager/download_settings_service.dart';
import 'package:watchtower/services/download_manager/external_downloader_launcher.dart';
import 'package:watchtower/services/get_video_list.dart';
import 'package:watchtower/services/icon_cache_service.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/watch/detail/download/video_file_meta.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';
import 'package:watchtower/utils/utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:watchtower/widgets/shimmer_skeleton.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Sheet « Télécharger » — design MovieBox, extrait de watch_detail_view.dart
// (qui regroupait tout dans un seul fichier) pour devenir un module autonome.
//
// Deux variantes, selon la nature du contenu :
//   • Film (1 seul item)    : UNE ligne (le titre) + des boutons de qualité
//     (uniquement les vraies résolutions disponibles, 144p → 8K) — aucun lineup
//     « 1080p film / 720p film ». Le poids | durée de la qualité choisie est
//     sous la ligne, en shimmer tant que le probe réseau n'a pas répondu.
//   • Série (plusieurs items) : carte « Ressources » avec les sélecteurs
//     Audio + Saison, boutons de qualité, puis la liste d'épisodes.
//
// Le CHARGEMENT du sheet est un squelette shimmer (pas un spinner) et les
// métadonnées (poids | durée) sont mises EN CACHE par URL : un poids déjà
// mesuré ne re-probe jamais le réseau et reste donc identique quel que soit
// le format affiché.
// ─────────────────────────────────────────────────────────────────────────────

// Dégradé d'action du design (bleu → vert) : c'est la marque du gabarit de
// référence, conservée quel que soit le thème. TOUTES les autres couleurs
// (fond du sheet, cartes, champs, textes) suivent le thème de l'application
// pour que le sheet soit exactement de la même teinte que le reste de la page.
const LinearGradient _kActionGradient = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [Color(0xFF1EA7EF), Color(0xFF36E07D)],
);

enum _Downloader { internal, external }

// ── Cache mémoire des métadonnées poids/durée, polite sur le réseau ──────────
// Clé = URL EXACTE du flux. Un poids déjà mesuré ne change jamais : rouvrir le
// sheet, changer de qualité ou de langue relit simplement ces valeurs.

class _UrlMeta {
  final String? sizeLabel; // « 259.9MB »
  final int? durationSeconds;
  const _UrlMeta({this.sizeLabel, this.durationSeconds});
}

final Map<String, _UrlMeta> kVideoDirectMetaCache = <String, _UrlMeta>{};
final Map<String, HlsMeta> kVideoHlsMetaCache = <String, HlsMeta>{};

void _trimMetaCaches() {
  if (kVideoDirectMetaCache.length > 800) kVideoDirectMetaCache.clear();
  if (kVideoHlsMetaCache.length > 800) kVideoHlsMetaCache.clear();
}

/// HLS master (ou playlist média) : un seul probe réseau par URL, en cache.
Future<HlsMeta?> cachedHlsMeta(String url, Map<String, String>? headers) {
  final hit = kVideoHlsMetaCache[url];
  if (hit != null) return Future.value(hit);
  return fetchHlsMeta(url, headers).then((meta) {
    if (meta != null) {
      _trimMetaCaches();
      kVideoHlsMetaCache[url] = meta;
    }
    return meta;
  });
}

/// Fichier direct : poids via `Content-Range` + durée conteneur, en cache.
Future<_UrlMeta?> cachedDirectMeta(String url, Map<String, String>? headers) async {
  final hit = kVideoDirectMetaCache[url];
  if (hit != null) return hit;
  String? size;
  int? seconds;
  try {
    final bytes = await fetchDirectFileSize(url, headers);
    if (bytes != null && bytes > 0) size = formatBytes(bytes);
  } catch (_) {
    // Poids indisponible : la durée reste cherchée.
  }
  try {
    seconds = await fetchDirectFileDuration(url, headers);
  } catch (_) {
    // Durée indisponible.
  }
  final meta = _UrlMeta(sizeLabel: size, durationSeconds: seconds);
  if (size != null || seconds != null) {
    _trimMetaCaches();
    kVideoDirectMetaCache[url] = meta;
  }
  return meta;
}

/// Ouvre le sheet « Télécharger » (barre transparente : la vidéo reste visible
/// et continue de jouer pendant la sélection).
Future<void> showWatchDownloadSheet({
  required BuildContext context,
  required Manga manga,
  required List<Chapter> chapters,
  required Future<void> Function(List<Chapter> selected) onDownload,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    elevation: 0,
    barrierColor: Colors.transparent,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    builder: (_) => WatchDownloadSheet(
      manga: manga,
      chapters: chapters,
      onDownload: onDownload,
    ),
  );
}

class WatchDownloadSheet extends ConsumerStatefulWidget {
  const WatchDownloadSheet({
    super.key,
    required this.manga,
    required this.chapters,
    required this.onDownload,
  });

  final Manga manga;
  final List<Chapter> chapters;
  final Future<void> Function(List<Chapter> selected) onDownload;

  @override
  ConsumerState<WatchDownloadSheet> createState() => _WatchDownloadSheetState();
}

class _WatchDownloadSheetState extends ConsumerState<WatchDownloadSheet> {
  // ── État ─────────────────────────────────────────────────────────────────────
  bool _loading = true;
  List<Video> _videos = [];

  // Film : options de qualité (une chip = une vraie résolution) + choix.
  List<_FilmRow> _filmRows = [];
  int _filmMetaGeneration = 0;
  String? _filmQuality; // libellé de la chip sélectionnée (film).
  bool _filmItemSelected = true;

  /// Vraie résolution (144p → 8K) ? Tout le reste (Auto, MP4 (high),suite
  /// d'embellissement HD/FHD/SD sans numéro) est exclu des chips qualité : on
  /// ne montre QUE les qualités réellement disponibles.
  static bool _isRealResolution(String label) => _resRank(label) >= 144;

  // Série : sélection d'épisodes.
  final Set<Chapter> _selected = {};

  String? _selectedLang;
  String? _selectedSeason;
  String? _selectedQuality; // série uniquement (boutons 360P … 1080P)

  _Downloader _downloader = _Downloader.internal;
  String _externalApp = 'adm';

  // ── Regex partagées ──────────────────────────────────────────────────────────
  static final RegExp _langRe = RegExp(
    r'\b(VOSTFR|VOSTA|MULTI|ENGLISH|FRENCH|FRANÇAIS|SPANISH|ESPAÑOL|'
    r'JAPANESE|JAPONAIS|PORTUGUESE|PORTUGAIS|GERMAN|DEUTSCH|ITALIAN|'
    r'ITALIANO|KOREAN|CHINESE|ARABIC|RUSSIAN|VF|VO|EN|FR|JAP?|ENG?)\b',
    caseSensitive: false,
  );
  static final RegExp _seasonRe = RegExp(r'(?:[Ss]aison|[Ss]eason|\bS)[ ]*(\d+)');

  static final RegExp _seriesMarkerRe = RegExp(
    r'(?:Saison|Season|Ep\.?\s*\d|S\d+\s*E\d+|\bE\d+)',
    caseSensitive: false,
  );

  bool get _isFilm {
    // FIX — un film téléchargé en 360p puis ré-ouvert en 1080p produit des
    // chapitres DOUBLONS (même nom, stockés par le download de qualité) : le
    // sheet ne doit PAS les transformer en « série » à 2 épisodes.
    //   • un marqueur de série/épisode dans un nom → série (sauf 1 chapitre) ;
    //   • sinon : 1 seul nom distinct (même en doublons) → film.
    if (widget.chapters.isEmpty) return true;
    if (widget.chapters.length == 1) {
      return !_seriesMarkerRe.hasMatch(widget.chapters.first.name ?? '');
    }
    if (widget.chapters.any((c) => _seriesMarkerRe.hasMatch(c.name ?? ''))) {
      return false;
    }
    final names = widget.chapters
        .map((c) => (c.name ?? '').trim().toLowerCase())
        .toSet();
    return names.length <= 1;
  }

  // ── Palette : couleurs du THÈME de l'application ──────────────────────────────
  // Le sheet n'impose plus de noir fixe : il prend la même teinte que le reste
  // de la page, thème sombre comme clair.
  Color get _kSheetBg => Theme.of(context).scaffoldBackgroundColor;
  Color get _kCardBg => Theme.of(context).colorScheme.surfaceContainerHighest;
  Color get _kFieldBg => Theme.of(context).colorScheme.surface;
  Color get _kText => Theme.of(context).colorScheme.onSurface;
  Color get _kMuted => _kText.withValues(alpha: 0.55);
  Color get _kDivider => _kText.withValues(alpha: 0.14);

  // ── Init ──────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    final pref =
        DownloadSettingsService.instance.preferredExternalDownloader ?? '';
    if (pref.isNotEmpty) _externalApp = pref;
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    if (widget.chapters.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final result = await ref
          .read(getVideoListProvider(episode: widget.chapters.first).future);
      final videos = result.$1;
      final seen = <String>{};
      if (mounted) {
        setState(() {
          _videos = videos.where((v) => seen.add(v.originalUrl)).toList();
          _loading = false;
        });
        if (_isFilm) _recomputeFilmRows();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// (Re)construit les lignes du cas FILM et lance le remplissage du poids et
  /// de la durée. Sert aussi quand la langue (dropdown Audio) change.
  void _recomputeFilmRows() {
    final generation = ++_filmMetaGeneration;
    final chapter = widget.chapters.isEmpty ? null : widget.chapters.first;
    final fallbackSize = (chapter?.downloadSize ?? '').trim();
    final fallbackDuration = (chapter?.duration ?? '').trim();

    // Vidéos filtrées par langue (dropdown Audio du film).
    var source = _videos;
    final langs = _langs;
    final lang = _selectedLang ?? (langs.isNotEmpty ? langs.first : null);
    if (lang != null) {
      final filtered = source
          .where((v) => v.quality.toUpperCase().contains(lang))
          .toList();
      if (filtered.isNotEmpty) source = filtered;
    }

    var rows = <_FilmRow>[
      for (final v in source)
        _FilmRow(
          label: _normQ(v.quality),
          video: v,
          url: v.url,
          headers: v.headers,
          size: fallbackSize.isEmpty ? null : fallbackSize,
          duration: fallbackDuration.isEmpty ? null : fallbackDuration,
        ),
    ];
    // Retire les doublons de libellé (plusieurs flux annonçant la même
    // qualité), trie par résolution croissante, puis NE GARDE que les vraies
    // résolutions : Auto, « MP4 (high) » et consorts sortent des chips —
    // celles-ci ne portent que les qualités réellement disponibles.
    {
      final seen = <String>{};
      rows = rows.where((row) => seen.add(row.label)).toList()
        ..sort((a, b) => _resRank(a.label).compareTo(_resRank(b.label)));
      final real = rows.where((row) => _isRealResolution(row.label)).toList();
      if (real.isNotEmpty) rows = real;
    }
    _filmRows = rows;
    // Qualité sélectionnée : la chip choisie si elle existe toujours, sinon
    // la meilleure disponible (dernier élément de l'ordre croissant).
    if (_filmQuality == null || !rows.any((row) => row.label == _filmQuality)) {
      _filmQuality = rows.isEmpty ? null : rows.last.label;
    }
    setState(() {});
    _fillFilmMeta(generation);
  }

  /// Complète chaque ligne avec le POIDS RÉEL et la DURÉE, sans jamais
  /// télécharger la vidéo :
  ///   • HLS master → une ligne par variante, poids = BANDWIDTH × durée,
  ///     durée = somme des `#EXTINF` de la playlist média.
  ///   • Fichier direct (peu importe l'extension) → poids exact via
  ///     `Content-Range` et durée lue dans le conteneur (mvhd MP4, Duration
  ///     Matroska MKV/WebM), avec repli sur la durée persistée par le lecteur.
  Future<void> _fillFilmMeta(int generation) async {
    final chapter = widget.chapters.isEmpty ? null : widget.chapters.first;
    final fallbackDuration = (chapter?.duration ?? '').trim().isEmpty
        ? null
        : chapter?.duration;

    // 1) Dépliage des masters HLS — CHAQUE URL n'est probee qu'UNE fois :
    //    le cache repond instantanément aux prochains appels (autre format,
    //    autre ouverture du sheet), le poids n'évolue plus jamais.
    for (var i = 0; i < _filmRows.length; i++) {
      final row = _filmRows[i];
      if (row.metaDone || !isHlsUrl(row.video.url)) continue;
      row.metaDone = true;
      final hls = await cachedHlsMeta(row.video.url, row.video.headers);
      if (!mounted || generation != _filmMetaGeneration) return;
      final duration = hls?.durationLabel ?? fallbackDuration;
      if (hls != null && hls.tracks.isNotEmpty) {
        final variants = [
          for (final t in hls.tracks)
            _FilmRow(
              label: _normQ(t.label),
              video: row.video,
              url: t.url,
              headers: row.video.headers,
              size: formatBytes(t.estimatedBytes),
              duration: duration,
            ),
        ];
        for (final variant in variants) {
          variant.metaDone = true;
        }
        _filmRows
          ..[i] = variants.first
          ..insertAll(i + 1, variants.sublist(1));
        i += variants.length - 1;
      } else {
        // Playlist média simple : durée + poids du flux (exact si BYTERANGE,
        // estimé via Content-Range sinon).
        if (duration != null) row.duration = duration;
        final bytes = hls?.playlistBytesEstimate;
        if (bytes != null && bytes > 0) row.size = formatBytes(bytes);
      }
      setState(() {});
    }

    // 2) Fichiers directs : poids exact (entête Content-Range) puis durée
    //    conteneur — via le CACHE, une seule détection par URL pour toutes
    //    les opens du sheet.
    final fetched = <String, (String?, int?)>{};
    for (final row in _filmRows) {
      if (row.metaDone) continue;
      row.metaDone = true;
      if (!fetched.containsKey(row.url)) {
        final meta = await cachedDirectMeta(row.url, row.headers);
        if (!mounted || generation != _filmMetaGeneration) return;
        fetched[row.url] = (meta?.sizeLabel, meta?.durationSeconds);
      }
      final (size, seconds) = fetched[row.url]!;
      row
        ..size = (size ?? '').isNotEmpty ? size : row.size
        ..duration = seconds != null
            ? formatDurationSeconds(seconds)
            : row.duration;
      setState(() {});
    }

    if (!mounted || generation != _filmMetaGeneration) return;
    // Dédup FINAL : l'expansion master a pu recoller des variantes sur des
    // flux distincts qui annoncent la même qualité (ex. 2×360p dans le log
    // XNXX). Une seule chip par résolution, tri croissant.
    final seen = <String>{};
    final deduped = <_FilmRow>[];
    final sorted = [..._filmRows]
      ..sort((a, b) => _resRank(a.label).compareTo(_resRank(b.label)));
    for (final row in sorted) {
      if (seen.add(row.label)) deduped.add(row);
    }
    _filmRows = deduped;
    if (_filmQuality == null ||
        !deduped.any((row) => row.label == _filmQuality)) {
      _filmQuality = deduped.isEmpty ? null : deduped.last.label;
    }
    setState(() {});
  }

  // ── Dérivations ───────────────────────────────────────────────────────────────

  List<String> get _langs {
    final s = <String>{};
    for (final v in _videos) {
      final m = _langRe.firstMatch(v.quality);
      if (m != null) s.add(m.group(0)!.toUpperCase());
    }
    return s.toList()..sort();
  }

  List<String> get _seasons {
    final s = <String>{};
    for (final ch in widget.chapters) {
      final m = _seasonRe.firstMatch(ch.name ?? '');
      if (m != null) s.add('Saison ${m.group(1)}');
    }
    return s.toList()..sort();
  }

  static int _resRank(String quality) {
    final s = quality.toLowerCase();
    if (s.contains('4k') || s.contains('2160')) return 2160;
    if (s.contains('8k') || s.contains('4320')) return 4320;
    final m = RegExp(
      r'(240|360|480|540|720|1080|1440|2160|4320)',
    ).firstMatch(quality);
    return m == null ? 0 : int.tryParse(m.group(1)!) ?? 0;
  }

  static String _normQ(String raw) {
    if (raw.trim().isEmpty) return 'Auto';
    final s = raw.toLowerCase();
    if (s.contains('8k') || s.contains('4320')) return '8K';
    if (s.contains('4k') || s.contains('2160')) return '4K';
    final resolution = RegExp(
      r'(1440|1080|720|540|480|360|240)\s*p?',
      caseSensitive: false,
    ).firstMatch(raw);
    if (resolution != null) return '${resolution.group(1)}p';
    if (s.contains('fhd')) return '1080P';
    if (s.contains('hd')) return '720P';
    if (s.contains('sd')) return '480P';
    return raw.trim();
  }

  List<String> get _qualities {
    var src = _videos;
    if (_selectedLang != null) {
      final f = src
          .where((v) => v.quality.toUpperCase().contains(_selectedLang!))
          .toList();
      if (f.isNotEmpty) src = f;
    }
    final seen = <String>{};
    final out = src.map((v) => _normQ(v.quality)).where(seen.add).toList()
      ..sort((a, b) => _resRank(a).compareTo(_resRank(b)));
    // Uniquement les VRAIES résolutions ; si un flux n'annonçe aucune
    // résolution reconnue, on retombe sur tout (lecteur sinon inutilisable).
    final real = out.where(_isRealResolution).toList();
    return real.isNotEmpty ? real : out;
  }

  /// Déduplication par numéro d'épisode (sources multi-qualité).
  static int _episodeKeyNum(Chapter ch, int fallback) {
    final name = ch.name ?? '';
    final em = RegExp(
      r'(?:Ep\.?|Episode)\s*(\d+)',
      caseSensitive: false,
    ).firstMatch(name);
    if (em != null) return int.tryParse(em.group(1)!) ?? fallback;
    final all = RegExp(r'\d+').allMatches(name).toList();
    if (all.isNotEmpty) return int.tryParse(all.last.group(0)!) ?? fallback;
    return fallback;
  }

  List<Chapter> get _displayChapters {
    List<Chapter> base;
    if (_selectedSeason == null) {
      base = widget.chapters;
    } else {
      final num = _selectedSeason!.replaceAll('Saison ', '');
      base = widget.chapters.where((ch) {
        final m = _seasonRe.firstMatch(ch.name ?? '');
        return m != null && m.group(1) == num;
      }).toList();
    }
    // Dédup : par numéro d'épisode quand le nom en porte un, sinon par NOM —
    // un doublon de téléchargement n'apparaît jamais deux fois dans la liste.
    final seen = <String>{};
    final result = <Chapter>[];
    for (var i = 0; i < base.length; i++) {
      final name = (base[i].name ?? '').trim();
      final key = RegExp(r'\d').hasMatch(name)
          ? 'n${_episodeKeyNum(base[i], i)}'
          : 't${name.toLowerCase()}';
      if (seen.add(key)) result.add(base[i]);
    }
    return result;
  }

  static String _twoDigits(String? n) => (n ?? '').trim().padLeft(2, '0');

  /// Titre d'épisode façon MovieBox : `S01 E02 · Chapter 2` (le suffixe reste
  /// facultatif, les épisodes au nom sans libellé n'affichent que Sxx Exx).
  String _seriesLabel(Chapter ch, int index) {
    final name = (ch.name ?? '').trim();
    var season = _selectedSeason?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    final sm = _seasonRe.firstMatch(name);
    if (season.isEmpty && sm != null) season = sm.group(1) ?? '';

    final em = RegExp(
      r'(?:Ep\.?|Episode)\s*(\d+)',
      caseSensitive: false,
    ).firstMatch(name);
    String ep;
    if (em != null) {
      ep = em.group(1)!;
    } else {
      final all = RegExp(r'\d+').allMatches(name).toList();
      ep = all.isNotEmpty ? all.last.group(0)! : '${index + 1}';
    }

    var rest = name;
    if (sm != null) rest = rest.replaceFirst(sm.group(0)!, '');
    if (em != null) rest = rest.replaceFirst(em.group(0)!, '');
    rest = rest
        .replaceAll(RegExp(r'^\s*[·:&\-–—]+\s*|\s*[·:&\-–—]+\s*$'), '')
        .trim();

    final base = 'S${_twoDigits(season)} E${_twoDigits(ep)}';
    return rest.isEmpty ? base : '$base · $rest';
  }

  /// `poids | durée` sous chaque titre — présent uniquement si l'API le fournit.
  String _rowMeta(Chapter ch) {
    final parts = <String>[];
    final size = (ch.downloadSize ?? '').trim();
    final duration = (ch.duration ?? '').trim();
    if (size.isNotEmpty) parts.add(size);
    if (duration.isNotEmpty) parts.add(duration);
    return parts.join(' | ');
  }

  String _audioLabel() {
    final langs = _langs;
    if (_selectedLang != null) return _prettyLang(_selectedLang!);
    return langs.isEmpty ? 'Audio original' : _prettyLang(langs.first);
  }

  static String _prettyLang(String raw) => raw.isEmpty
      ? raw
      : '${raw[0].toUpperCase()}${raw.substring(1).toLowerCase()}';

  // ── Action de téléchargement ─────────────────────────────────────────────────
  Future<void> _startDownload() async {
    // ── Film : pas de sélection d'épisode, le choix porte sur les qualités. ──
    if (_isFilm) {
      if (widget.chapters.isEmpty) return;
      final chapter = widget.chapters.first;
      // Le choix porte sur la CHIP qualité ; sans sélection, la meilleure
      // qualité disponible (ordre croissant).
      final picked = <_FilmRow>[
        if (_filmItemSelected && _filmRows.isNotEmpty)
          _filmRows.lastWhere((row) => row.label == _filmQuality,
              orElse: () => _filmRows.last),
      ];

      if (_downloader == _Downloader.external) {
        if (picked.isEmpty) {
          botToast('Aucun lien disponible.');
          return;
        }
        if (mounted) Navigator.pop(context);
        for (final row in picked) {
          try {
            final launched = await ExternalDownloaderLauncher.launch(
              url: row.url,
              appId: _externalApp,
              headers: row.headers,
            );
            if (!launched && mounted) {
              botToast(
                  'Impossible d\'ouvrir $_externalApp — vérifiez qu\'il est installé.');
            }
          } catch (e) {
            if (mounted) botToast(e.toString().split('\n').first);
          }
        }
        return;
      }

      final queue = picked.isEmpty
          ? <Chapter>[chapter]
          : picked
              .map((row) => prepareVideoQualityDownloadChapter(
                    chapter,
                    quality: row.label,
                    language: _selectedLang,
                  ))
              .toList();
      if (mounted) Navigator.pop(context);
      await widget.onDownload(queue);
      return;
    }

    // ── Série : comportement historique ──
    // Sélectionner des épisodes est facultatif : une sélection vide signifie
    // « télécharger tous les épisodes affichés ».
    final chapters = _selected.isEmpty ? _displayChapters : _selected.toList();
    if (chapters.isEmpty) {
      botToast('Aucun épisode disponible.');
      return;
    }

    if (_downloader == _Downloader.external) {
      if (mounted) Navigator.pop(context);
      for (final ch in chapters) {
        try {
          final result = await ref.read(getVideoListProvider(episode: ch).future);
          var videos = result.$1;
          if (videos.isEmpty) {
            botToast('Aucun lien pour ${ch.name ?? '?'}');
            continue;
          }
          if (_selectedLang != null && _langs.length > 1) {
            final lm = videos
                .where((v) =>
                    v.quality.toUpperCase().contains(_selectedLang!.toUpperCase()))
                .toList();
            if (lm.isNotEmpty) videos = lm;
          }
          Video best = videos.first;
          if (_selectedQuality != null) {
            final match = videos.cast<Video?>().firstWhere(
                  (v) => _normQ(v!.quality) == _selectedQuality,
                  orElse: () => null,
                );
            if (match != null) best = match;
          }
          final launched = await ExternalDownloaderLauncher.launch(
            url: best.url,
            appId: _externalApp,
            headers: best.headers,
          );
          if (!launched && mounted) {
            botToast(
                'Impossible d\'ouvrir $_externalApp — vérifiez qu\'il est installé.');
          }
        } catch (e) {
          if (mounted) botToast(e.toString().split('\n').first);
        }
      }
      return;
    }

    var queueChapters = chapters;
    if (_selectedQuality != null) {
      queueChapters = chapters
          .map(
            (chapter) => prepareVideoQualityDownloadChapter(
              chapter,
              quality: _selectedQuality!,
              language: _selectedLang,
            ),
          )
          .toList();
    } else if (_selectedLang != null && _langs.length > 1) {
      for (final chapter in chapters) {
        if (chapter.id != null) {
          chapterPreferredLang[chapter.id!] = _selectedLang!;
        }
      }
    }
    if (mounted) Navigator.pop(context);
    await widget.onDownload(queueChapters);
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final statusH = MediaQuery.of(context).padding.top;
    final maxH = screenH - 230 - statusH;

    final isFilm = _isFilm;
    final displayed = isFilm ? const <Chapter>[] : _displayChapters;
    final qualities = _qualities;

    return Container(
      height: maxH,
      color: _kSheetBg,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Barre de titre (pas de poignée de glissement).
            _sheetTopBar(),

            if (_loading) ...[
              // Chargement du sheet = SQUELETTE SHIMMER (carte Ressources +
              // quelques lignes), pas un spinner.
              Expanded(child: _buildLoadingSkeleton()),
            ] else ...[
              // Carte « Ressources » (sélecteurs + boutons de qualité).
              _buildRessourcesCard(isFilm: isFilm, qualities: qualities),

              // Liste : film → UNE ligne (l'item, poids|durée de la qualité
              // choisie dessous) · série → une ligne par épisode.
              Expanded(
                child: isFilm ? _buildFilmRows() : _buildSeriesRows(displayed),
              ),
            ],

            if (!_loading) ...[
              // Séparateur au-dessus de la barre d'actions (gabarit MovieBox).
              Divider(
                  height: 1,
                  thickness: 0.8,
                  color: _kDivider),
              _buildBottomBar(isFilm, displayed),
            ],
          ],
        ),
      ),
    );
  }

  // ── Barre de titre ────────────────────────────────────────────────────────────
  Widget _sheetTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          Text('Télécharger',
              style: TextStyle(
                  color: _kText, fontSize: 17, fontWeight: FontWeight.w700)),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.close_rounded, color: _kMuted, size: 22),
          ),
        ],
      ),
    );
  }

  // ── Carte « Ressources · Ajouté par … (?) » ──────────────────────────────────
  Widget _buildRessourcesCard({
    required bool isFilm,
    required List<String> qualities,
  }) {
    final source = getSource(
      widget.manga.lang ?? '',
      widget.manga.source ?? '',
      widget.manga.sourceId,
    );
    final seasons = _seasons;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Titre + « ajouté par (logo + nom) » TOUT À DROITE + aide ──
          Row(
            children: [
              Text('Ressources',
                  style: TextStyle(
                      color: _kText,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('Ajouté par',
                  style: TextStyle(color: _kMuted, fontSize: 12.5)),
              if (source != null) ...[
                const SizedBox(width: 6),
                // Logo de l'extension (cache disque partagé avec le reste
                // de l'app).
                ExtensionIconWidget(
                  sourceId: source.id,
                  iconUrl: source.iconUrl,
                  size: 16,
                ),
              ],
              const SizedBox(width: 5),
              Flexible(
                fit: FlexFit.loose,
                child: Text(
                  source?.name?.trim().isNotEmpty == true
                      ? source!.name!.trim()
                      : 'l\'extension',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: _kText,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 6),
              // « ? » → détails de l'extension : nom, liens, langue, version.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: source == null ? null : () => _showSourceDetails(source),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(Icons.help_outline_rounded,
                      size: 16, color: _kMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),          // ── Sélecteurs : affichés SEULEMENT quand il y a un vrai choix ──
          // Box langue uniquement si plusieurs langues, box saison uniquement
          // si la série a plusieurs saisons.
          if (_langs.length > 1 || (!isFilm && seasons.length > 1))
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                if (_langs.length > 1)
                  _buildFieldButton(
                    label: _audioLabel(),
                    onTap: () => _showOptionSheet(
                      'Audio',
                      _langs,
                      _selectedLang ?? _langs.first,
                      (l) {
                        setState(() {
                          _selectedLang = l;
                          _selected.clear();
                          // Le film redevient les options qualité de cette
                          // langue ; la chip courante est périmée.
                          _filmQuality = null;
                        });
                        if (_isFilm) _recomputeFilmRows();
                      },
                    ),
                  ),
                if (!isFilm && seasons.length > 1)
                  _buildFieldButton(
                    label: _selectedSeason ??
                        'Saison ${_twoDigits(seasons.first.replaceAll(RegExp(r'[^0-9]'), ''))}',
                    onTap: () => _showOptionSheet(
                      'Saison',
                      seasons
                          .map((s) =>
                              'Saison ${_twoDigits(s.replaceAll(RegExp(r'[^0-9]'), ''))}')
                          .toList(),
                      _selectedSeason ??
                          'Saison ${_twoDigits(seasons.first.replaceAll(RegExp(r'[^0-9]'), ''))}',
                      (s) => setState(() {
                        _selectedSeason = _selectedSeason == s ? null : s;
                        _selected.clear();
                      }),
                    ),
                  ),
              ],
            ),

          // ── Boutons de qualité — FILM ET SÉRIE : uniquement les vraies
          //    résolutions réellement disponibles (jamais de Auto/MP4/high…).
          if (isFilm ? _filmChips.isNotEmpty : qualities.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(height: 1, thickness: 0.8, color: _kDivider),
            const SizedBox(height: 10),
            isFilm
                ? _buildQualityChipSet(
                    chips: _filmChips,
                    selected: _filmQuality,
                    onSelect: (quality) => setState(
                        () => _filmQuality =
                            _filmQuality == quality ? null : quality),
                  )
                : _buildQualityChipSet(
                    chips: _seriesQualities(qualities),
                    selected: _selectedQuality,
                    onSelect: (quality) => setState(
                        () => _selectedQuality =
                            _selectedQuality == quality ? null : quality),
                  ),
          ],
        ],
      ),
    );
  }

  /// Qualités affichées pour une série : UNIQUEMENT les vraies résolutions
  /// détectées (plus de base MovieBox injectée « dans le vide »).
  List<String> _seriesQualities(List<String> detected) {
    final real = detected.where(_isRealResolution).toList()
      ..sort((a, b) => _resRank(a).compareTo(_resRank(b)));
    return real.isNotEmpty ? real : detected;
  }

  // ── Bouton de champ (« Original Audio ▾ », « Saison 01 ▾ ») ──────────────────
  Widget _buildFieldButton({required String label, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _kFieldBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    color: _kText,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Icon(Icons.keyboard_arrow_down_rounded, color: _kText, size: 18),
          ],
        ),
      ),
    );
  }

  /// Chips qualité du cas film : les options déjà résolues (lignes) puis,
  /// pendant le chargement, les qualités détectées sur les flux bruts.
  List<String> get _filmChips {
    final fromRows =
        _filmRows.map((row) => row.label).where(_isRealResolution).toList();
    return fromRows.isNotEmpty ? fromRows : _qualities;
  }

  // ── Boutons de qualité (360P | 480P | 720P | 1080P) ─────────────────────────
  // ≤ 6 qualités : une rangée à parts égales (gabarit MovieBox). Au-delà :
  // plusieurs rangées (Wrap) — aucune chip n'est jamais écrasée.
  Widget _buildQualityChipSet({
    required List<String> chips,
    required String? selected,
    required void Function(String quality) onSelect,
  }) {
    Widget chip(String quality, {bool compact = false}) {
      final isSel = selected == quality;
      return GestureDetector(
        onTap: () => onSelect(quality),
        child: Container(
          height: 42,
          alignment: Alignment.center,
          padding: compact ? const EdgeInsets.symmetric(horizontal: 10) : null,
          decoration: BoxDecoration(
            gradient: isSel ? _kActionGradient : null,
            color: isSel ? null : _kFieldBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            quality.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isSel ? Colors.black : _kText,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    if (chips.length <= 6) {
      return SizedBox(
        height: 42,
        child: Row(
          children: [
            for (var i = 0; i < chips.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(child: chip(chips[i])),
            ],
          ],
        ),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final quality in chips)
          SizedBox(
            width: 68,
            child: chip(quality, compact: true),
          ),
      ],
    );
  }

  // ── Lignes du cas FILM : UNE ligne (le titre), `poids | durée` de la qualité
  // choisie en dessous — shimmer tant que le probe réseau n'a pas répondu.
  Widget _buildFilmRows() {
    if (_videos.isEmpty && !_loading) {
      return Center(
        child: Text('Aucune ressource disponible',
            style: TextStyle(color: _kMuted, fontSize: 13)),
      );
    }
    final chapterName =
        (widget.chapters.isNotEmpty ? widget.chapters.first.name : '') ?? '';
    // Si le nom commence déjà par une résolution, on l'enlève : le titre de
    // l'item est affiché seul, la qualité est choisie par les chips.
    final bareTitle = chapterName
        .replaceFirst(
            RegExp(r'^\s*\d{3,4}\s*[pP][\s·:\-–—]+'), '')
        .trim();

    // Poids | durée de la qualité SÉLECTIONNÉE ; shimmer tant que le probe
    // réseau n'a pas répondu, rien si le flux n'expose aucune métadonnée.
    _FilmRow? selectedRow;
    if (_filmRows.isNotEmpty) {
      for (final row in _filmRows.reversed) {
        if (row.label == _filmQuality) {
          selectedRow = row;
          break;
        }
      }
      selectedRow ??= _filmRows.last;
    }
    Widget meta;
    if (selectedRow != null && (selectedRow.metaDone ||
        ((selectedRow.size ?? '').isNotEmpty ||
            (selectedRow.duration ?? '').isNotEmpty))) {
      final parts = <String>[];
      if ((selectedRow.size ?? '').trim().isNotEmpty) {
        parts.add(selectedRow.size!.trim());
      }
      if ((selectedRow.duration ?? '').trim().isNotEmpty) {
        parts.add(selectedRow.duration!.trim());
      }
      meta = Text(parts.join(' | '),
          style: TextStyle(color: _kMuted, fontSize: 12.5));
    } else {
      // En cours de probe : deux barres shimmer (poids + durée).
      meta = ShimmerSkeleton(
        effect: _shimmerEffect,
        child: Row(
          children: [
            _shimmerBone(width: 64, height: 12),
            const SizedBox(width: 10),
            _shimmerBone(width: 42, height: 12),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      children: [
        _buildSelectRow(
          selected: _filmItemSelected,
          onTap: () => setState(() => _filmItemSelected = !_filmItemSelected),
          title: bareTitle,
          meta: '',
          metaWidget: meta,
        ),
      ],
    );
  }

  Widget _shimmerBone({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }

  /// Squelette shimmer du chargement global du sheet : carte Ressources +
  /// rangées fantômes (le gabarit des vraies lignes).
  ShimmerEffect get _shimmerEffect {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ShimmerEffect(
      baseColor:
          isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E7),
      highlightColor:
          isDark ? const Color(0xFF3B3B3F) : const Color(0xFFF6F6F8),
    );
  }

  Widget _buildLoadingSkeleton() {
    final effect = _shimmerEffect;
    Widget bone(double? w, double h, {double r = 8}) {
      return Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(r),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Carte « Ressources » fantôme.
          ShimmerSkeleton(
            effect: effect,
            child: Container(
              height: 92,
              decoration: BoxDecoration(
                color: _kCardBg,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              children: [
                for (var i = 0; i < 5; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: ShimmerSkeleton(
                      effect: effect,
                      child: Row(
                        children: [
                          bone(null, 22, r: 11),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FractionallySizedBox(
                                  widthFactor: 0.78 - i * 0.08,
                                  alignment: Alignment.centerLeft,
                                  child: bone(null, 14),
                                ),
                                const SizedBox(height: 8),
                                FractionallySizedBox(
                                  widthFactor: 0.38,
                                  alignment: Alignment.centerLeft,
                                  child: bone(null, 11, r: 5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Lignes du cas SÉRIE : une ligne par épisode ──────────────────────────────
  Widget _buildSeriesRows(List<Chapter> displayed) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      itemCount: displayed.length,
      itemBuilder: (_, i) {
        final chapter = displayed[i];
        final selected = _selected.contains(chapter);
        return _buildSelectRow(
          selected: selected,
          onTap: () => setState(() {
            selected ? _selected.remove(chapter) : _selected.add(chapter);
          }),
          title: _seriesLabel(chapter, i),
          meta: _rowMeta(chapter),
        );
      },
    );
  }

  Widget _buildSelectRow({
    required bool selected,
    required VoidCallback onTap,
    required String title,
    required String meta,
    Widget? metaWidget,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
        child: Row(
          children: [
            _SelectCircle(checked: selected),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: _kText,
                          fontSize: 15,
                          fontWeight: FontWeight.w500)),
                  if (metaWidget != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: metaWidget,
                    )
                  else if (meta.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(meta,
                        style: TextStyle(color: _kMuted, fontSize: 12.5)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Barre d'actions basse : « Tout sélectionner » + « ⬇ Télécharger » ────────
  Widget _buildBottomBar(bool isFilm, List<Chapter> displayed) {
    final allChecked = isFilm
        ? _filmItemSelected
        : (displayed.isNotEmpty && _selected.length == displayed.length);

    void toggleAll() {
      setState(() {
        if (isFilm) {
          _filmItemSelected = !allChecked;
        } else if (allChecked) {
          _selected.clear();
        } else {
          _selected.addAll(displayed);
        }
      });
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: toggleAll,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      _SelectCircle(checked: allChecked),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          'Tout sélectionner',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _kText, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: _startDownload,
                child: Container(
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: _kActionGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.download_rounded,
                          color: Colors.black, size: 18),
                      SizedBox(width: 7),
                      Text('Télécharger',
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Détails de l'extension (via le « ? » de la carte Ressources) ────────────
  void _showSourceDetails(Source source) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor:
            Theme.of(dialogContext).colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
        title: Row(
          children: [
            ExtensionIconWidget(
              sourceId: source.id,
              iconUrl: source.iconUrl,
              size: 34,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                source.name?.trim().isNotEmpty == true
                    ? source.name!.trim()
                    : 'Extension',
                style: TextStyle(
                    color: Theme.of(dialogContext).colorScheme.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sourceDetailRow(dialogContext, 'Site web', source.baseUrl,
                launchTarget: source.baseUrl),
            _sourceDetailRow(dialogContext, 'Code source', source.sourceCodeUrl,
                launchTarget: source.sourceCodeUrl),
            _sourceDetailRow(
                dialogContext, 'Langue', source.lang?.toUpperCase()),
            _sourceDetailRow(dialogContext, 'Version', source.version),
            _sourceDetailRow(dialogContext, 'Type', source.typeSource),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Fermer',
                style: TextStyle(
                    color: context.primaryColor, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _sourceDetailRow(
    BuildContext dialogContext,
    String label,
    String? value, {
    String? launchTarget,
  }) {
    final trimmed = (value ?? '').trim();
    final has = trimmed.isNotEmpty;
    final onSurface = Theme.of(dialogContext).colorScheme.onSurface;
    final faintColor = onSurface.withValues(alpha: 0.55);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child:
                Text(label, style: TextStyle(color: faintColor, fontSize: 13)),
          ),
          Expanded(
            child: has
                ? GestureDetector(
                    onTap: launchTarget != null && launchTarget.trim().isNotEmpty
                        ? () => _openExternal(launchTarget)
                        : null,
                    child: Text(
                      trimmed,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: launchTarget != null
                            ? context.primaryColor
                            : onSurface,
                        fontSize: 13,
                        decoration: launchTarget != null
                            ? TextDecoration.underline
                            : TextDecoration.none,
                      ),
                    ),
                  )
                : Text('—', style: TextStyle(color: faintColor, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Future<void> _openExternal(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // L'ouverture web n'est pas critique : échec ignoré.
    }
  }

  // ── Feuille de choix (Audio / Saison) ────────────────────────────────────────
  void _showOptionSheet(
    String title,
    List<String> items,
    String? selectedValue,
    void Function(String) onSelect,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _kSheetBg,
      elevation: 0,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
              child: Row(
                children: [
                  Text(title,
                      style: TextStyle(
                          color: _kText,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Icon(Icons.close_rounded, size: 20, color: _kMuted),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 0.8, color: _kDivider),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: items.map((item) {
                  final sel = item == selectedValue;
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      onSelect(item);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: sel ? _kActionGradient : null,
                        color: sel ? null : _kFieldBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        item,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: sel ? Colors.black : _kText,
                          fontSize: 14,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Ligne qualité du cas film ───────────────────────────────────────────────────
// Une ligne = un flux téléchargeable (variante HLS ou fichier direct + échelle
// de qualités standard selon le gabarit MovieBox), avec son poids et sa durée.
class _FilmRow {
  /// Libellé affiché (ex. `480P`).
  final String label;

  /// Flux d'origine fourni par l'extension (pour la référence HLS).
  final Video video;

  /// URL à passer au downloader externe : variante HLS dépliée si connue,
  /// sinon l'URL d'origine.
  final String url;

  final Map<String, String>? headers;

  /// Poids affiché (« 259.9MB ») ; rempli après la détection réseau.
  String? size;

  /// Durée affichée (« 13:17 », « 2:37:01 »).
  String? duration;

  /// Vrai tant que la détection poids/durée n'a pas encore été tentée.
  bool metaDone = false;

  _FilmRow({
    required this.label,
    required this.video,
    required this.url,
    this.headers,
    this.size,
    this.duration,
  });
}

// ── Cercle de sélection (cercle contour, rempli quand coché) ─────────────────
class _SelectCircle extends StatelessWidget {
  const _SelectCircle({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: checked ? _kActionGradient.colors.last : Colors.transparent,
        border: Border.all(
          color: checked
              ? _kActionGradient.colors.last
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
          width: 1.8,
        ),
      ),
      child: checked
          ? const Icon(Icons.check_rounded, color: Colors.black, size: 14)
          : null,
    );
  }
}
