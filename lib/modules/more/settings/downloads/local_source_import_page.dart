import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
  import 'dart:typed_data';

  import 'package:flutter/foundation.dart';
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:isar_community/isar.dart';
  import 'package:path/path.dart' as p;
  import 'package:watchtower/main.dart';
  import 'package:watchtower/models/manga.dart';
  import 'package:watchtower/modules/library/providers/file_scanner.dart';
  import 'package:watchtower/modules/widgets/bottom_text_widget.dart';
  import 'package:watchtower/modules/widgets/cover_view_widget.dart';
  import 'package:watchtower/modules/widgets/gridview_widget.dart';
  import 'package:watchtower/modules/widgets/manga_image_card_widget.dart';
  import 'package:watchtower/providers/storage_provider.dart';

  // Streams local mangas filtered by itemType
  final _localMangasByTypeProvider = StreamProvider.family<List<Manga>, ItemType>(
    (ref, itemType) => isar.mangas
        .filter()
        .sourceEqualTo('local')
        .and()
        .itemTypeEqualTo(itemType)
        .watch(fireImmediately: true),
  );

  class LocalBrowserPage extends ConsumerStatefulWidget {
    final ItemType itemType;

    const LocalBrowserPage({super.key, required this.itemType});

    @override
    ConsumerState<LocalBrowserPage> createState() => _LocalBrowserPageState();
  }

  class _LocalBrowserPageState extends ConsumerState<LocalBrowserPage> {
    bool _scanning = false;

    String get _folderName {
      switch (widget.itemType) {
        case ItemType.anime:
          return 'Watch';
        case ItemType.manga:
          return 'Manga';
        case ItemType.novel:
          return 'Novel';
        case ItemType.music:
          return 'Music';
        case ItemType.game:
          return 'Game';
      }
    }

    String get _title => 'Local $_folderName';

    @override
    void initState() {
      super.initState();
      if (!kIsWeb) _initAndScan();
    }

    Future<void> _initAndScan() async {
      if (!mounted) return;
      setState(() => _scanning = true);
      try {
        final baseDir = await StorageProvider().getDefaultDirectory();
        if (baseDir == null) return;

        final localTypePath = p.join(baseDir.path, 'local', _folderName);
        final localTypeDir = Directory(localTypePath);

        if (!await localTypeDir.exists()) {
          await localTypeDir.create(recursive: true);
        }

        final current = ref.read(localFoldersStateProvider);
        if (!current.contains(localTypePath)) {
          ref
              .read(localFoldersStateProvider.notifier)
              .set([...current, localTypePath]);
        }

        await ref.read(scanLocalLibraryProvider.future);
      } catch (_) {
      } finally {
        if (mounted) setState(() => _scanning = false);
      }
    }

    Future<void> _refresh() async {
      if (!mounted) return;
      setState(() => _scanning = true);
      try {
        await ref.read(scanLocalLibraryProvider.future);
      } finally {
        if (mounted) setState(() => _scanning = false);
      }
    }

    @override
    Widget build(BuildContext context) {
      if (kIsWeb) {
        return Scaffold(
          appBar: AppBar(
          leading: const BackButton(),title: Text(_title)),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.folder_off_rounded, size: 72, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'Local source not available on Web',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                ),
              ],
            ),
          ),
        );
      }

      final mangasAsync = ref.watch(_localMangasByTypeProvider(widget.itemType));

      return Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: Text(_title),
          actions: [
            if (_scanning)
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _refresh,
                tooltip: 'Refresh',
              ),
          ],
        ),
        body: mangasAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (mangas) {
            if (mangas.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.folder_open_rounded,
                      size: 72,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _scanning ? 'Scanning...' : 'No content found',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add files to Watchtower/local/$_folderName/',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return GridViewWidget(
              itemCount: mangas.length,
              itemBuilder: (context, index) {
                final manga = mangas[index];
                final bool isLocalArchive = manga.isLocalArchive ?? false;

                // Local mangas store their cover as bytes — no network URL needed
                final ImageProvider? image = manga.customCoverImage != null
                    ? MemoryImage(manga.customCoverImage as Uint8List)
                    : null;

                return Padding(
                  padding: const EdgeInsets.all(2),
                  child: CoverViewWidget(
                    image: image,
                    isLongPressed: false,
                    bottomTextWidget: BottomTextWidget(
                      text: manga.name ?? '',
                      maxLines: 1,
                      isComfortableGrid: false,
                    ),
                    onTap: () async {
                      await pushToMangaReaderDetail(
                        ref: ref,
                        context: context,
                        lang: manga.lang ?? '',
                        mangaM: manga,
                        source: manga.source ?? 'local',
                        sourceId: manga.sourceId,
                        archiveId: isLocalArchive ? manga.id : null,
                      );
                    },
                    children: [
                      BottomTextWidget(
                        text: manga.name ?? '',
                        maxLines: 1,
                        isComfortableGrid: false,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      );
    }
  }
  