import 'dart:io';
import 'package:flutter/material.dart';
import 'package:watchtower/modules/plugins/flare_loader.dart';
import 'package:d4rt/d4rt.dart';

// FlareEvalRenderer — méthode eval : interprète ui/main.dart via d4rt
// Le script hérite de WPlugin (bridge injecté) qui expose ZeusDL, Log, Notif, Storage

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

  // Stub d4rt context injecté avant le code du plugin
  String _buildStub() => '''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Bridge de base — tout plugin extends WPlugin
abstract class WPlugin {
  Widget buildWidget(BuildContext context);
}

// ZeusDL — binaire déjà dans l APK, appelé via commandScopes
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
  static void info(String m)    => debugPrint('[Plugin/INFO] ' + m);
  static void warn(String m)    => debugPrint('[Plugin/WARN] ' + m);
  static void error(String m)   => debugPrint('[Plugin/ERR ] ' + m);
  static void success(String m) => debugPrint('[Plugin/OK  ] ' + m);
  static void progress(double p, Map opts) {}
}

class WatchtowerNotif {
  static const _ch = MethodChannel('com.watchtower.app.notif');
  static void show({required String title, required String body}) =>
    _ch.invokeMethod('show', {'title':title,'body':body});
}

class WatchtowerContext {
  static Map<String,dynamic> userConfig = {};
  static String pluginId = '';
}
''';

  Future<Widget> _interpret(String source) async {
    final interpreter = D4rt();
    final full = _buildStub() + source;
    final result = interpreter.execute(source: full);
    if (result is Widget) return result;
    throw Exception('Plugin ne retourne pas un Widget.');
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
            child: const Text('Réessayer', style: TextStyle(color: _teal))),
        ]),
      )),
    );
    return _pluginWidget ?? const SizedBox.shrink();
  }
}