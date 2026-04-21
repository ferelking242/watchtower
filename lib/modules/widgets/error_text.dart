import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:watchtower/main.dart' show botToast;

/// Centered, selectable error message with a discrete copy button.
///
/// Errors from extension scripts are often long stack traces — keeping them
/// centered, scrollable and copyable makes them much easier to read and report.
class ErrorText extends StatelessWidget {
  final dynamic errorText;
  const ErrorText(this.errorText, {super.key});

  @override
  Widget build(BuildContext context) {
    final text = errorText?.toString() ?? '';
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  child: SelectableText(
                    text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 12.5,
                      height: 1.35,
                      fontFamilyFallback: const ['monospace'],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              IconButton(
                tooltip: 'Copy error',
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                onPressed: text.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(text: text));
                        try {
                          botToast('Error copied');
                        } catch (_) {}
                      },
                icon: Icon(
                  Icons.content_copy_rounded,
                  color: cs.onSurfaceVariant.withOpacity(0.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
