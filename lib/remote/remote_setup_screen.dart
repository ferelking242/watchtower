
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const _kPrefKey = 'remote_server_url';

/// Shown on the web version when no server is configured.
/// Auto-saves URL so future visits reconnect automatically.
class RemoteSetupScreen extends StatefulWidget {
  final VoidCallback? onConnected;
  const RemoteSetupScreen({super.key, this.onConnected});

  @override
  State<RemoteSetupScreen> createState() => _RemoteSetupScreenState();
}

class _RemoteSetupScreenState extends State<RemoteSetupScreen> {
  final _ctrl = TextEditingController();
  bool _testing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kPrefKey);
    if (saved != null) _ctrl.text = saved;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final url = _ctrl.text.trim().replaceAll(RegExp(r'/$'), '');
    if (url.isEmpty) return;
    setState(() { _testing = true; _error = null; });
    try {
      final res = await http.get(Uri.parse('$url/api/ping'))
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['ok'] == true) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_kPrefKey, url);
          widget.onConnected?.call();
          return;
        }
      }
      setState(() {
        _error = 'Serveur introuvable. Vérifiez que le Mode Distant est actif.';
        _testing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de se connecter : $e';
        _testing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.wifi_tethering, size: 64),
                const SizedBox(height: 16),
                Text('Connexion au serveur Watchtower',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const Text(
                  '1. Ouvrez Watchtower sur votre téléphone ou PC\n'
                  '2. Allez dans Paramètres → Mode Distant\n'
                  '3. Activez le serveur et copiez le lien public\n'
                  '4. Collez-le ici — la prochaine visite sera automatique',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _ctrl,
                  decoration: InputDecoration(
                    labelText: 'URL du serveur',
                    hintText: 'https://xxxx.trycloudflare.com',
                    border: const OutlineInputBorder(),
                    errorText: _error,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.paste),
                      onPressed: () async {
                        final data = await Clipboard.getData('text/plain');
                        if (data?.text != null) _ctrl.text = data!.text!.trim();
                      },
                    ),
                  ),
                  onSubmitted: (_) => _connect(),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _testing ? null : _connect,
                  icon: _testing
                      ? const SizedBox(
                          height: 18, width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.link),
                  label: Text(_testing ? 'Connexion...' : 'Connecter'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
