import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:watchtower/modules/music/collections/music_icons.dart';
import 'package:watchtower/modules/music/extensions/context.dart';

/// Compact error surface used across the music module.
///
/// Deliberately styled with the shared Watchtower tokens (tinted icon disc,
/// `surfaceContainerHighest` code block, `FilledButton.tonal` action) so an
/// error inside a music shelf looks identical to an error elsewhere in the app.
class ErrorBox extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  const ErrorBox({
    super.key,
    required this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: cs.errorContainer.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                child: Icon(MusicIcons.error, size: 34, color: cs.error),
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.an_error_occurred,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  error.toString(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () => showDialog<void>(
                      context: context,
                      useRootNavigator: false,
                      barrierDismissible: true,
                      builder: (_) => _LogDialog(error: error),
                    ),
                    icon: const Icon(MusicIcons.logs, size: 18),
                    label: Text(context.l10n.view_logs),
                  ),
                  if (onRetry != null)
                    FilledButton.tonalIcon(
                      onPressed: onRetry,
                      icon: const Icon(MusicIcons.refresh, size: 18),
                      label: Text(context.l10n.retry),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Log dialog extracted as a separate widget to avoid stale BuildContext
/// captures across dialog boundaries.
class _LogDialog extends HookWidget {
  final Object error;
  const _LogDialog({required this.error});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final copied = useState(false);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(MusicIcons.logs, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(context.l10n.logs)),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              error.toString(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: error.toString()));
            copied.value = true;
          },
          icon: Icon(
            copied.value ? Icons.check_rounded : Icons.copy_rounded,
            size: 16,
          ),
          label: Text(context.l10n.copy_to_clipboard),
        ),
      ],
    );
  }
}
