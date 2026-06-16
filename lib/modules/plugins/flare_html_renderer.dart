import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:watchtower/modules/plugins/flare_loader.dart';

// FlareHtmlRenderer — méthode html : WebView + bridge JS bidirectionnel
// JS -> Flutter : window.Watchtower.postAction('action', values)
// Flutter -> JS : sendToPlugin(type, data)

class FlareHtmlRenderer extends StatefulWidget {
  final InstalledFlarePlugin plugin;
  final void Function(String action, Map<String, dynamic> values) onAction;
  const FlareHtmlRenderer({required this.plugin, required this.onAction, super.key});
  @override State<FlareHtmlRenderer> createState() => _FlareHtmlRendererState();
}

class _FlareHtmlRendererState extends State<FlareHtmlRenderer> {
  InAppWebViewController? _ctrl;
  bool _loading = true;
  String? _error;
  static const _bg   = Color(0xFF0F0F0F);
  static const _teal = Color(0xFF00D4AA);
  static const _grey = Color(0xFF888888);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    body: Stack(children: [
      if (_error != null)
        Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.web_asset_off_rounded, color: Colors.red, size: 40),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: _grey), textAlign: TextAlign.center),
          ],
        )))
      else _buildWebView(),
      if (_loading) const Center(child: CircularProgressIndicator(color: _teal)),
    ]),
  );

  Widget _buildWebView() => InAppWebView(
    initialSettings: InAppWebViewSettings(
      transparentBackground: true,
      javaScriptEnabled: true,
      supportZoom: false,
    ),
    onWebViewCreated: (ctrl) async {
      _ctrl = ctrl;
      await ctrl.addJavaScriptHandler(
        handlerName: 'watchtower',
        callback: (args) {
          if (args.isEmpty || args[0] is! Map) return;
          final d = Map<String, dynamic>.from(args[0] as Map);
          widget.onAction(
            d['action'] as String? ?? '',
            (d['values'] as Map?)?.cast<String, dynamic>() ?? {},
          );
        },
      );
      final html = await FlareLoader.readHtml(widget.plugin);
      if (html == null) {
        setState(() { _error = 'ui/index.html introuvable.'; _loading = false; });
        return;
      }
      await ctrl.loadData(data: _inject(html), mimeType: 'text/html', encoding: 'utf8');
    },
    onLoadStop: (c, u) => setState(() => _loading = false),
    onReceivedError: (c, req, err) =>
      setState(() { _error = err.description; _loading = false; }),
  );

  String _inject(String html) {
    const br = '<scr' + 'ipt>window.Watchtower={postAction:(a,v)=>window.flutter_inappwebview.callHandler("watchtower",{action:a,values:v})};' + '</' + 'script>';
    return html.contains('<head>') ? html.replaceFirst('<head>', '<head>' + br) : br + html;
  }

  void sendToPlugin(String type, Map<String, dynamic> data) {
    final kv = data.entries.map((e) {
      final k = e.key;
      final v = e.value is String ? '"' + (e.value as String).replaceAll('"', '\\"') + '"' : e.value.toString();
      return '"' + k + '":' + v;
    }).join(',');
    _ctrl?.evaluateJavascript(
      source: 'window.dispatchEvent(new MessageEvent("message",{data:{"type":"' + type + '",' + kv + '}}))',
    );
  }
}