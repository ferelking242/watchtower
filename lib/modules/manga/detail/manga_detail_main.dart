import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/manga/detail/manga_details_view.dart';
import 'package:watchtower/modules/manga/detail/providers/update_manga_detail_providers.dart';
import 'package:watchtower/modules/manga/detail/providers/isar_providers.dart';
import 'package:watchtower/modules/watch/detail/watch_detail_view.dart';
import 'package:watchtower/modules/widgets/error_text.dart';
import 'package:watchtower/modules/widgets/progress_center.dart';
import 'package:watchtower/utils/log/logger.dart';
import 'package:watchtower/utils/utils.dart';

class MangaReaderDetail extends ConsumerStatefulWidget {
  final int mangaId;
  final int? resumeChapterId;
  final Duration? resumePosition;

  const MangaReaderDetail({
    super.key,
    required this.mangaId,
    this.resumeChapterId,
    this.resumePosition,
  });

  @override
  ConsumerState<MangaReaderDetail> createState() => _MangaReaderDetailState();
}

/// Navigation payload for `/manga-reader/detail` when the caller also wants
/// the watch player to resume a specific episode at a specific position.
class MangaDetailArgs {
  final int mangaId;
  final int? resumeChapterId;
  final Duration? resumePosition;

  const MangaDetailArgs(
    this.mangaId, {
    this.resumeChapterId,
    this.resumePosition,
  });
}

class _MangaReaderDetailState extends ConsumerState<MangaReaderDetail> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Wait for the widget tree to settle before loading detail
    await WidgetsBinding.instance.endOfFrame;
    // `Manga` is the shared item model for every medium (manga, watch, novel,
    // …), so a watch entry must not be logged under the MANGA tag. Read the
    // stored type first and label the line with the item's real kind.
    final itemType = isar.mangas.getSync(widget.mangaId)?.itemType;
    final isWatch = itemType == ItemType.anime;
    final kind = isWatch ? 'watch' : 'manga';
    final tag = isWatch ? LogTag.watch : LogTag.manga;
    AppLogger.log(
      'Open detail page · ${kind}Id=${widget.mangaId}',
      tag: tag,
    );
    try {
      await ref.read(
        updateMangaDetailProvider(mangaId: widget.mangaId, isInit: true).future,
      );
      AppLogger.log(
        'Detail loaded · ${kind}Id=${widget.mangaId}',
        tag: tag,
      );
    } catch (e, st) {
      AppLogger.log(
        'Detail load FAILED · ${kind}Id=${widget.mangaId}',
        logLevel: LogLevel.error,
        tag: tag,
        error: e,
        stackTrace: st,
      );
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _isLoading = true;

  /// Source row resolved for this page's item type cross-check.
  ///
  /// `nameContains` has no Isar index, so the lookup deserializes every
  /// `Source` (extension JavaScript included). Resolve it once per page instead
  /// of on every `build`, and never write to Isar from inside `build`.
  Source? _sourceForTypeCache;
  bool _sourceForTypeResolved = false;
  bool _typeCorrectionScheduled = false;

  Source? _resolveSourceForType(Manga manga) {
    if (_sourceForTypeResolved) return _sourceForTypeCache;
    _sourceForTypeResolved = true;
    // Two sources can share a display name across catalogues — MKissa exists as
    // both a watch and a manga source. A `nameContains` scan then returns
    // whichever row Isar yields first, which opened the manga in the watch
    // layout. Resolve by the stored id first.
    final byId = manga.sourceId == null
        ? null
        : getSource(manga.lang ?? '', manga.source ?? '', manga.sourceId);
    if (byId != null) return _sourceForTypeCache = byId;
    // Rows saved before `sourceId` existed: prefer a same-named source that
    // agrees with the stored type instead of the first name match.
    final sameName = isar.sources
        .filter()
        .nameContains(manga.source!, caseSensitive: false)
        .findAllSync();
    Source? chosen;
    for (final source in sameName) {
      if (source.itemType == manga.itemType) {
        chosen = source;
        break;
      }
    }
    return _sourceForTypeCache =
        chosen ?? (sameName.isEmpty ? null : sameName.first);
  }

  @override
  Widget build(BuildContext context) {
    final manga = ref.watch(
      getMangaDetailStreamProvider(mangaId: widget.mangaId),
    );
    return Scaffold(
      body: manga.when(
        data: (manga) {
          // Watch only this title's source row (primary key) when its id is
          // known. The previous `filter().langContains().nameContains()` watch
          // has no index, so Isar deserialized *every* `Source` — the embedded
          // extension JavaScript included — on each sources write, on the UI
          // isolate. Rows saved before `sourceId` existed fall back to the
          // name-based watch.
          final sourceId = manga!.sourceId;
          final sourcesStream = sourceId != null
              ? isar.sources.watchObject(sourceId, fireImmediately: true)
              : isar.sources
                    .filter()
                    .langContains(manga.lang!, caseSensitive: false)
                    .and()
                    .nameContains(manga.source!, caseSensitive: false)
                    .watch(fireImmediately: true);
          return StreamBuilder(
            stream: sourcesStream,
            builder: (context, snapshot) {
              final Source? source = sourceId != null
                  ? (snapshot.data as Source?)
                  : (snapshot.data as List<Source>?)?.firstOrNull;
              final sourceExist =
                  source != null &&
                  (source.isActive ?? false) &&
                  (source.isAdded ?? false);

              // For local archives (source='archive' or 'local'), trust the
              // stored itemType directly — never look up in sources table,
              // which would incorrectly match manga-type extensions.
              final isLocalArchive = manga.isLocalArchive ?? false;
              final ItemType effectiveType;
              if (isLocalArchive) {
                effectiveType = manga.itemType ?? ItemType.manga;
              } else {
                // Cross-check the source's declared itemType (prevents manga-type
                // extensions from opening in WatchDetailView due to a stale DB entry).
                final sourceForType = _resolveSourceForType(manga);
                effectiveType = sourceForType?.itemType ?? manga.itemType;

                // Silently correct the stored type if it disagrees with the
                // source. Deferred to a post-frame callback: writing to Isar
                // inside build() stalls the frame and can re-trigger the
                // `getMangaDetailStream` watch that is currently building.
                if (sourceForType != null &&
                    sourceForType.itemType != manga.itemType &&
                    !_typeCorrectionScheduled) {
                  _typeCorrectionScheduled = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    isar.writeTxnSync(() {
                      isar.mangas.putSync(
                        manga..itemType = sourceForType.itemType,
                      );
                    });
                  });
                }
              }

              return RefreshIndicator(
                onRefresh: () async {
                  if (sourceExist && !_isLoading) {
                    await ref.read(
                      updateMangaDetailProvider(
                        mangaId: manga.id,
                        isInit: false,
                      ).future,
                    );
                  }
                },
                child: effectiveType == ItemType.anime
                    ? WatchDetailView(
                        manga: manga,
                        sourceExist: sourceExist,
                        isLoading: _isLoading,
                        resumeChapterId: widget.resumeChapterId,
                        resumePosition: widget.resumePosition,
                        checkForUpdate: (value) async {
                          if (!_isLoading) {
                            setState(() {
                              _isLoading = true;
                            });
                            if (sourceExist) {
                              await ref.read(
                                updateMangaDetailProvider(
                                  mangaId: manga.id,
                                  isInit: false,
                                ).future,
                              );
                            }
                            if (mounted) {
                              setState(() {
                                _isLoading = false;
                              });
                            }
                          }
                        },
                      )
                    : Stack(
                        children: [
                          MangaDetailsView(
                            manga: manga,
                            sourceExist: sourceExist,
                            // Titre, auteur et statut passent en shimmer
                            // pendant le chargement des infos de la source.
                            isLoading: _isLoading,
                            checkForUpdate: (value) async {
                              if (!_isLoading) {
                                setState(() {
                                  _isLoading = true;
                                });
                                if (sourceExist) {
                                  await ref.read(
                                    updateMangaDetailProvider(
                                      mangaId: manga.id,
                                      isInit: false,
                                    ).future,
                                  );
                                }
                                if (mounted) {
                                  setState(() {
                                    _isLoading = false;
                                  });
                                }
                              }
                            },
                          ),
                          if (_isLoading)
                            const Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: Padding(
                                padding: EdgeInsets.only(top: 40),
                                child: Center(
                                    child: RefreshProgressIndicator()),
                              ),
                            ),
                        ],
                      ),
              );
            },
          );
        },
        error: (Object error, StackTrace stackTrace) {
          return ErrorText(error);
        },
        loading: () {
          return const ProgressCenter();
        },
      ),
    );
  }
}
