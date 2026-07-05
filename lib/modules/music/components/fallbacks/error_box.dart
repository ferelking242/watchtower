import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
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
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    error.toString(),
                    style: TextStyle(
                      fontFamily: 'Ubuntu Mono',
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
                        showDialog(
                          context: context,
                          builder: (context) {
                            return ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: 480,
                                maxHeight:
                                    MediaQuery.of(context).size.height * 0.8,
                              ),
                              child: AlertDialog(
                                contentPadding: const EdgeInsets.all(12),
                                title: Row(
                                  children: [
                                    const Icon(SpotubeIcons.logs),
                                    const SizedBox(width: 8),
                                    Text(context.l10n.logs),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(SpotubeIcons.close),
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                    )
                                  ],
                                ),
                                actions: [
                                  HookBuilder(builder: (context) {
                                    final copied = useState(false);

                                    return TextButton(
                                      onPressed: () {
                                        Clipboard.setData(
                                          ClipboardData(text: error.toString()),
                                        );
                                        copied.value = true;
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          copied.value
                                              ? const Icon(SpotubeIcons.done)
                                              : const Icon(SpotubeIcons.clipboard),
                                          const SizedBox(width: 8),
                                          Text(context.l10n.copy_to_clipboard),
                                        ],
                                      ),
                                    );
                                  })
                                ],
                                content: SingleChildScrollView(
                                  child: Container(
                                    padding: const EdgeInsets.all(8.0),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: SelectableText(
                                      error.toString(),
                                      style: TextStyle(
                                        fontFamily: 'Ubuntu Mono',
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
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
