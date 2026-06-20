import 'package:flutter/material.dart';
  import 'package:flutter_inappwebview/flutter_inappwebview.dart';
  import 'package:watchtower/eval/model/m_bridge.dart';

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

    @override
    Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;

      return Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          // ── Thin progress indicator ───────────────────────────────────────
          SizedBox(
            height: 3,
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

          // ── WebView — just the page content ──────────────────────────────
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
              onLoadStop: (ctrl, url) async {
                if (url != null && mounted) {
                  setState(() {
                    _currentUrl = url.toString();
                    _progress = 1.0;
                  });
                }
                // Auto-close once Cloudflare sets the cf_clearance cookie
                try {
                  final cookies = await CookieManager.instance().getCookies(
                    url: WebUri(widget.url),
                  );
                  final resolved = cookies.any((c) => c.name == 'cf_clearance');
                  if (resolved && mounted) {
                    await Future.delayed(const Duration(milliseconds: 600));
                    if (mounted) {
                      botToast('✅ Cloudflare résolu — accès rétabli', second: 4);
                      Navigator.of(context).pop(true);
                    }
                  }
                } catch (_) {}
              },
            ),
          ),
        ],
      );
    }
  }
  