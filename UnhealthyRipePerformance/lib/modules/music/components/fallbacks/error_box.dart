import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/extensions/context.dart';

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
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(SpotubeIcons.error),
                  title: Text(context.l10n.an_error_occurred),
                ),
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    error.toString(),
                    style: TextStyle(
                      fontFamily: 'Ubuntu Mono',
                      color: cs.onSurface.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () {
                        // Use useRootNavigator: false to avoid AutoRouter
                        // null-check crash when the dialog is shown inside
                        // the music module's nested navigator context.
                        showDialog<void>(
                          context: context,
                          useRootNavigator: false,
                          barrierDismissible: true,
                          builder: (_) => _LogDialog(error: error),
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(SpotubeIcons.logs),
                          const SizedBox(width: 8),
                          Text(context.l10n.view_logs),
                        ],
                      ),
                    ),
                    if (onRetry != null)
                      TextButton(
                        onPressed: onRetry,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(SpotubeIcons.refresh),
                            const SizedBox(width: 8),
                            Text(context.l10n.retry),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
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

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title row — uses its own fresh context, never the outer one
              Row(
                children: [
                  const Icon(SpotubeIcons.logs),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.logs,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    // Navigator.of uses the dialog's own context — no AutoRouter crash
                    onPressed: () => Navigator.of(context).pop(),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Log content
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      error.toString(),
                      style: TextStyle(
                        fontFamily: 'Ubuntu Mono',
                        color: cs.onSurface.withValues(alpha: 0.5),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Copy button
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                        ClipboardData(text: error.toString()));
                    copied.value = true;
                  },
                  icon: Icon(
                    copied.value
                        ? Icons.check_rounded
                        : Icons.copy_rounded,
                    size: 16,
                  ),
                  label: Text(
                    copied.value
                        ? context.l10n.copy_to_clipboard
                        : context.l10n.copy_to_clipboard,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
