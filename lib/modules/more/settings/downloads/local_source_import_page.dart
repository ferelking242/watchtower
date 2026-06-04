import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
  import 'dart:developer' show log;

  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:isar_community/isar.dart';
  import 'package:watchtower/models/chapter.dart';
  import 'package:watchtower/models/manga.dart';
  import 'package:watchtower/main.dart';
  import 'package:watchtower/services/local/dex_movie_scanner.dart';

  // ─── State ───────────────────────────────────────────────────────────────────

  enum _ImportStatus { idle, scanning, importing, done }

  class _ImportState {
    final _ImportStatus status;
    final String? scannedFolder;
    final List<DexMovieEntry> entries;
    final int importedCount;
    final String? error;

    const _ImportState({
      this.status = _ImportStatus.idle,
      this.scannedFolder,
      this.entries = const [],
      this.importedCount = 0,
      this.error,
    });

    _ImportState copyWith({
      _ImportStatus? status,
      String? scannedFolder,
      List<DexMovieEntry>? entries,
      int? importedCount,
      String? error,
    }) =>
        _ImportState(
          status: status ?? this.status,
          scannedFolder: scannedFolder ?? this.scannedFolder,
          entries: entries ?? this.entries,
          importedCount: importedCount ?? this.importedCount,
          error: error,
        );
  }

  // ─── Provider ────────────────────────────────────────────────────────────────

  class _ImportNotifier extends Notifier<_ImportState> {
    @override
    _ImportState build() => const _ImportState();
    void setState(_ImportState s) => state = s;
  }

  final _importStateProvider =
      NotifierProvider<_ImportNotifier, _ImportState>(_ImportNotifier.new);

  // ─── Main Page ───────────────────────────────────────────────────────────────

  class LocalSourceImportPage extends ConsumerStatefulWidget {
    const LocalSourceImportPage({super.key});

    @override
    ConsumerState<LocalSourceImportPage> createState() =>
        _LocalSourceImportPageState();
  }

  class _LocalSourceImportPageState extends ConsumerState<LocalSourceImportPage> {
    final _customPathController = TextEditingController();

    @override
    void dispose() {
      _customPathController.dispose();
      super.dispose();
    }

    // ── Scan ────────────────────────────────────────────────────────────────────

    Future<void> _scan({String? customPath}) async {
      ref
          .read(_importStateProvider.notifier)
          .setState(const _ImportState(status: _ImportStatus.scanning));

      try {
        String? folderPath = customPath;
        if (folderPath == null || folderPath.isEmpty) {
          folderPath = await DexMovieScanner.findDexMovieFolder();
        }

        if (folderPath == null) {
          ref.read(_importStateProvider.notifier).setState(const _ImportState(
            status: _ImportStatus.idle,
            error: 'Aucun dossier DexMovie/Movie trouvé.\n'
                'Chemins vérifiés :\n'
                '• /storage/emulated/0/DexMovie/Movie\n'
                '• /sdcard/DexMovie/Movie',
          ));
          return;
        }

        final entries = await DexMovieScanner.scanFolder(folderPath);

        ref.read(_importStateProvider.notifier).setState(_ImportState(
          status: _ImportStatus.idle,
          scannedFolder: folderPath,
          entries: entries,
          error: entries.isEmpty
              ? 'Aucun fichier reconnu dans ${folderPath}.\n'
                  'Format attendu : Titre_[Langue]_QualitéP_SXX_EXX.mp4'
              : null,
        ));
      } catch (e) {
        ref.read(_importStateProvider.notifier).setState(_ImportState(
          status: _ImportStatus.idle,
          error: 'Erreur de scan : ${e}',
        ));
      }
    }

    // ── Import ───────────────────────────────────────────────────────────────────

    Future<void> _import(List<DexMovieEntry> entries) async {
      final current = ref.read(_importStateProvider);
      ref
          .read(_importStateProvider.notifier)
          .setState(current.copyWith(status: _ImportStatus.importing));

      try {
        final groups = DexMovieScanner.groupByTitle(entries);
        int count = 0;

        await isar.writeTxn(() async {
          for (final title in groups.keys) {
            final groupEntries = groups[title]!;
            final first = groupEntries.first;

            final existing = await isar.mangas
                .where()
                .filter()
                .nameEqualTo(title)
                .and()
                .sourceEqualTo('local')
                .and()
                .isLocalArchiveEqualTo(true)
                .findFirst();

            final manga = existing ??
                Manga(
                  source: 'local',
                  author: '',
                  artist: '',
                  genre: [],
                  imageUrl: '',
                  lang: first.language ?? 'fr',
                  link: 'local://${title.replaceAll(" ", "_")}',
                  name: title,
                  status: Status.unknown,
                  description: '',
                  sourceId: 0,
                  isLocalArchive: true,
                  itemType: ItemType.anime,
                  isManga: false,
                  favorite: true,
                  dateAdded: DateTime.now().millisecondsSinceEpoch,
                );

            final mangaId = await isar.mangas.put(manga);

            for (final e in groupEntries) {
              final chapterName = e.isMovie
                  ? '${e.quality} — ${e.language ?? ""}'
                  : 'S${(e.season ?? 1).toString().padLeft(2, "0")}'
                      'E${(e.episode ?? 1).toString().padLeft(2, "0")}'
                      '${e.part != null ? ".${e.part}" : ""}'
                      ' — ${e.quality}${e.language != null ? " [${e.language}]" : ""}';

              final existingCh = await isar.chapters
                  .where()
                  .filter()
                  .archivePathEqualTo(e.filePath)
                  .findFirst();
              if (existingCh != null) continue;

              final chapter = Chapter(
                mangaId: mangaId,
                name: chapterName,
                url: '',
                archivePath: e.filePath,
              );
              chapter.manga.value = manga;
              final chId = await isar.chapters.put(chapter);
              await isar.chapters.get(chId).then((ch) async {
                ch?.manga.value = manga;
                if (ch != null) await isar.chapters.put(ch);
              });
              count++;
            }
          }
        });

        final updated = ref.read(_importStateProvider);
        ref.read(_importStateProvider.notifier).setState(
              updated.copyWith(
                status: _ImportStatus.done,
                importedCount: count,
              ));
      } catch (e, st) {
        log('[DexMovieImport] error: ${e}\n${st}');
        final updated = ref.read(_importStateProvider);
        ref.read(_importStateProvider.notifier).setState(
              updated.copyWith(
                status: _ImportStatus.idle,
                error: "Erreur d'import : ${e}",
              ));
      }
    }

    // ── Build ────────────────────────────────────────────────────────────────────

    @override
    Widget build(BuildContext context) {
      final state = ref.watch(_importStateProvider);
      final accent = Theme.of(context).primaryColor;
      final cs = Theme.of(context).colorScheme;
      final textTheme = Theme.of(context).textTheme;

      return Scaffold(
        appBar: AppBar(title: const Text('Sources Locales — DexMovie')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withValues(alpha: 0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.folder_open_rounded, color: accent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Format des fichiers attendu',
                            style: textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Titre_[Langue]_QualitéP_SXX_EXX.mp4\n'
                            'Ex: Breaking_Bad_[FR]_1080P_S01_E01.mp4\n'
                            'Ex: Inception_[FR]_1080P.mp4  (film)',
                            style: textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              color: cs.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Dossier scanné : /storage/emulated/0/DexMovie/Movie/',
                            style: textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Text('Dossier personnalisé (optionnel)', style: textTheme.labelLarge),
              const SizedBox(height: 6),
              TextField(
                controller: _customPathController,
                decoration: InputDecoration(
                  hintText: '/storage/emulated/0/MonDossier/Film',
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _customPathController.clear(),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: state.status == _ImportStatus.scanning ||
                              state.status == _ImportStatus.importing
                          ? null
                          : () => _scan(
                              customPath: _customPathController.text.trim()),
                      icon: const Icon(Icons.search_rounded),
                      label: const Text('Scanner'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: state.entries.isEmpty ||
                              state.status == _ImportStatus.scanning ||
                              state.status == _ImportStatus.importing ||
                              state.status == _ImportStatus.done
                          ? null
                          : () => _import(state.entries),
                      icon: const Icon(Icons.download_for_offline_rounded),
                      label: const Text('Importer'),
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.green.shade700),
                    ),
                  ),
                ],
              ),

              if (state.status == _ImportStatus.scanning ||
                  state.status == _ImportStatus.importing) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 8),
                Text(
                  state.status == _ImportStatus.scanning
                      ? 'Scan en cours…'
                      : 'Import en cours…',
                  style: textTheme.bodySmall,
                ),
              ],

              if (state.status == _ImportStatus.done) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${state.importedCount} épisode(s)/film(s) importé(s) dans votre bibliothèque.',
                          style: const TextStyle(color: Colors.green),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (state.error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cs.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline_rounded, color: cs.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(state.error!,
                            style: TextStyle(color: cs.error)),
                      ),
                    ],
                  ),
                ),
              ],

              if (state.entries.isNotEmpty &&
                  state.status != _ImportStatus.importing) ...[
                const SizedBox(height: 20),
                Text(
                  '${state.entries.length} fichier(s) reconnu(s) dans ${state.scannedFolder}',
                  style: textTheme.labelLarge?.copyWith(color: accent),
                ),
                const SizedBox(height: 8),
                ...DexMovieScanner.groupByTitle(state.entries).entries.map((group) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    child: ExpansionTile(
                      leading: const Icon(Icons.movie_filter_rounded),
                      title: Text(group.key, style: textTheme.titleSmall),
                      subtitle: Text(
                        '${group.value.length} fichier(s) — ${group.value.first.isMovie ? "Film" : "Série"}',
                        style: textTheme.bodySmall,
                      ),
                      children: group.value.map((e) {
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.play_circle_outline, size: 18),
                          title: Text(e.episodeKey, style: textTheme.bodySmall),
                          subtitle: Text(
                            '${e.quality}${e.language != null ? " [${e.language}]" : ""}',
                            style: textTheme.bodySmall?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.5)),
                          ),
                          trailing: Text(
                            e.filePath.split('/').last,
                            style: textTheme.bodySmall?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.4),
                                fontSize: 9),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      );
    }
  }
  