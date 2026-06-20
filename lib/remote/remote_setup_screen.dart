import 'package:flutter/foundation.dart';
  import 'package:flutter/material.dart';
  import 'package:flutter/services.dart';
  import 'package:shared_preferences/shared_preferences.dart';
  import 'package:http/http.dart' as http;
  import 'dart:async';
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
      if (saved != null && mounted) setState(() => _ctrl.text = saved);
    }

    @override
    void dispose() {
      _ctrl.dispose();
      super.dispose();
    }

    Future<void> _connect() async {
      final url = _ctrl.text.trim().replaceAll(RegExp(r'/+$'), '');
      if (url.isEmpty) {
        setState(() => _error = 'Entrez une URL de serveur.');
        return;
      }

      // ── Vérification mixed content (HTTP depuis une page HTTPS) ─────────────
      // Les navigateurs bloquent silencieusement les requêtes HTTP depuis HTTPS,
      // ce qui rend le Future http.get() bloqué indéfiniment.
      if (kIsWeb && url.startsWith('http://') && !url.startsWith('http://localhost')) {
        setState(() {
          _testing = false;
          _error =
              'URL HTTP bloquée par le navigateur (cette page est HTTPS).\n'
              'Utilisez le lien public HTTPS du tunnel SSH :\n'
              'ex. https://xxxx.lhr.life';
        });
        return;
      }

      setState(() { _testing = true; _error = null; });

      try {
        final res = await http
            .get(Uri.parse('$url/api/ping'))
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () => throw TimeoutException(
                'Délai dépassé (10s) — serveur inaccessible ou URL incorrecte',
              ),
            );

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
          _error = 'Serveur introuvable (HTTP ${res.statusCode}).\n'
                   'Vérifiez que le Mode Distant est actif sur votre appareil.';
          _testing = false;
        });
      } on TimeoutException catch (e) {
        if (!mounted) return;
        setState(() { _error = e.message ?? 'Délai dépassé'; _testing = false; });
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
                  Text(
                    'Connexion au serveur Watchtower',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
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
                      hintText: 'https://xxxx.lhr.life',
                      border: const OutlineInputBorder(),
                      errorText: _error == null ? null : '', // affiche la bordure rouge
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.paste),
                        onPressed: () async {
                          final data = await Clipboard.getData('text/plain');
                          if (data?.text != null) {
                            setState(() => _ctrl.text = data!.text!.trim());
                          }
                        },
                      ),
                    ),
                    onSubmitted: (_) => _connect(),
                  ),
                  // Message d'erreur multiline sélectionnable
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 18,
                              color: Theme.of(context).colorScheme.onErrorContainer),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SelectableText(
                              _error!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.copy, size: 16,
                                color: Theme.of(context).colorScheme.onErrorContainer),
                            tooltip: 'Copier l\'erreur',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _error!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Erreur copiée'),
                                    duration: Duration(seconds: 2)),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _testing ? null : _connect,
                    icon: _testing
                        ? const SizedBox(
                            height: 18, width: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
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
  