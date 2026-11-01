import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/watch/detail/watch_detail_view.dart';
import 'package:watchtower/utils/log/logger.dart';

/// Entry point kept for the `animePlayerView` route and the WebView
/// "open in MPV" action.
///
/// Watchtower has exactly one video player: the native `WatchInlinePlayer`
/// driven by [WatchDetailView]. This widget used to be backed by a second,
/// parallel player implementation (`anime_player_view_io.dart`), which drifted
/// out of sync with every fix applied to the main player. It now resolves the
/// episode's parent entry and renders the single real player instead, so there
/// is nothing left to keep in sync.
class AnimePlayerView extends ConsumerStatefulWidget {
  final int episodeId;

  const AnimePlayerView({super.key, required this.episodeId});

  @override
  ConsumerState<AnimePlayerView> createState() => _AnimePlayerViewState();
}

class _AnimePlayerViewState extends ConsumerState<AnimePlayerView> {
  Manga? _manga;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    try {
      final chapter = isar.chapters.getSync(widget.episodeId);
      Manga? manga = chapter?.manga.value;
      if (chapter != null && manga == null) {
        await chapter.manga.load();
        manga = chapter.manga.value;
      }
      if (!mounted) return;
      setState(() {
        _manga = manga;
        _loading = false;
      });
    } catch (error, stack) {
      AppLogger.log(
        'AnimePlayerView: could not resolve episode ${widget.episodeId}',
        logLevel: LogLevel.warning,
        tag: LogTag.watch,
        error: error,
        stackTrace: stack,
      );
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final manga = _manga;
    if (manga == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Épisode introuvable dans la bibliothèque.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return WatchDetailView(
      manga: manga,
      sourceExist: true,
      isLoading: false,
      resumeChapterId: widget.episodeId,
      checkForUpdate: (_) async {},
    );
  }
}
