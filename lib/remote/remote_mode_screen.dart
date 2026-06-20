
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/remote/remote_mode_provider.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';

class RemoteModeScreen extends ConsumerWidget {
  const RemoteModeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(remoteModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mode Distant')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (s) => _Body(state: s),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final RemoteModeState state;
  const _Body({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(remoteModeProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Status card ──────────────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      state.isRunning ? Icons.wifi_tethering : Icons.wifi_tethering_off,
                      color: state.isRunning ? Colors.green : context.secondaryColor,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Serveur Distant',
                              style: Theme.of(context).textTheme.titleMedium),
                          Text(
                            state.isRunning ? 'Actif' : 'Inactif',
                            style: TextStyle(
                              color: state.isRunning ? Colors.green : context.secondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: state.isRunning,
                      onChanged: (_) => notifier.toggle(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        if (state.isRunning) ...[
          // ── Tunnel URL ────────────────────────────────────────────────────
          const Text('Lien public (tunnel Cloudflare)',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          if (state.tunnelUrl != null)
            _UrlCard(
              url: state.tunnelUrl!,
              label: 'Coller ce lien dans la version web',
              icon: Icons.cloud_outlined,
              isPrimary: true,
            )
          else if (state.tunnelError != null)
            // Tunnel failed — show error (binary not found, download failed, etc.)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: Icon(Icons.warning_amber_rounded,
                    color: Theme.of(context).colorScheme.onErrorContainer),
                title: Text(
                  'Tunnel indisponible',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer),
                ),
                subtitle: Text(
                  state.tunnelError!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontSize: 12),
                ),
              ),
            )
          else if (state.downloadProgress != null)
            // Downloading cloudflared binary
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      title: Text('Téléchargement de cloudflared...'),
                      subtitle: Text('Première utilisation — environ 30 Mo'),
                    ),
                    LinearProgressIndicator(
                      value: state.downloadProgress,
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${((state.downloadProgress ?? 0) * 100).toStringAsFixed(0)} %',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            )
          else
            // Waiting for tunnel URL (cloudflared started, waiting for output)
            const Card(
              child: ListTile(
                leading: CircularProgressIndicator(strokeWidth: 2),
                title: Text('Tunnel en cours de démarrage...'),
                subtitle: Text('Cela prend environ 10 secondes'),
              ),
            ),

          const SizedBox(height: 16),

          // ── Local URL ───────────────────────────────────────────────────
          const Text('Lien local (même réseau Wi-Fi)',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _UrlCard(
            url: state.localUrl ?? 'http://localhost:4567',
            label: 'Utiliser si vous êtes sur le même réseau',
            icon: Icons.lan_outlined,
            isPrimary: false,
          ),
          const SizedBox(height: 24),

          // ── Instructions ─────────────────────────────────────────────
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.info_outline,
                        color: Theme.of(context).colorScheme.onPrimaryContainer),
                    const SizedBox(width: 8),
                    Text('Comment utiliser',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        )),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    '1. Copiez le lien public ci-dessus\n'
                    '2. Ouvrez watchtower sur le web\n'
                    '3. Allez dans Paramètres → Connexion distante\n'
                    '4. Collez le lien et connectez-vous\n'
                    '5. Toutes les extensions et sources seront disponibles',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Comment ça marche',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  const Text(
                    'Quand le Mode Distant est actif, votre appareil devient un serveur. '
                    'Un lien public est créé automatiquement via un tunnel Cloudflare — '
                    'accessible depuis n\'importe où dans le monde, sans configuration réseau.\n\n'
                    'La version web de Watchtower peut ensuite se connecter à ce lien '
                    'pour utiliser toutes vos extensions et sources installées.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _UrlCard extends StatelessWidget {
  final String url;
  final String label;
  final IconData icon;
  final bool isPrimary;
  const _UrlCard({required this.url, required this.label, required this.icon, required this.isPrimary});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: isPrimary ? context.primaryColor : context.secondaryColor),
        title: Text(url, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
        subtitle: Text(label),
        trailing: IconButton(
          icon: const Icon(Icons.copy),
          tooltip: 'Copier',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: url));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Lien copié'), duration: Duration(seconds: 2)),
            );
          },
        ),
      ),
    );
  }
}
