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
import 'package:watchtower/utils/utils.dart';

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

// Palette fixe du design (le sheet MovieBox reste sombre, quel que soit le
// thème de l'application, pour rester fidèle au gabarit de référence).
const Color _kSheetBg = Color(0xFF0D0D0C);
const Color _kCardBg = Color(0xFF1E1E1E);
const Color _kFieldBg = Color(0xFF2A2A2A);
const Color _kText = Color(0xFFF4F4F4);
const Color _kMuted = Color(0xFF9B9B9B);
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

  // Film : sélection de flux (une ligne par qualité).
  final Set<Video> _selectedVideos = {};

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
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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

  /// Lignes du cas film : un gabarit répété pour chaque qualité, ordonnées par
  /// résolution croissante (360 → 1080, comme dans le gabarit de référence).
  List<Video> get _filmRows {
    final rows = _videos.toList();
    rows.sort((a, b) => _resRank(a.quality).compareTo(_resRank(b.quality)));
    return rows;
  }

  static int _resRank(String quality) {
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
          : (_filmRows.isNotEmpty ? <Video>[_filmRows.last] : const <Video>[]);

      if (_downloader == _Downloader.external) {
        if (picked.isEmpty) {
          botToast('Aucun lien disponible.');
          return;
        }
        if (mounted) Navigator.pop(context);
        for (final v in picked) {
          try {
            final launched = await ExternalDownloaderLauncher.launch(
              url: v.url,
              appId: _externalApp,
              headers: v.headers,
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
              .map((v) => prepareVideoQualityDownloadChapter(
                    chapter,
                    quality: _normQ(v.quality),
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

            if (!_loading) _buildBottomBar(isFilm, displayed),
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
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        source?.name?.trim().isNotEmpty == true
                            ? source!.name!.trim()
                            : 'l\'extension',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _kMuted, fontSize: 12.5),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Icon(Icons.help_outline_rounded, size: 16, color: _kMuted),
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
                label: _audioLabel(),
                onTap: _langs.length > 1
                    ? () => _showOptionSheet(
                          'Audio',
                          _langs,
                          _selectedLang ?? _langs.first,
                          (l) => setState(() {
                            _selectedLang = l;
                            _selected.clear();
                          }),
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

  // ── Lignes du cas FILM : un gabarit identique pour chaque qualité ────────────
  Widget _buildFilmRows() {
    final rows = _filmRows;
    if (rows.isEmpty) {
      return Center(
        child: Text('Aucune ressource disponible',
            style: TextStyle(color: _kMuted, fontSize: 13)),
      );
    }
    final meta = _rowMeta(widget.chapters.first);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      itemCount: rows.length,
      itemBuilder: (_, i) {
        final v = rows[i];
        final selected = _selectedVideos.contains(v);
        final rawQuality = v.quality.trim();
        return _buildSelectRow(
          selected: selected,
          onTap: () => setState(() {
            selected ? _selectedVideos.remove(v) : _selectedVideos.add(v);
          }),
          title: rawQuality.isEmpty ? 'Auto' : rawQuality,
          meta: meta,
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: Row(
          children: [
            Expanded(
              flex: 2,
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
                          style: TextStyle(color: _kText, fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: GestureDetector(
                onTap: _startDownload,
                child: Container(
                  height: 48,
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
                          color: Colors.black, size: 20),
                      SizedBox(width: 8),
                      Text('Télécharger',
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
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
            Divider(height: 1, thickness: 0.8, color: _kFieldBg),
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
          color: checked ? const Color(0xFF36E07D) : const Color(0xFF8A8A8A),
          width: 1.8,
        ),
      ),
      child: checked
          ? const Icon(Icons.check_rounded, color: Colors.black, size: 14)
          : null,
    );
  }
}
