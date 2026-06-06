import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class BypassWebViewSheet extends StatefulWidget {
  final String url;
  const BypassWebViewSheet({super.key, required this.url});

  @override
  State<BypassWebViewSheet> createState() => _BypassWebViewSheetState();
}

class _BypassWebViewSheetState extends State<BypassWebViewSheet> {
  double _progress = 0;
  String _currentUrl = '';

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
  }

  String _hostFrom(String url) {
    try {
      return Uri.parse(url).host;
    } catch (_) {
      return url;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        // ── Drag handle ────────────────────────────────────────────────────
        Center(
          child: Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withOpacity(0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // ── Title bar ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Row(
            children: [
              Icon(
                Icons.shield_rounded,
                size: 18,
                color: cs.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Résoudre le challenge',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _hostFrom(_currentUrl),
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  color: cs.onSurfaceVariant,
                ),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Fermer',
              ),
            ],
          ),
        ),

        // ── Progress bar ──────────────────────────────────────────────────
        SizedBox(
          height: 2,
          child: _progress > 0 && _progress < 1.0
              ? LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.transparent,
                  color: cs.primary,
                )
              : (_progress == 0
                  ? LinearProgressIndicator(
                      backgroundColor: Colors.transparent,
                      color: cs.primary,
                    )
                  : const SizedBox.shrink()),
        ),

        // ── WebView ───────────────────────────────────────────────────────
        Expanded(
          child: InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(widget.url)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              domStorageEnabled: true,
              useShouldOverrideUrlLoading: false,
              userAgent:
                  'Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X) '
                  'AppleWebKit/605.1.15 (KHTML, like Gecko) '
                  'Version/16.5 Mobile/15E148 Safari/604.1',
            ),
            onLoadStart: (ctrl, url) {
              if (url != null && mounted) {
                setState(() {
                  _currentUrl = url.toString();
                  _progress = 0;
                });
              }
            },
            onProgressChanged: (ctrl, progress) {
              if (mounted) setState(() => _progress = progress / 100.0);
            },
            onLoadStop: (ctrl, url) {
              if (url != null && mounted) {
                setState(() {
                  _currentUrl = url.toString();
                  _progress = 1.0;
                });
              }
            },
          ),
        ),
      ],
    );
  }
}
