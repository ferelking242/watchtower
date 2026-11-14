import 'package:flutter/material.dart';
  import 'package:flutter/services.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/remote/remote_mode_provider.dart';
  import 'package:watchtower/utils/extensions/build_context_extensions.dart';

  class RemoteModeScreen extends ConsumerWidget {
    const RemoteModeScreen({super.key});

    @override
    Widget build(BuildContext context, WidgetRef ref) {
      final state = ref.watch(remoteModeProvider);

      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.settings_remote_mode)),
        body: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, stack) => _ErrorFullPage(error: e.toString()),
          data: (s) => _Body(state: s),
        ),
      );
    }
  }

  // ── Erreur de chargement du provider (pleine page) ───────────────────────────
  class _ErrorFullPage extends StatelessWidget {
    final String error;
    const _ErrorFullPage({required this.error});

    @override
    Widget build(BuildContext context) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48,
                color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(context.l10n.settings_error,
                style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                error,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: error));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.l10n.remote_error_copied),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.copy, size: 16),
              label: Text(context.l10n.remote_copy_error),
            ),
          ],
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
                        state.isRunning
                            ? Icons.wifi_tethering
                            : Icons.wifi_tethering_off,
                        color: state.isRunning
                            ? Colors.green
                            : context.secondaryColor,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(context.l10n.remote_server_title,
                                style: Theme.of(context).textTheme.titleMedium),
                            Text(
                              state.isRunning
                                    ? context.l10n.browse_status_active
                                    : context.l10n.browse_status_inactive,
                              style: TextStyle(
                                color: state.isRunning
                                    ? Colors.green
                                    : context.secondaryColor,
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
            // ── Tunnel URL ────────────────────────────────────────────────
            Text(context.l10n.remote_public_link,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            if (state.tunnelUrl != null)
              _UrlCard(
                url: state.tunnelUrl!,
                label: context.l10n.remote_paste_in_web,
                icon: Icons.cloud_outlined,
                isPrimary: true,
              )
            else if (state.tunnelError != null)
              _TunnelErrorCard(error: state.tunnelError!)
            else
              Card(
                child: ListTile(
                  leading: const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  title: Text(context.l10n.remote_tunnel_starting),
                  subtitle: Text(context.l10n.remote_tunnel_ssh_hint),
                ),
              ),

            const SizedBox(height: 16),

            // ── Local URL ─────────────────────────────────────────────────
            Text(context.l10n.remote_local_link,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _UrlCard(
              url: state.localUrl ?? 'http://localhost:4567',
              label: context.l10n.remote_use_same_network,
              icon: Icons.lan_outlined,
              isPrimary: false,
            ),
            const SizedBox(height: 16),

            // ── API key ───────────────────────────────────────────────────
            Text(context.l10n.remote_api_key,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: Icon(Icons.vpn_key_outlined,
                    color: context.secondaryColor),
                title: SelectableText(
                  state.apiKey ?? '...',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
                subtitle: Text(context.l10n.remote_api_key_hint),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.copy),
                      tooltip: context.l10n.remote_copy,
                      onPressed: state.apiKey == null
                          ? null
                          : () {
                              Clipboard.setData(
                                  ClipboardData(text: state.apiKey!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(context.l10n.remote_key_copied),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: context.l10n.remote_regenerate,
                      onPressed: () async {
                        await notifier.regenerateApiKey();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(context.l10n.remote_new_key),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Instructions ──────────────────────────────────────────────
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.info_outline,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer),
                      const SizedBox(width: 8),
                      Text(
                        context.l10n.remote_how_to_use,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.remote_how_to_use_body,
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer),
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
                    Text(
                      context.l10n.remote_how_it_works,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(context.l10n.remote_how_it_works_body),
                  ],
                ),
              ),
            ),
          ],
        ],
      );
    }
  }

  // ── Carte d'erreur tunnel : multiline + sélectionnable + bouton copier ────────
  class _TunnelErrorCard extends StatelessWidget {
    final String error;
    const _TunnelErrorCard({required this.error});

    @override
    Widget build(BuildContext context) {
      final bg = Theme.of(context).colorScheme.errorContainer;
      final fg = Theme.of(context).colorScheme.onErrorContainer;
      return Card(
        color: bg,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.warning_amber_rounded, color: fg),
                const SizedBox(width: 8),
                Text(context.l10n.remote_tunnel_unavailable,
                    style: TextStyle(fontWeight: FontWeight.bold, color: fg)),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.copy, size: 18, color: fg),
                  tooltip: context.l10n.remote_copy_error,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: error));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.l10n.remote_error_copied),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ]),
              const SizedBox(height: 8),
              SelectableText(
                error,
                style: TextStyle(
                    fontFamily: 'monospace', fontSize: 12, color: fg),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.remote_check_connection,
                style: TextStyle(fontSize: 12, color: fg.withValues(alpha: 0.75)),
              ),
            ],
          ),
        ),
      );
    }
  }

  // ── Carte URL avec texte sélectionnable + bouton copier ──────────────────────
  class _UrlCard extends StatelessWidget {
    final String url;
    final String label;
    final IconData icon;
    final bool isPrimary;
    const _UrlCard({
      required this.url,
      required this.label,
      required this.icon,
      required this.isPrimary,
    });

    @override
    Widget build(BuildContext context) {
      return Card(
        child: ListTile(
          leading: Icon(icon,
              color: isPrimary ? context.primaryColor : context.secondaryColor),
          title: SelectableText(
            url,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
          subtitle: Text(label),
          trailing: IconButton(
            icon: const Icon(Icons.copy),
            tooltip: context.l10n.remote_copy,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.l10n.remote_link_copied),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ),
      );
    }
  }
  