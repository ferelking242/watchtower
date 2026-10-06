import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/download.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:watchtower/modules/manga/download/providers/download_provider.dart';
import 'package:watchtower/modules/more/settings/downloads/providers/downloads_state_provider.dart';
import 'package:watchtower/modules/plugin/nfile/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/services/download_manager/active_download_registry.dart';
import 'package:watchtower/utils/extensions/chapter.dart';
import 'package:watchtower/utils/extensions/string_extensions.dart';
import 'package:watchtower/utils/global_style.dart';
import 'package:watchtower/utils/log/logger.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import 'package:watchtower/utils/arrow_popup_menu.dart';
import 'package:watchtower/eval/model/m_bridge.dart' show botToast;

class ChapterPageDownload extends ConsumerWidget {
  final Chapter chapter;
  final Manga? manga;

  const ChapterPageDownload({super.key, required this.chapter, this.manga});

  /// Démarre (ou relance) le téléchargement du chapitre.
  ///
  /// TOUTE erreur est attrapée ici : le Future renvoyé à `onPressed` est
  /// ignoré par Flutter, donc la moindre exception (Isar corrompu, prefs…)
  /// atterrissait dans `runZonedGuarded` sans feedback — le bouton semblait
  /// mort et l'app "plantait" à chaque appui.
  Future<void> _startDownload(bool? useWifi, WidgetRef ref) async {
    final id = chapter.id;
    if (id == null) return;
    var stage = 'cancel previous worker';
    try {
      // Stoppe un éventuel transfert en cours et purge une entrée de registre
      // restée "active" (crash, tâche orpheline) : sinon `processDownloads`
      // considère le chapitre comme déjà en cours et ne le redémarre jamais.
      await ActiveDownloadRegistry.cancel(id);
      stage = 'read queue state';
      final queue = ref.read(downloadQueueStateProvider.notifier);
      stage = 'clear stale progress';
      queue.clearLiveProgress(id);
      stage = 'attach manga';
      final mangaForChapter = manga;
      if (mangaForChapter != null &&
          mangaForChapter.id != null &&
          chapter.mangaId == mangaForChapter.id) {
        chapter.manga.value = mangaForChapter;
      }
      stage = 'persist queue entry';
      await ref.read(addDownloadToQueueProvider(chapter: chapter).future);
      stage = 'unpause chapter';
      queue.setPaused(id, false);
      stage = 'start scheduler';
      ref.read(processDownloadsProvider(useWifi: useWifi));
    } catch (e, stackTrace) {
      AppLogger.log(
        'Download start failed during "$stage" for chapterId=$id',
        logLevel: LogLevel.warning,
        tag: LogTag.download,
        error: e,
        stackTrace: stackTrace,
      );
      botToast('Impossible de démarrer : ${friendlyErrorMessage(e)}');
    }
  }

  /// Reprend un chapitre mis en pause (le scheduler le reprend au tick suivant).
  void _resumeDownload(WidgetRef ref) {
    final id = chapter.id;
    try {
      if (id != null) {
        ref.read(downloadQueueStateProvider.notifier).setPaused(id, false);
      }
      ref.read(processDownloadsProvider());
    } catch (e) {
      botToast('Reprise impossible : ${friendlyErrorMessage(e)}');
    }
  }

  /// Annule le transfert et retire l'entrée de la file de téléchargement.
  Future<void> _cancelDownload(WidgetRef ref, int? downloadId) async {
    final id = chapter.id;
    try {
      if (id != null) {
        await ActiveDownloadRegistry.cancel(id);
        final queue = ref.read(downloadQueueStateProvider.notifier);
        queue.clearLiveProgress(id);
        // Ne pas laisser le chapitre en pause : une future demande de
        // téléchargement doit pouvoir repartir immédiatement.
        queue.setPaused(id, false);
      }
      chapter.cancelDownloads(downloadId);
    } catch (e) {
      botToast('Annulation impossible : ${friendlyErrorMessage(e)}');
    }
  }

  void _sendFile(BuildContext context) async {
    final storageProvider = StorageProvider();
    final mangaDir = await storageProvider.getMangaMainDirectory(chapter);
    final path = await storageProvider.getMangaChapterDirectory(
      chapter,
      mangaMainDirectory: mangaDir,
    );

    List<XFile> files = [];

    final cbzFile = File(p.join(mangaDir!.path, "${chapter.name}.cbz"));
    final mp4File = File(
      p.join(
        mangaDir.path,
        "${chapter.name!.replaceForbiddenCharacters(' ')}.mp4",
      ),
    );
    final htmlFile = File(p.join(mangaDir.path, "${chapter.name}.html"));
    if (cbzFile.existsSync()) {
      files = [XFile(cbzFile.path)];
    } else if (mp4File.existsSync()) {
      files = [XFile(mp4File.path)];
    } else if (htmlFile.existsSync()) {
      files = [XFile(htmlFile.path)];
    } else {
      files = path!.listSync().map((e) => XFile(e.path)).toList();
    }
    if (files.isNotEmpty && context.mounted) {
      final box = context.findRenderObject() as RenderBox?;
      SharePlus.instance.share(
        ShareParams(
          files: files,
          text: chapter.name,
          sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
        ),
      );
    }
  }

  void _deleteFile(int downloadId) async {
    final storageProvider = StorageProvider();
    final mangaDir = await storageProvider.getMangaMainDirectory(chapter);
    final path = await storageProvider.getMangaChapterDirectory(
      chapter,
      mangaMainDirectory: mangaDir,
    );

    try {
      try {
        final cbzFile = File(p.join(mangaDir!.path, "${chapter.name}.cbz"));
        if (cbzFile.existsSync()) {
          cbzFile.deleteSync();
        }
      } catch (_) {}
      try {
        final mp4File = File(
          p.join(
            mangaDir!.path,
            "${chapter.name!.replaceForbiddenCharacters(' ')}.mp4",
          ),
        );
        if (mp4File.existsSync()) {
          mp4File.deleteSync();
        }
      } catch (_) {}
      try {
        final htmlFile = File(p.join(mangaDir!.path, "${chapter.name}.html"));
        if (htmlFile.existsSync()) {
          htmlFile.deleteSync();
        }
      } catch (_) {}
      path!.deleteSync(recursive: true);
    } catch (_) {}
    chapter.cancelDownloads(downloadId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = l10nLocalizations(context)!;
    final id = chapter.id;
    // Sélecteurs ciblés : sans eux, chaque tick de progression (n'importe quel
    // chapitre) reconstruirait TOUTES les tuiles de la liste.
    final isPaused = ref.watch(
      downloadQueueStateProvider.select(
        (state) => id != null && state.pausedIds.contains(id),
      ),
    );
    final liveProgress = ref.watch(
      downloadQueueStateProvider.select(
        (state) => id == null ? null : state.liveProgress[id],
      ),
    );
    final speed = ref.watch(
      downloadQueueStateProvider.select(
        (state) => id == null ? null : state.speeds[id],
      ),
    );
    return SizedBox(
      height: 41,
      width: 35,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: StreamBuilder<Download?>(
          // Watch only this chapter: a corrupt unrelated row must not prevent
          // its icon from receiving queue/progress updates.
          stream: id == null
              ? null
              : isar.downloads.watchObject(id, fireImmediately: true),
          builder: (context, snapshot) {
            return _buildTrailing(
              context,
              ref,
              l10n,
              snapshot.data,
              isPaused: isPaused,
              liveProgress: liveProgress,
              speed: speed,
            );
          },
        ),
      ),
    );
  }

  /// Icône / anneau de progression du chapitre, avec la progression visible
  /// directement dans la liste (pourcentage affiché à l'intérieur de l'anneau).
  Widget _buildTrailing(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    Download? download, {
    required bool isPaused,
    required DownloadLiveProgress? liveProgress,
    required double? speed,
  }) {
    final id = chapter.id;
    final color = Theme.of(context).iconTheme.color!.withValues(alpha: 0.7);
    final isCompleted = download?.isDownload ?? false;
    final hasFailed =
        download != null &&
        ((download.failed ?? 0) > 0 || download.status == 'failed');
    final isStarted = download?.isStartDownload ?? false;
    final succeeded = download?.succeeded ?? 0;
    final isActive =
        liveProgress != null ||
        (id != null && ActiveDownloadRegistry.isActive(id));
    final fraction = _progressFraction(download, liveProgress);
    final speedValue = speed;
    final String? speedLabel =
        (speedValue != null && speedValue >= 0.05)
        ? '${speedValue >= 10 ? speedValue.toStringAsFixed(0) : speedValue.toStringAsFixed(1)} MB/s'
        : null;

    // ── Terminé : lecture du fichier / suppression ──────────────────────────
    if (isCompleted) {
      return ArrowPopupMenuButton(
        popUpAnimationStyle: popupAnimationStyle,
        child: Icon(Broken.tick_circle, size: 25, color: color),
        onSelected: (value) {
          if (value == 0) {
            _sendFile(context);
          } else if (value == 1) {
            _deleteFile(download!.id!);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(value: 0, child: Text(l10n.send)),
          PopupMenuItem(value: 1, child: Text(l10n.delete)),
        ],
      );
    }

    // ── En pause : reprendre / annuler ─────────────────────────────────────
    if (isPaused) {
      return ArrowPopupMenuButton(
        popUpAnimationStyle: popupAnimationStyle,
        child: Icon(
          Broken.play,
          size: 22,
          color: Theme.of(context).colorScheme.primary,
        ),
        onSelected: (value) {
          if (value == 0) {
            _resumeDownload(ref);
          } else if (value == 1) {
            _cancelDownload(ref, download?.id);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(value: 0, child: Text(l10n.resume)),
          PopupMenuItem(value: 1, child: Text(l10n.cancel)),
        ],
      );
    }

    // ── Échec : l'utilisateur doit pouvoir réessayer (et savoir pourquoi) ──
    if (hasFailed) {
      return ArrowPopupMenuButton(
        popUpAnimationStyle: popupAnimationStyle,
        child: Icon(
          Broken.warning_2,
          color: Theme.of(context).colorScheme.error,
          size: 25,
        ),
        onSelected: (value) {
          if (value == 0) {
            _startDownload(null, ref);
          } else if (value == 1) {
            _cancelDownload(ref, download?.id);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(value: 0, child: Text(l10n.retry)),
          PopupMenuItem(value: 1, child: Text(l10n.cancel)),
        ],
      );
    }

    // ── En cours (ou en file) : anneau + pourcentage ───────────────────────
    if (isStarted || isActive) {
      return ArrowPopupMenuButton(
        popUpAnimationStyle: popupAnimationStyle,
        child: Tooltip(
          message: download?.status == 'waiting_wifi'
              ? 'En attente du Wi-Fi'
              : download?.status == 'fetching_metadata'
                  ? 'Récupération des métadonnées…'
                  : isActive
                      ? 'Téléchargement en cours'
                      : 'En attente de téléchargement',
          child: _progressBadge(
            value: isActive ? fraction : null,
            fraction: fraction,
            color: color,
          ),
        ),
        onSelected: (value) {
          if (value == 0) {
            _cancelDownload(ref, download?.id);
          }
        },
        itemBuilder: (context) => [
          if (speedLabel != null)
            PopupMenuItem(
              value: -1,
              enabled: false,
              height: 34,
              child: Text(
                speedLabel,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          PopupMenuItem(value: 0, child: Text(l10n.cancel)),
        ],
      );
    }

    // ── Interrompu en cours de route : anneau figé + reprise ──────────────
    if (succeeded != 0) {
      return ArrowPopupMenuButton(
        popUpAnimationStyle: popupAnimationStyle,
        child: _progressBadge(
          value: fraction,
          fraction: fraction,
          color: color,
        ),
        onSelected: (value) {
          if (value == 0) {
            _startDownload(null, ref);
          } else if (value == 1) {
            _cancelDownload(ref, download?.id);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(value: 0, child: Text(l10n.resume)),
          PopupMenuItem(value: 1, child: Text(l10n.cancel)),
        ],
      );
    }

    // ── Aucune entrée (ou entrée jamais démarrée) : lancer le téléchargement.
    // Le bouton doit toujours être présent, sinon il est impossible de
    // télécharger depuis la liste des chapitres.
    return IconButton(
      padding: EdgeInsets.zero,
      tooltip: 'Télécharger',
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(32, 32),
        padding: EdgeInsets.zero,
      ),
      onPressed: () => _startDownload(null, ref),
      icon: Icon(Broken.receive_square, size: 23, color: color),
    );
  }

  /// Fraction de progression (0 → 1) ou `null` si elle n'est pas encore connue.
  ///
  /// On combine la progression "live" de la session (plus fraîche que les
  /// écritures Isar, seule source quand le total est encore inconnu) et les
  /// compteurs Isar (qui portent l'offset d'une reprise) en gardant la valeur
  /// la plus avancée : chacune est croissante, donc l'anneau ne recule jamais.
  double? _progressFraction(
    Download? download,
    DownloadLiveProgress? liveProgress,
  ) {
    final candidates = <double>[];
    if (liveProgress != null) {
      final totalBytes = liveProgress.totalBytes;
      final downloadedBytes = liveProgress.downloadedBytes;
      if (!liveProgress.isIndeterminate &&
          totalBytes != null &&
          totalBytes > 0 &&
          downloadedBytes != null) {
        candidates.add(
          (downloadedBytes / totalBytes)
              .clamp(0.0, 1.0)
              .toDouble(),
        );
      } else if (!liveProgress.isIndeterminate &&
          liveProgress.totalUnits > 0 &&
          liveProgress.completedUnits > 0) {
        candidates.add(
          (liveProgress.completedUnits / liveProgress.totalUnits)
              .clamp(0.0, 1.0)
              .toDouble(),
        );
      }
    }
    if (liveProgress?.isIndeterminate != true) {
      final total = download?.total ?? 0;
      if (total > 1) {
        candidates.add(
          ((download?.succeeded ?? 0) / total).clamp(0.0, 1.0).toDouble(),
        );
      }
    }
    if (candidates.isEmpty) return null;
    return candidates.reduce((a, b) => a > b ? a : b);
  }
}

/// Anneau de progression avec le pourcentage au centre (téléchargement en
/// cours, directement lisible depuis la liste des chapitres).
Widget _progressBadge({
  required double? value,
  required double? fraction,
  required Color color,
}) {
  final percentLabel = fraction == null
      ? null
      : '${(fraction * 100).round()}%';
  return SizedBox(
    width: 32,
    height: 32,
    child: Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            value: value,
            strokeWidth: 2.4,
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
          ),
        ),
        if (percentLabel != null)
          Text(
            percentLabel,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          )
        else
          Icon(Broken.receive_square, size: 14, color: color),
      ],
    ),
  );
}
