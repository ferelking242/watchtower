import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/watch/detail/watch_detail_view.dart';
import 'package:watchtower/utils/chapter_link.dart';
import 'package:watchtower/utils/log/logger.dart';
import 'package:watchtower/providers/l10n_providers.dart';

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
      final manga = chapter == null ? null : resolveChapterManga(chapter);
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
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              context.l10n.player_episode_not_in_library,
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
