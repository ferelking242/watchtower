import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:lottie/lottie.dart';
import 'package:watchtower/modules/music/collections/music_icons.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart' as app_l10n;
import 'package:watchtower/modules/widgets/offline_content_state.dart';

/// Friendly error surface used across the music module.
///
/// Instead of dumping a raw runtime trace with a "view logs" button, it shows
/// the shared Watchtower illustration (`assets/animations/error.json`) plus a
/// plain-language message. The technical detail is still reachable — collapsed
/// behind "Details", copyable in one tap — but it never dominates the screen.
class ErrorBox extends StatefulWidget {
  final Object error;
  final VoidCallback? onRetry;
  const ErrorBox({
    super.key,
    required this.error,
    this.onRetry,
  });

  @override
  State<ErrorBox> createState() => _ErrorBoxState();
}

class _ErrorBoxState extends State<ErrorBox> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // An offline failure is not a bug: show the shared "no connection" surface
    // with a retry instead of the generic "something went wrong" trace, so the
    // user understands they just need to reconnect.
    if (isOfflineContentError(widget.error)) {
      // The app-wide locale can be one only the music module translates, in
      // which case the app has no table and `of` returns null.
      final appL10n = app_l10n.AppLocalizations.of(context) ??
          app_l10n.lookupAppLocalizations(const Locale('en'));
      return OfflineContentState(
        title: appL10n.media_no_network,
        message: appL10n.media_check_connection,
        onRetry: widget.onRetry,
      );
    }
    final detail = _humanize(widget.error);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                'assets/animations/error.json',
                width: 148,
                height: 148,
                fit: BoxFit.contain,
                repeat: true,
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.something_went_wrong,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                detail.summary,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  if (widget.onRetry != null)
                    FilledButton.tonalIcon(
                      onPressed: widget.onRetry,
                      icon: const Icon(MusicIcons.refresh, size: 18),
                      label: Text(context.l10n.retry),
                    ),
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _showDetails = !_showDetails),
                    icon: Icon(
                      _showDetails
                          ? MusicIcons.angleDown
                          : MusicIcons.angleRight,
                      size: 18,
                    ),
                    label: Text(context.l10n.details),
                  ),
                ],
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 180),
                crossFadeState: _showDetails
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: _DetailsCard(detail: detail),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Raw technical detail, collapsed by default, copyable in one tap.
class _DetailsCard extends HookWidget {
  final _ErrorDetail detail;
  const _DetailsCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final copied = useState(false);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  detail.source.isEmpty ? context.l10n.details : detail.source,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 16,
                tooltip: context.l10n.copy_to_clipboard,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: detail.raw));
                  copied.value = true;
                },
                icon: Icon(
                  copied.value ? MusicIcons.done : MusicIcons.clipboard,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          SelectableText(
            detail.raw,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontFamily: 'monospace',
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

/// A parsed view of an arbitrary thrown object: a short, human summary plus the
/// untouched raw text kept for the details panel.
class _ErrorDetail {
  final String summary;
  final String raw;
  final String source;
  const _ErrorDetail(this.summary, this.raw, this.source);
}

_ErrorDetail _humanize(Object error) {
  final raw = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  final lines = raw.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty);

  // Pull the first line that carries information; runtime traces often open
  // with a bare "Runtime error:" header that says nothing on its own.
  var summary = lines.isEmpty ? raw : lines.first;
  for (final line in lines) {
    final lower = line.toLowerCase();
    if (lower.startsWith('message:') || lower.startsWith('cause:')) {
      summary = line.split(':').skip(1).join(':').trim();
      break;
    }
  }

  // Locate a "File: …/x.ht" / "Line: n" pair to name the failing source.
  final fileLine = lines.firstWhere(
    (l) => l.toLowerCase().startsWith('file:'),
    orElse: () => '',
  );
  final source = fileLine.isEmpty
      ? ''
      : fileLine.split(':').skip(1).join(':').trim().split('/').last;

  return _ErrorDetail(summary, raw, source);
}
