import 'dart:io';
import 'package:flutter/material.dart';
import 'package:watchtower/modules/plugins/flare_loader.dart';
import 'package:d4rt/d4rt.dart';

// FlareEvalRenderer — methode eval : interprete ui/main.dart via d4rt
// WPlugin etend StatelessWidget : l'instance retournee par d4rt EST un Widget.

class FlareEvalRenderer extends StatefulWidget {
  final InstalledFlarePlugin plugin;
  const FlareEvalRenderer({required this.plugin, super.key});
  @override
  State<FlareEvalRenderer> createState() => _FlareEvalRendererState();
}

class _FlareEvalRendererState extends State<FlareEvalRenderer> {
  Widget? _pluginWidget;
  bool _loading = true;
  String? _error;
  static const _bg   = Color(0xFF0F0F0F);
  static const _teal = Color(0xFF00D4AA);
  static const _grey = Color(0xFF888888);

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final dartSource = await FlareLoader.readEvalSource(widget.plugin);
      if (dartSource == null) {
        setState(() { _loading = false; _error = 'ui/main.dart introuvable dans ce plugin.'; });
        return;
      }
      final built = await _interpret(dartSource);
      if (mounted) setState(() { _pluginWidget = built; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'Erreur eval : $e'; });
    }
  }

  // Stub injecte avant le code du plugin.
  // IMPORTANT : WPlugin etend StatelessWidget.
  // Le plugin definit class FooPlugin extends WPlugin et se termine par FooPlugin().
  // d4rt execute() retourne cette instance — qui EST un Flutter Widget.
  String _buildStub() {
    final id = widget.plugin.manifest.id;
    return '''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:typed_data';

// WPlugin : bridge statique entre le plugin et Watchtower.
// Etend StatelessWidget pour que l instance retournee par d4rt soit un Widget.
abstract class WPlugin extends StatelessWidget {
  const WPlugin({super.key});

  // build() appelle buildWidget() — implementee par chaque plugin.
  @override
  Widget build(BuildContext context) => buildWidget(context);

  Widget buildWidget(BuildContext context);

  static const _storageCh = MethodChannel('com.watchtower.app.storage');
  static const _pluginCh  = MethodChannel('com.watchtower.app.plugin');
  static const _urlCh     = MethodChannel('com.watchtower.app.url');

  static Future<String?> getPreference(String key) async {
    try {
      final r = await _storageCh.invokeMethod('get', {'key': key});
      return r?.toString();
    } catch (_) { return null; }
  }

  static Future<void> setPreference(String key, String value) async {
    try {
      await _storageCh.invokeMethod('set', {'key': key, 'value': value});
    } catch (_) {}
  }

  static Future<Map<String,dynamic>> invoke(String action, Map<String,dynamic> args) async {
    try {
      final r = await _pluginCh.invokeMethod('invoke', {
        'pluginId': WatchtowerContext.pluginId,
        'action': action,
        'args': args,
      });
      if (r is Map) return Map<String,dynamic>.from(r);
      return {'status': 'ok', 'data': r};
    } catch (e) { return {'status': 'error', 'error': e.toString()}; }
  }

  static Future<void> openUrl(String url) async {
    try { await _urlCh.invokeMethod('open', {'url': url}); } catch (_) {}
  }

  static Future<void> openReader(Map<String,dynamic> args) async {
    try { await _pluginCh.invokeMethod('openReader', {'args': args}); } catch (_) {}
  }

  static void showToast(String message) {
    try { _pluginCh.invokeMethod('toast', {'message': message}); } catch (_) {}
  }

  static Uint8List base64Decode(String b64) => base64.decode(b64);
  static dynamic  parseJson(String s)       => jsonDecode(s);
}

class WatchtowerZeusDL {
  static const _ch = MethodChannel('com.watchtower.app.zeusdl');
  static Future<Map<String,dynamic>> start({
    required String command, required List<String> args,
    void Function(double,String,String,String)? onProgress,
    void Function(String)? onLog,
  }) async {
    try {
      final r = await _ch.invokeMethod('start', {'command':command,'args':args});
      return Map<String,dynamic>.from(r as Map);
    } catch(e) { return {'success':false,'error':e.toString()}; }
  }
  static Future<Map<String,dynamic>> getInfo(String url) async {
    try {
      final r = await _ch.invokeMethod('getInfo', {'url':url});
      return Map<String,dynamic>.from(r as Map);
    } catch(e) { return {}; }
  }
}

class WatchtowerLog {
  static void info(String m)    => debugPrint('[Plugin/INFO] \$m');
  static void warn(String m)    => debugPrint('[Plugin/WARN] \$m');
  static void error(String m)   => debugPrint('[Plugin/ERR ] \$m');
  static void success(String m) => debugPrint('[Plugin/OK  ] \$m');
  static void progress(double p, Map opts) {}
}

class WatchtowerNotif {
  static const _ch = MethodChannel('com.watchtower.app.notif');
  static void show({required String title, required String body}) =>
    _ch.invokeMethod('show', {'title':title,'body':body});
}

class WatchtowerContext {
  static Map<String,dynamic> userConfig = {};
  static String pluginId = '${id}';
}
''';
  }

  Future<Widget> _interpret(String source) async {
    final interpreter = D4rt();
    final full = _buildStub() + source;
    // execute() retourne la derniere expression — FooPlugin() extends WPlugin extends StatelessWidget.
    final raw = interpreter.execute(source: full);
    final result = (raw is Future) ? await (raw as Future<dynamic>) : raw;
    if (result is Widget) return result as Widget;
    throw Exception(
      'Le plugin ne retourne pas un Widget (recu : \${result?.runtimeType}). '
      'Assurez-vous que ui/main.dart se termine par PluginClass().');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(
      backgroundColor: _bg,
      body: Center(child: CircularProgressIndicator(color: _teal)));
    if (_error != null) return Scaffold(
      backgroundColor: _bg,
      body: Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.code_off_rounded, color: Colors.red, size: 40),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: _grey), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          TextButton(onPressed: _load,
            child: const Text('Reessayer', style: TextStyle(color: _teal))),
        ]),
      )),
    );
    return _pluginWidget ?? const SizedBox.shrink();
  }
}
