import 'package:flutter/material.dart';
  import 'package:flutter_inappwebview/flutter_inappwebview.dart';
  import 'package:go_router/go_router.dart';
  import 'package:http/http.dart' as http;
  import 'package:watchtower/modules/plugins/plugins_screen.dart';

  // ─── InstalledPlugin model ────────────────────────────────────────────────────

  class InstalledPlugin {
    final String id;
    final String version;
    final String uiMethod;
    final String uiUrl;

    const InstalledPlugin({
      required this.id,
      required this.version,
      this.uiMethod = 'html',
      required this.uiUrl,
    });

    factory InstalledPlugin.fromEntry(PluginEntry entry) {
      const base =
          'https://raw.githubusercontent.com/ferelking242/watchtower-extensions/main/plugins/';
      final uiUrl = entry.uiMethod == 'json'
          ? '${base}${entry.id}/ui/schema.json'
          : '${base}${entry.id}/ui/index.html';
      return InstalledPlugin(
        id: entry.id,
        version: entry.version,
        uiMethod: entry.uiMethod,
        uiUrl: uiUrl,
      );
    }
  }

  // ─── PluginLauncherScreen ─────────────────────────────────────────────────────

  class PluginLauncherScreen extends StatefulWidget {
    final InstalledPlugin installed;
    final PluginEntry meta;

    const PluginLauncherScreen({
      required this.installed,
      required this.meta,
      super.key,
    });

    @override
    State<PluginLauncherScreen> createState() => _PluginLauncherScreenState();
  }

  class _PluginLauncherScreenState extends State<PluginLauncherScreen> {
    String? _htmlContent;
    bool _loading = true;
    String? _error;

    @override
    void initState() {
      super.initState();
      _loadContent();
    }

    Future<void> _loadContent() async {
      setState(() {
        _loading = true;
        _error = null;
      });
      try {
        final res = await http.get(Uri.parse(widget.installed.uiUrl));
        if (res.statusCode == 200) {
          setState(() {
            _htmlContent = res.body;
            _loading = false;
          });
        } else {
          setState(() {
            _error = 'HTTP ${res.statusCode}';
            _loading = false;
          });
        }
      } catch (e) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }

    @override
    Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0E0E0E) : cs.surface,
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(meta: widget.meta, onClose: () => context.pop()),
              Expanded(
                child: _loading
                    ? Center(child: CircularProgressIndicator(color: cs.primary))
                    : _error != null
                        ? _ErrorView(error: _error!, onRetry: _loadContent)
                        : _HtmlView(
                            html: _htmlContent!,
                            baseUrl: widget.installed.uiUrl,
                          ),
              ),
            ],
          ),
        ),
      );
    }
  }

  // ── Top bar ───────────────────────────────────────────────────────────────────

  class _TopBar extends StatelessWidget {
    final PluginEntry meta;
    final VoidCallback onClose;
    const _TopBar({required this.meta, required this.onClose});

    @override
    Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141414) : cs.surfaceContainerLow,
          border: Border(
            bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2)),
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
              onPressed: onClose,
            ),
            if (meta.iconUrl.isNotEmpty)
              Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(right: 8),
                decoration:
                    BoxDecoration(borderRadius: BorderRadius.circular(6)),
                clipBehavior: Clip.antiAlias,
                child: Image.network(
                  meta.iconUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Icon(Icons.extension_rounded, size: 18, color: cs.primary),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child:
                    Icon(Icons.extension_rounded, size: 22, color: cs.primary),
              ),
            Expanded(
              child: Text(
                meta.name,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }
  }

  // ── HTML WebView ──────────────────────────────────────────────────────────────

  class _HtmlView extends StatelessWidget {
    final String html;
    final String baseUrl;
    const _HtmlView({required this.html, required this.baseUrl});

    @override
    Widget build(BuildContext context) {
      final uri = Uri.parse(baseUrl);
      final segs = List<String>.from(uri.pathSegments);
      if (segs.isNotEmpty) segs.removeLast();
      final baseDirUrl = Uri(
        scheme: uri.scheme,
        host: uri.host,
        pathSegments: segs,
      ).toString() + '/';

      return InAppWebView(
        initialData: InAppWebViewInitialData(
          data: html,
          baseUrl: WebUri(baseDirUrl),
          mimeType: 'text/html',
          encoding: 'utf-8',
        ),
        initialSettings: InAppWebViewSettings(
          useShouldOverrideUrlLoading: true,
          mediaPlaybackRequiresUserGesture: false,
          allowsInlineMediaPlayback: true,
          transparentBackground: true,
          disableContextMenu: true,
          supportZoom: false,
          builtInZoomControls: false,
          displayZoomControls: false,
        ),
        shouldOverrideUrlLoading: (_, __) async => NavigationActionPolicy.ALLOW,
      );
    }
  }

  // ── Error view ────────────────────────────────────────────────────────────────

  class _ErrorView extends StatelessWidget {
    final String error;
    final VoidCallback onRetry;
    const _ErrorView({required this.error, required this.onRetry});

    @override
    Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: cs.error),
              const SizedBox(height: 16),
              const Text(
                'Impossible de charger le plugin',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(error,
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }
  }
  