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

class MangaReaderDetail extends ConsumerStatefulWidget {
  final int mangaId;
  const MangaReaderDetail({super.key, required this.mangaId});

  @override
  ConsumerState<MangaReaderDetail> createState() => _MangaReaderDetailState();
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
    AppLogger.log(
      'Open detail page · mangaId=${widget.mangaId}',
      tag: LogTag.manga,
    );
    try {
      await ref.read(
        updateMangaDetailProvider(mangaId: widget.mangaId, isInit: true).future,
      );
      AppLogger.log(
        'Detail loaded · mangaId=${widget.mangaId}',
        tag: LogTag.manga,
      );
    } catch (e, st) {
      AppLogger.log(
        'Detail load FAILED · mangaId=${widget.mangaId}',
        logLevel: LogLevel.error,
        tag: LogTag.manga,
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
  @override
  Widget build(BuildContext context) {
    final manga = ref.watch(
      getMangaDetailStreamProvider(mangaId: widget.mangaId),
    );
    return Scaffold(
      body: manga.when(
        data: (manga) {
          return StreamBuilder(
            stream: isar.sources
                .filter()
                .langContains(manga!.lang!, caseSensitive: false)
                .and()
                .nameContains(manga.source!, caseSensitive: false)
                .and()
                .idIsNotNull()
                .and()
                .isActiveEqualTo(true)
                .and()
                .isAddedEqualTo(true)
                .watch(fireImmediately: true),
            builder: (context, snapshot) {
              final sourceExist = snapshot.hasData && snapshot.data!.isNotEmpty;

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
                final sourceForType = isar.sources
                    .filter()
                    .nameContains(manga.source!, caseSensitive: false)
                    .findFirstSync();
                effectiveType = sourceForType?.itemType ?? manga.itemType;

                // Silently correct the stored type if it disagrees with the source
                if (sourceForType != null &&
                    sourceForType.itemType != manga.itemType) {
                  isar.writeTxnSync(() {
                    isar.mangas.putSync(
                      manga..itemType = sourceForType.itemType,
                    );
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
