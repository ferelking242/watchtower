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
    // Make a monospace error log view. Make sure it's only 4 lines
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              ListTile(
                leading: const Icon(SpotubeIcons.error),
                contentSpacing: 8,
                title: Text(context.l10n.an_error_occurred),
              ),
              Card(
                padding: const EdgeInsets.all(8.0)).colorScheme.muted,
                child: Text(
                  error.toString(),
                  style: TextStyle(
                    // Use monospace
                    fontFamily: 'Ubuntu Mono',
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Show a dialog with full log and a retry button as well
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [ const Icon(SpotubeIcons.logs),
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
                              padding: const EdgeInsets.all(12),
                              title: Row(
                                spacing: 8,
                                children: [
                                  const Icon(SpotubeIcons.logs),
                                  Text(context.l10n.logs),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(SpotubeIcons.close),
                                    onPressed: () => context.maybePop(),
                                  )
                                ],
                              ),
                              actions: [
                                HookBuilder(builder: (context) {
                                  final copied = useState(false);

                                  return TextButton(
                                    child: Row(mainAxisSize: MainAxisSize.min, children: [ copied.value
                                        ? const Icon(SpotubeIcons.done)
                                        : const Icon(SpotubeIcons.clipboard),
                                    child: Text(context.l10n.copy_to_clipboard),
                                    onPressed: () {
                                      Clipboard.setData(
                                        ClipboardData(text: error.toString()),
                                      );
                                      copied.value = true;
                                    },
                                  );
                                })
                              ],
                              content: SingleChildScrollView(
                                child: Card(
                                  padding: const EdgeInsets.all(8.0)).colorScheme.muted,
                                  child: SelectableText(
                                    error.toString(),
                                    style: TextStyle(
                                      // Use monospace
                                      fontFamily: 'Ubuntu Mono',
                                      color: context
                                          .colorScheme.onSurface.withValues(alpha: 0.5),
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
                    child: Text(context.l10n.view_logs),
                  ),
                  if (onRetry != null)
                    TextButton(
                      child: Row(mainAxisSize: MainAxisSize.min, children: [ const Icon(SpotubeIcons.refresh),
                      onPressed: onRetry,
                      child: Text(context.l10n.retry),
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
