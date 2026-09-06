import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A reusable scrollable error display with a copy-to-clipboard button.
///
/// Used wherever extension/runtime errors are surfaced to the user so that
/// long stack traces don't overflow the screen and can be shared by the
/// user when reporting issues.
class ErrorBox extends StatelessWidget {
  final Object error;
  final StackTrace? stackTrace;
  final String? title;
  final EdgeInsetsGeometry padding;
  final double maxHeight;

  const ErrorBox({
    super.key,
    required this.error,
    this.stackTrace,
    this.title,
    this.padding = const EdgeInsets.all(16),
    this.maxHeight = 360,
  });

  String get _fullText {
    final buf = StringBuffer();
    buf.writeln(error.toString());
    if (stackTrace != null) {
      buf.writeln();
      buf.writeln(stackTrace.toString());
    }
    return buf.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.errorContainer.withValues(alpha: 0.35),
              border: Border.all(color: scheme.error.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: scheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title ?? 'Error',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: scheme.error,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy',
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: _fullText),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 2),
                              content: Text('Error copied to clipboard'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: SelectableText(
                        _fullText,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
