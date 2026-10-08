import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:watchtower/eval/model/m_bridge.dart' show botToast;
import 'package:watchtower/modules/anti_bot/cloudflare_error_widget.dart';
import 'package:watchtower/modules/watch/home/extension_home_empty_state.dart'
    show
        extensionErrorTitle,
        extensionFailedUrl,
        extensionRequestFailureMessage;

class ErrorText extends StatefulWidget {
  final dynamic errorText;
  final String? sourceUrl;
  final int? sourceId;
  final VoidCallback? onRetry;

  const ErrorText(
    this.errorText, {
    super.key,
    this.sourceUrl,
    this.sourceId,
    this.onRetry,
  });

  @override
  State<ErrorText> createState() => _ErrorTextState();
}

class _ErrorTextState extends State<ErrorText> {
  bool _detailsExpanded = false;

  @override
  Widget build(BuildContext context) {
    final text = widget.errorText?.toString() ?? '';
    final title = extensionErrorTitle(widget.errorText);
    final failureMessage = extensionRequestFailureMessage(widget.errorText);
    final summary =
        failureMessage == null ? null : _limitSummary(failureMessage);
    final hasDetails = text.trim().isNotEmpty && text.trim() != summary?.trim();
    final cs = Theme.of(context).colorScheme;

    if (isCloudflareError(text)) {
      return CloudflareErrorWidget(
        errorText: text,
        // Prefer the exact failing URL over the site root: the root loads with
        // no challenge, so the bypass WebView would look already solved.
        url: widget.sourceUrl ?? extensionFailedUrl(widget.errorText),
        sourceId: widget.sourceId,
        onRetry: widget.onRetry,
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, color: cs.error, size: 28),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (summary != null) ...[
                const SizedBox(height: 6),
                Text(
                  summary,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
              if (hasDetails) ...[
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () =>
                      setState(() => _detailsExpanded = !_detailsExpanded),
                  child: Text(
                    _detailsExpanded
                        ? 'Masquer les détails'
                        : 'Détails de l’erreur',
                  ),
                ),
              ],
              if (_detailsExpanded && hasDetails)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      text,
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 11.5,
                        height: 1.35,
                        fontFamilyFallback: const ['monospace'],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              IconButton(
                tooltip: 'Copier le détail de l’erreur',
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                onPressed: text.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(text: text));
                        try {
                          botToast('Erreur copiée')();
                        } catch (_) {}
                      },
                icon: Icon(
                  Icons.content_copy_rounded,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _limitSummary(String summary) {
  final oneLine = summary.replaceAll(RegExp(r'\s+'), ' ').trim();
  const maxLength = 180;
  if (oneLine.length <= maxLength) return oneLine;
  return '${oneLine.substring(0, maxLength - 1)}…';
}
