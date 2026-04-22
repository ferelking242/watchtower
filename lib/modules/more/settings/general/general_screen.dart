import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/modules/more/settings/general/providers/doh_provider_notifier.dart';
import 'package:watchtower/modules/more/settings/general/providers/general_state_provider.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/services/http/doh/doh_providers.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:url_launcher/url_launcher.dart';

class GeneralScreen extends ConsumerWidget {
  const GeneralScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = l10nLocalizations(context)!;
    final customDns = ref.watch(customDnsStateProvider);
    final userAgent = ref.watch(userAgentStateProvider);
    final enableDiscordRpc = ref.watch(enableDiscordRpcStateProvider);
    final hideDiscordRpcInIncognito = ref.watch(
      hideDiscordRpcInIncognitoStateProvider,
    );
    final rpcShowReadingWatchingProgress = ref.watch(
      rpcShowReadingWatchingProgressStateProvider,
    );
    final rpcShowTitleState = ref.watch(rpcShowTitleStateProvider);
    final rpcShowCoverImage = ref.watch(rpcShowCoverImageStateProvider);
    final doHState = ref.watch(doHProviderStateProvider);
    final availableProviders = ref.watch(availableDoHProvidersProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.general)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ──────────────────────────────────────────────────────────────────
            // RÉSEAU
            // ──────────────────────────────────────────────────────────────────
            _SectionHeader(
              icon: Icons.wifi_rounded,
              label: 'Réseau',
              colorScheme: colorScheme,
            ),

            // DNS over HTTPS
            ExpansionTile(
              leading: const Icon(Icons.security_rounded),
              title: Text(l10n.dns_over_https),
              subtitle: doHState.enabled
                  ? Text(
                      availableProviders[doHState.providerId ?? 0].name,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.secondaryColor,
                      ),
                    )
                  : Text(
                      'Désactivé',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.error.withOpacity(0.7),
                      ),
                    ),
              initiallyExpanded: doHState.enabled,
              trailing: IgnorePointer(
                child: Switch(value: doHState.enabled, onChanged: (_) {}),
              ),
              onExpansionChanged: (value) => ref
                  .read(doHProviderStateProvider.notifier)
                  .setDoHEnabled(value),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chiffre vos requêtes DNS pour empêcher votre opérateur ou réseau de voir les sites que vous visitez.',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.dns_rounded,
                          color: colorScheme.primary,
                        ),
                        title: Text(l10n.dns_provider),
                        subtitle: Text(
                          availableProviders[doHState.providerId ?? 0].name,
                          style: TextStyle(
                            fontSize: 11,
                            color: context.secondaryColor,
                          ),
                        ),
                        onTap: () => _showDnsProviderDialog(
                          context,
                          ref,
                          doHState,
                          availableProviders,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Custom DNS (when DoH is off)
            if (!doHState.enabled)
              ListTile(
                leading: const Icon(Icons.settings_ethernet_rounded),
                onTap: () =>
                    _showCustomDnsDialog(context, ref, customDns, l10n),
                title: Text(l10n.custom_dns),
                subtitle: Text(
                  customDns.isEmpty ? 'Système par défaut' : customDns,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.secondaryColor,
                  ),
                ),
              ),

            // User Agent
            ListTile(
              leading: const Icon(Icons.manage_accounts_rounded),
              onTap: () =>
                  _showDefaultUserAgentDialog(context, ref, userAgent),
              title: Text(context.l10n.default_user_agent),
              subtitle: Text(
                userAgent,
                style: TextStyle(fontSize: 11, color: context.secondaryColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const Divider(height: 8, indent: 16, endIndent: 16),

            // ──────────────────────────────────────────────────────────────────
            // RECOMMANDATIONS
            // ──────────────────────────────────────────────────────────────────
            _SectionHeader(
              icon: Icons.auto_awesome_rounded,
              label: 'Recommandations',
              colorScheme: colorScheme,
            ),

            ListTile(
              leading: const Icon(Icons.recommend_rounded),
              title: const Text('Recommandations'),
              subtitle: const Text(
                'Algorithme, similarité et poids de pertinence',
                style: TextStyle(fontSize: 11),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/recommendations'),
            ),

            const Divider(height: 8, indent: 16, endIndent: 16),

            // ──────────────────────────────────────────────────────────────────
            // ACTIVITÉ
            // ──────────────────────────────────────────────────────────────────
            _SectionHeader(
              icon: Icons.sensors_rounded,
              label: 'Activité',
              colorScheme: colorScheme,
            ),

            SwitchListTile(
              secondary: const Icon(Icons.discord),
              value: enableDiscordRpc,
              title: Text(l10n.enable_discord_rpc),
              onChanged: (value) {
                ref.read(enableDiscordRpcStateProvider.notifier).set(value);
                if (value) {
                  discordRpc?.connect(ref);
                } else {
                  discordRpc?.disconnect();
                }
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.visibility_off_rounded),
              value: hideDiscordRpcInIncognito,
              title: Text(l10n.hide_discord_rpc_incognito),
              onChanged: (value) {
                ref
                    .read(hideDiscordRpcInIncognitoStateProvider.notifier)
                    .set(value);
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.track_changes_rounded),
              value: rpcShowReadingWatchingProgress,
              title: Text(l10n.rpc_show_reading_watching_progress),
              onChanged: (value) {
                ref
                    .read(rpcShowReadingWatchingProgressStateProvider.notifier)
                    .set(value);
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.title_rounded),
              value: rpcShowTitleState,
              title: Text(l10n.rpc_show_title),
              onChanged: (value) {
                ref.read(rpcShowTitleStateProvider.notifier).set(value);
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.image_rounded),
              value: rpcShowCoverImage,
              title: Text(l10n.rpc_show_cover_image),
              onChanged: (value) {
                ref.read(rpcShowCoverImageStateProvider.notifier).set(value);
              },
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showDnsProviderDialog(
    BuildContext context,
    WidgetRef ref,
    DoHProviderState doHState,
    List<DoHProvider> providers,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Fournisseur DNS'),
          content: SizedBox(
            width: context.width(0.9),
            child: SuperListView.builder(
              shrinkWrap: true,
              itemCount: providers.length,
              itemBuilder: (_, index) {
                final p = providers[index];
                final selected = (doHState.providerId ?? 0) == p.id;
                return RadioListTile<int>(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  value: p.id,
                  groupValue: doHState.providerId ?? 0,
                  title: Row(
                    children: [
                      Text(
                        p.name,
                        style: TextStyle(
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (p.region != 'Global')
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            p.region,
                            style: TextStyle(
                              fontSize: 9,
                              color: colorScheme.onTertiaryContainer,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    p.description,
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  onChanged: (value) {
                    ref
                        .read(doHProviderStateProvider.notifier)
                        .setDoHProvider(value!);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  void _showCustomDnsDialog(
    BuildContext context,
    WidgetRef ref,
    String customDns,
    dynamic l10n,
  ) {
    final dnsController = TextEditingController(text: customDns);
    String dns = customDns;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: Text(
              context.l10n.custom_dns,
              style: const TextStyle(fontSize: 22),
            ),
            content: SizedBox(
              width: context.width(0.8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: dnsController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    onChanged: (v) => setState(() => dns = v),
                    decoration: InputDecoration(
                      hintText: '8.8.8.8',
                      filled: false,
                      contentPadding: const EdgeInsets.all(12),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(width: 0.4),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(5),
                        borderSide: const BorderSide(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        ref.read(customDnsStateProvider.notifier).set(dns);
                        Navigator.pop(ctx);
                      },
                      child: Text(context.l10n.dialog_confirm),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme colorScheme;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// User-Agent dialog
// ─────────────────────────────────────────────────────────────────────────────

void _showDefaultUserAgentDialog(
  BuildContext context,
  WidgetRef ref,
  String ua,
) {
  final uaController = TextEditingController(text: ua);
  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        return AlertDialog(
          title: Text(
            context.l10n.default_user_agent,
            style: const TextStyle(fontSize: 22),
          ),
          content: SizedBox(
            width: context.width(0.8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                TextFormField(
                  controller: uaController,
                  autofocus: true,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)...',
                    filled: false,
                    contentPadding: const EdgeInsets.all(12),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(width: 0.4),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: const BorderSide(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                  label: const Text('Import from Device Browser'),
                  onPressed: () async {
                    final uri = Uri.parse('https://www.whatsmyua.info/');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ouvre le site, copie ton User Agent, puis colle-le ci-dessus.',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.secondaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      ref
                          .read(userAgentStateProvider.notifier)
                          .set(uaController.text);
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                    },
                    child: Text(context.l10n.dialog_confirm),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
