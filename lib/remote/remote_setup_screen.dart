
import 'package:flutter/material.dart';
import 'package:watchtower/remote/remote_client.dart';

/// Shown on the web version to configure the remote server URL.
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
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final url = _ctrl.text.trim();
    if (url.isEmpty) return;
    setState(() { _testing = true; _error = null; });
    await RemoteClient.instance.setBaseUrl(url);
    final ok = await RemoteClient.instance.ping();
    if (!mounted) return;
    if (ok) {
      widget.onConnected?.call();
    } else {
      setState(() {
        _error = 'Impossible de se connecter. Vérifiez que le Mode Distant est actif sur votre appareil.';
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
                  'Ouvrez Watchtower sur votre téléphone ou PC, '
                  'activez le Mode Distant dans les paramètres, '
                  'puis collez le lien public ici.',
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
                  ),
                  onSubmitted: (_) => _connect(),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _testing ? null : _connect,
                  child: _testing
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Connecter'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
