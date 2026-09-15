import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../constants/api_constants.dart';
import '../../constants/app_constants.dart';
import '../../functions/function.dart';
import '../../models/custom_exceptions.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';
import '../../ui_components/app_ui_components.dart';

/// The route a link lands on while the record behind it is fetched.
///
/// A link can only hand the app an identity, and the detail pages read the rating, the vote count
/// and the synopsis straight off the record they are given — so a page built from the link alone
/// shows a title with none of its facts, and for a bookmarked one writes those blanks back over what
/// was saved. The fetch therefore happens here, in front of whatever artwork the link came with, and
/// the page is built only once there is a whole record to build it from.
///
/// TMDB and IMDb links arrive here directly. Widgets use this screen to retry a
/// failed fetch after preparing their destination before navigation.
class DeepLinkLoader extends StatefulWidget {
  const DeepLinkLoader({
    required this.load,
    this.initialError,
    this.title,
    this.artworkPath,
    super.key,
  });

  /// A failed pre-navigation fetch, shown immediately without fetching again.
  final Object? initialError;

  /// Fetches the record and returns the page that renders it.
  final Future<Widget> Function(BuildContext context) load;

  /// Name of the title being opened, as the link spelled it.
  final String? title;

  /// Backdrop, still or poster to show behind the wait, when the link came with one.
  final String? artworkPath;

  @override
  State<DeepLinkLoader> createState() => _DeepLinkLoaderState();
}

class _DeepLinkLoaderState extends State<DeepLinkLoader> {
  /// The TMDB helpers retry until they are told to stop, and this wait is already on top of a cold
  /// start, so it is bounded here rather than left to them.
  static const Duration _limit = Duration(seconds: 12);

  Widget? _page;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.initialError;
    if (_error == null) _resolve();
  }

  Future<void> _resolve() async {
    try {
      // The fetch helpers retry a dropped connection for hours, and a wait this route has already
      // given up on goes on retrying unseen. Asking first keeps the offline case from starting one
      // at all, and answers straight away.
      if (!await checkConnection()) {
        throw const SocketException('No connection to fetch the record');
      }
      if (!mounted) return;
      final page = await widget.load(context).timeout(_limit);
      if (!mounted) return;
      setState(() => _page = page);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  void _retry() {
    setState(() => _error = null);
    _resolve();
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    if (page != null) return page;
    // The failure state is drawn in theme colours, so the scrimmed artwork gives way to it rather
    // than sitting behind it.
    final artwork = _error == null ? widget.artworkPath : null;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (artwork != null) _Artwork(path: artwork),
          SafeArea(
            child: Stack(
              children: [
                Align(
                  alignment: AlignmentDirectional.topStart,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: IconButton(
                      tooltip:
                          MaterialLocalizations.of(context).backButtonTooltip,
                      onPressed: () => Navigator.maybePop(context),
                      color: artwork == null ? null : Colors.white,
                      icon: Icon(PhosphorIcons.caretLeft()),
                    ),
                  ),
                ),
                _error == null
                    ? _waiting(context, overArtwork: artwork != null)
                    : _failure(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _waiting(BuildContext context, {required bool overArtwork}) {
    final title = widget.title;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(
            dimension: 30,
            child: CircularProgressIndicator(strokeWidth: 2.6),
          ),
          if (title != null && title.isNotEmpty) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontFamily: 'FigtreeSB',
                      color: overArtwork ? Colors.white : null,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// A record TMDB does not hold will not appear on a second attempt, so that case says as much and
  /// offers no retry. Everything else is the connection, which may well come back.
  Widget _failure(BuildContext context) {
    final missing = _error is NotFoundException;
    return AppEmptyState(
      icon: missing ? PhosphorIcons.filmSlate() : PhosphorIcons.cloudSlash(),
      title: missing ? tr('link_unavailable') : tr('error_occured'),
      message: missing ? tr('link_unavailable_message') : tr('check_connection'),
      action: missing
          ? null
          : FilledButton.icon(
              onPressed: _retry,
              icon: Icon(PhosphorIcons.arrowClockwise()),
              label: Text(tr('retry')),
            ),
    );
  }
}

/// The artwork the link arrived with, dimmed so the wait reads as the page arriving.
class _Artwork extends StatelessWidget {
  const _Artwork({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final dependencies = Provider.of<AppDependencyProvider>(context);
    final base = buildImageUrl(
      TMDB_BASE_IMAGE_URL,
      dependencies.tmdbProxy,
      settings.enableProxy,
      context,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          cacheManager: cacheProp(),
          imageUrl: '${base}w780$path',
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          placeholder: (_, __) => const SizedBox.shrink(),
          errorWidget: (_, __, ___) => const SizedBox.shrink(),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: .45),
                Colors.black.withValues(alpha: .75),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
