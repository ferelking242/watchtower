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

// ─────────────────────────────────────────────────────────────────────────────
// Sheet « Télécharger » — design MovieBox, extrait de watch_detail_view.dart
// (qui regroupait tout dans un seul fichier) pour devenir un module autonome.
//
// Deux variantes, selon la nature du contenu :
//   • Film (1 seul item)    : une ligne par qualité/flux disponible — le même
//     gabarit est répété pour chaque qualité, avec `poids | durée` en dessous.
//   • Série (plusieurs items) : carte « Ressources » avec les sélecteurs
//     Audio + Saison, boutons de qualité (360P … 1080P), puis la liste
//     d'épisodes — un cercle + `poids | durée` sous chaque titre.
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

  // Film : lignes qualité (une ligne par flux/qualité) + sélection.
  List<_FilmRow> _filmRows = [];
  int _filmMetaGeneration = 0;
  final Set<_FilmRow> _selectedVideos = {};

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

  bool get _isFilm {
    // 1 seul item et aucun marqueur série/épisode → film.
    if (widget.chapters.length != 1) return false;
    final name = widget.chapters.first.name ?? '';
    return !RegExp(
      r'(?:Saison|Season|Ep\.?\s*\d|S\d+\s*E\d+|\bE\d+)',
      caseSensitive: false,
    ).hasMatch(name);
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

    final rows = <_FilmRow>[
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
    rows.sort((a, b) => _resRank(a.label).compareTo(_resRank(b.label)));
    // Retire les doublons de libellé (plusieurs flux annonçant la même qualité).
    final seen = <String>{};
    rows.removeWhere((row) => !seen.add(row.label));
    _filmRows = rows;
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

    // 1) Dépliage des masters HLS.
    for (var i = 0; i < _filmRows.length; i++) {
      final row = _filmRows[i];
      if (row.metaDone || !isHlsUrl(row.video.url)) continue;
      row.metaDone = true;
      final hls = await fetchHlsMeta(row.video.url, row.video.headers);
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
      } else if (duration != null) {
        row.duration = duration;
      }
      setState(() {});
    }

    // 2) Fichiers directs : poids exact (entête Content-Range) puis durée
    //    conteneur. Une seule détection par URL si plusieurs lignes la partagent.
    final fetched = <String, (String?, int?)>{};
    for (final row in _filmRows) {
      if (row.metaDone) continue;
      row.metaDone = true;
      if (!fetched.containsKey(row.url)) {
        final size =
            formatBytes(await fetchDirectFileSize(row.url, row.headers));
        final seconds =
            await fetchDirectFileDuration(row.url, row.headers);
        if (!mounted || generation != _filmMetaGeneration) return;
        fetched[row.url] = (size, seconds);
      }
      final (size, seconds) = fetched[row.url]!;
      row
        ..size = (size ?? '').isNotEmpty ? size : row.size
        ..duration = seconds != null
            ? formatDurationSeconds(seconds)
            : row.duration;
      setState(() {});
    }
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
    final out = src.map((v) => _normQ(v.quality)).where(seen.add).toList();
    out.sort((a, b) => _resRank(a).compareTo(_resRank(b)));
    return out;
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
    final seen = <int>{};
    final result = <Chapter>[];
    for (var i = 0; i < base.length; i++) {
      if (seen.add(_episodeKeyNum(base[i], i))) result.add(base[i]);
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
      // Sélection vide → la meilleure qualité disponible (ordre croissant).
      final picked = _selectedVideos.isNotEmpty
          ? _selectedVideos.toList()
          : (_filmRows.isNotEmpty
              ? <_FilmRow>[_filmRows.last]
              : const <_FilmRow>[]);

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

            if (_loading)
              const LinearProgressIndicator(
                color: Color(0xFF36E07D),
                backgroundColor: Color(0xFF1E1E1E),
                minHeight: 2,
                borderRadius: BorderRadius.zero,
              ),

            if (_loading) ...[
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Color(0xFF36E07D),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text('Chargement…', style: TextStyle(color: _kMuted, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Carte « Ressources » (sélecteurs + boutons de qualité en série).
              _buildRessourcesCard(isFilm: isFilm, qualities: qualities),

              // Liste : film → une ligne par qualité · série → une par épisode.
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
          // ── Titre + ajouté par + aide ──
          Row(
            children: [
              Text('Ressources',
                  style: TextStyle(
                      color: _kText,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Flexible(
                fit: FlexFit.loose,
                child: Row(
                  children: [
                    Text('Ajouté par',
                        style: TextStyle(color: _kMuted, fontSize: 12.5)),
                    if (source != null) ...[
                      const SizedBox(width: 6),
                      // Logo de l'extension (cache disque partagé avec le reste
                      // de l'app).
                      ExtensionIconWidget(
                        sourceId: source.id,
                        iconUrl: source.iconUrl,
                        size: 18,
                      ),
                    ],
                    const SizedBox(width: 5),
                    Flexible(
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
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Sélecteurs : Audio (film & série) + Saison (série) ──
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _buildFieldButton(
                label: _audioLabel(),                onTap: _langs.length > 1
                    ? () => _showOptionSheet(
                          'Audio',
                          _langs,
                          _selectedLang ?? _langs.first,
                          (l) {
                            setState(() {
                              _selectedLang = l;
                              _selected.clear();
                              // Le film redevient les lignes qualité de cette
                              // langue ; la sélection courante est périmée.
                              _selectedVideos.clear();
                            });
                            if (_isFilm) _recomputeFilmRows();
                          },
                        )
                    : null,
              ),
              if (!isFilm && seasons.isNotEmpty)
                _buildFieldButton(
                  label: _selectedSeason ??
                      'Saison ${_twoDigits(seasons.first.replaceAll(RegExp(r'[^0-9]'), ''))}',
                  onTap: seasons.length > 1
                      ? () => _showOptionSheet(
                            'Saison',
                            seasons
                                .map((s) =>
                                    'Saison ${_twoDigits(s.replaceAll(RegExp(r'[^0-9]'), ''))}')
                                .toList(),
                            _selectedSeason ??
                                'Saison ${_twoDigits(seasons.first.replaceAll(RegExp(r'[^0-9]'), ''))}',
                            (s) => setState(() {
                              _selectedSeason =
                                  _selectedSeason == s ? null : s;
                              _selected.clear();
                            }),
                          )
                      : null,
                ),
            ],
          ),

          // ── Boutons de qualité — uniquement pour une série ──
          if (!isFilm && qualities.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(height: 1, thickness: 0.8, color: Colors.white.withValues(alpha: 0.08)),
            const SizedBox(height: 10),
            _buildQualityChips(qualities),
          ],
        ],
      ),
    );
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

  // ── Boutons de qualité (360P | 480P | 720P | 1080P) ─────────────────────────
  Widget _buildQualityChips(List<String> qualities) {
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          for (var i = 0; i < qualities.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: _buildQualityChip(qualities[i]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQualityChip(String quality) {
    final selected = _selectedQuality == quality;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedQuality = _selectedQuality == quality ? null : quality;
      }),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: selected ? _kActionGradient : null,
          color: selected ? null : _kFieldBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          quality.toUpperCase(),
          style: TextStyle(
            color: selected ? Colors.black : _kText,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ── Lignes du cas FILM : une ligne par qualité, `Qualité Titre` puis ───────
  // `poids réel | durée` en dessous.
  Widget _buildFilmRows() {
    if (_filmRows.isEmpty) {
      return Center(
        child: Text('Aucune ressource disponible',
            style: TextStyle(color: _kMuted, fontSize: 13)),
      );
    }
    final chapterName =
        (widget.chapters.isNotEmpty ? widget.chapters.first.name : '') ?? '';
    // Si le nom d'épisode commence déjà par une résolution, on l'enlève :
    // le gabarit remet le libellé de la ligne devant lui-même.
    final bareTitle = chapterName
        .replaceFirst(
            RegExp(r'^\s*\d{3,4}\s*[pP][\s·:\-–—]+'), '')
        .trim();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      itemCount: _filmRows.length,
      itemBuilder: (_, i) {
        final row = _filmRows[i];
        final selected = _selectedVideos.contains(row);
        final parts = <String>[];
        if ((row.size ?? '').trim().isNotEmpty) parts.add(row.size!.trim());
        if ((row.duration ?? '').trim().isNotEmpty) {
          parts.add(row.duration!.trim());
        }
        return _buildSelectRow(
          selected: selected,
          onTap: () => setState(() {
            selected ? _selectedVideos.remove(row) : _selectedVideos.add(row);
          }),
          title:
              '${row.label} $bareTitle'.trim(),
          meta: parts.join(' | '),
        );
      },
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
                  if (meta.isNotEmpty) ...[
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
        ? (_filmRows.isNotEmpty && _selectedVideos.length == _filmRows.length)
        : (displayed.isNotEmpty && _selected.length == displayed.length);

    void toggleAll() {
      setState(() {
        if (allChecked) {
          _selectedVideos.clear();
          _selected.clear();
        } else {
          if (isFilm) {
            _selectedVideos.addAll(_filmRows);
          } else {
            _selected.addAll(displayed);
          }
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
