import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/modules/more/providers/algorithm_weights_state_provider.dart';
import 'package:watchtower/modules/more/settings/general/providers/general_state_provider.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/modules/more/settings/general/providers/doh_provider_notifier.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:url_launcher/url_launcher.dart';

class GeneralScreen extends ConsumerStatefulWidget {
  const GeneralScreen({super.key});

  @override
  ConsumerState<GeneralScreen> createState() => _GeneralStateScreen();
}

class _GeneralStateScreen extends ConsumerState<GeneralScreen> {
  int _genre = 0;
  int _setting = 0;
  int _synopsis = 0;
  int _theme = 0;

  @override
  void initState() {
    super.initState();
    final algorithmWeights = ref.read(algorithmWeightsStateProvider);
    _genre = algorithmWeights.genre!;
    _setting = algorithmWeights.setting!;
    _synopsis = algorithmWeights.synopsis!;
    _theme = algorithmWeights.theme!;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = l10nLocalizations(context);
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
    return Scaffold(
      appBar: AppBar(title: Text(l10n!.general)),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── DNS over HTTPS ──────────────────────────────────────────────
            ExpansionTile(
              title: Text(l10n.dns_over_https),
              initiallyExpanded: doHState.enabled,
              trailing: IgnorePointer(
                child: Switch(value: doHState.enabled, onChanged: (_) {}),
              ),
              onExpansionChanged: (value) => ref
                  .read(doHProviderStateProvider.notifier)
                  .setDoHEnabled(value),
              children: [
                ListTile(
                  title: Text(l10n.dns_provider),
                  subtitle: Text(
                    availableProviders[doHState.providerId ?? 1].name,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.secondaryColor,
                    ),
                  ),
                  onTap: () {
                    final providerId = doHState.providerId ?? 1;
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: Text(l10n.dns_provider),
                          content: SizedBox(
                            width: context.width(0.8),
                            child: RadioGroup(
                              groupValue: providerId,
                              onChanged: (value) {
                                ref
                                    .read(doHProviderStateProvider.notifier)
                                    .setDoHProvider(value!);
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                              },
                              child: SuperListView.builder(
                                shrinkWrap: true,
                                itemCount: availableProviders.length,
                                itemBuilder: (context, index) {
                                  final provider = availableProviders[index];
                                  return RadioListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.all(0),
                                    value: provider.id,
                                    title: Text(provider.name),
                                  );
                                },
                              ),
                            ),
                          ),
                          actions: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () async {
                                    Navigator.pop(context);
                                  },
                                  child: Text(
                                    l10n.cancel,
                                    style: TextStyle(
                                      color: context.primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ),

            if (!doHState.enabled)
              ListTile(
                onTap: () => _showCustomDnsDialog(context, ref, customDns),
                title: Text(l10n.custom_dns),
                subtitle: Text(
                  customDns,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.secondaryColor,
                  ),
                ),
              ),

            // ── User Agent ──────────────────────────────────────────────────
            ListTile(
              onTap: () =>
                  _showDefaultUserAgentDialog(context, ref, userAgent),
              leading: const Icon(Icons.manage_accounts_rounded),
              title: Text(context.l10n.default_user_agent),
              subtitle: Text(
                userAgent,
                style: TextStyle(
                  fontSize: 11,
                  color: context.secondaryColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // ── Recommendation weights (modern card sliders) ────────────────
            _RecommendationWeightsCard(
              genre: _genre,
              setting: _setting,
              synopsis: _synopsis,
              theme: _theme,
              onGenreChanged: (v) {
                HapticFeedback.vibrate();
                setState(() => _genre = v);
              },
              onGenreEnd: (v) => ref
                  .read(algorithmWeightsStateProvider.notifier)
                  .setWeights(genre: _genre),
              onSettingChanged: (v) {
                HapticFeedback.vibrate();
                setState(() => _setting = v);
              },
              onSettingEnd: (v) => ref
                  .read(algorithmWeightsStateProvider.notifier)
                  .setWeights(setting: _setting),
              onSynopsisChanged: (v) {
                HapticFeedback.vibrate();
                setState(() => _synopsis = v);
              },
              onSynopsisEnd: (v) => ref
                  .read(algorithmWeightsStateProvider.notifier)
                  .setWeights(synopsis: _synopsis),
              onThemeChanged: (v) {
                HapticFeedback.vibrate();
                setState(() => _theme = v);
              },
              onThemeEnd: (v) => ref
                  .read(algorithmWeightsStateProvider.notifier)
                  .setWeights(theme: _theme),
              onReset: () {
                final defaultWeights = AlgorithmWeights();
                setState(() {
                  _genre = defaultWeights.genre!;
                  _setting = defaultWeights.setting!;
                  _synopsis = defaultWeights.synopsis!;
                  _theme = defaultWeights.theme!;
                });
                ref
                    .read(algorithmWeightsStateProvider.notifier)
                    .set(defaultWeights);
              },
            ),

            // ── Discord RPC ─────────────────────────────────────────────────
            SwitchListTile(
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
              value: hideDiscordRpcInIncognito,
              title: Text(l10n.hide_discord_rpc_incognito),
              onChanged: (value) {
                ref
                    .read(hideDiscordRpcInIncognitoStateProvider.notifier)
                    .set(value);
              },
            ),
            SwitchListTile(
              value: rpcShowReadingWatchingProgress,
              title: Text(l10n.rpc_show_reading_watching_progress),
              onChanged: (value) {
                ref
                    .read(rpcShowReadingWatchingProgressStateProvider.notifier)
                    .set(value);
              },
            ),
            SwitchListTile(
              value: rpcShowTitleState,
              title: Text(l10n.rpc_show_title),
              onChanged: (value) {
                ref.read(rpcShowTitleStateProvider.notifier).set(value);
              },
            ),
            SwitchListTile(
              value: rpcShowCoverImage,
              title: Text(l10n.rpc_show_cover_image),
              onChanged: (value) {
                ref.read(rpcShowCoverImageStateProvider.notifier).set(value);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomDnsDialog(
    BuildContext context,
    WidgetRef ref,
    String customDns,
  ) {
    final dnsController = TextEditingController(text: customDns);
    String dns = customDns;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
              context.l10n.custom_dns,
              style: const TextStyle(fontSize: 30),
            ),
            content: SizedBox(
              width: context.width(0.8),
              height: context.height(0.3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: TextFormField(
                      controller: dnsController,
                      autofocus: true,
                      onChanged: (value) => setState(() {
                        dns = value;
                      }),
                      decoration: InputDecoration(
                        hintText: "8.8.8.8",
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
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: SizedBox(
                      width: context.width(1),
                      child: ElevatedButton(
                        onPressed: () {
                          ref.read(customDnsStateProvider.notifier).set(dns);
                          Navigator.pop(context);
                        },
                        child: Text(context.l10n.dialog_confirm),
                      ),
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
// User-Agent dialog (with "Import from Device Browser" button)
// ─────────────────────────────────────────────────────────────────────────────

void _showDefaultUserAgentDialog(
  BuildContext context,
  WidgetRef ref,
  String ua,
) {
  final uaController = TextEditingController(text: ua);
  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
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
                    hintText: "Mozilla/5.0 (Windows NT 10.0; Win64; x64)...",
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
                // Import from device browser button
                OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                  label: const Text('Import from Device Browser'),
                  onPressed: () async {
                    final uri = Uri.parse('https://www.whatsmyua.info/');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Open the site, copy your User Agent, then paste it above.',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.secondaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      ref
                          .watch(userAgentStateProvider.notifier)
                          .set(uaController.text);
                      if (!context.mounted) return;
                      Navigator.pop(context);
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

// ─────────────────────────────────────────────────────────────────────────────
// Modern card sliders for recommendation weights
// ─────────────────────────────────────────────────────────────────────────────

class _RecommendationWeightsCard extends StatelessWidget {
  final int genre;
  final int setting;
  final int synopsis;
  final int theme;
  final ValueChanged<int> onGenreChanged;
  final ValueChanged<double> onGenreEnd;
  final ValueChanged<int> onSettingChanged;
  final ValueChanged<double> onSettingEnd;
  final ValueChanged<int> onSynopsisChanged;
  final ValueChanged<double> onSynopsisEnd;
  final ValueChanged<int> onThemeChanged;
  final ValueChanged<double> onThemeEnd;
  final VoidCallback onReset;

  const _RecommendationWeightsCard({
    required this.genre,
    required this.setting,
    required this.synopsis,
    required this.theme,
    required this.onGenreChanged,
    required this.onGenreEnd,
    required this.onSettingChanged,
    required this.onSettingEnd,
    required this.onSynopsisChanged,
    required this.onSynopsisEnd,
    required this.onThemeChanged,
    required this.onThemeEnd,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.45),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outline.withOpacity(0.25)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.tune_rounded,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.recommendations_weights,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onReset,
                    icon: const Icon(Icons.restore_rounded, size: 16),
                    label: Text(context.l10n.reset),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _WeightSliderCard(
                icon: Icons.category_rounded,
                label: context.l10n.recommendations_weights_genre,
                value: genre,
                color: Colors.blue,
                onChanged: onGenreChanged,
                onChangeEnd: onGenreEnd,
              ),
              const SizedBox(height: 8),
              _WeightSliderCard(
                icon: Icons.settings_rounded,
                label: context.l10n.recommendations_weights_setting,
                value: setting,
                color: Colors.purple,
                onChanged: onSettingChanged,
                onChangeEnd: onSettingEnd,
              ),
              const SizedBox(height: 8),
              _WeightSliderCard(
                icon: Icons.article_rounded,
                label: context.l10n.recommendations_weights_synopsis,
                value: synopsis,
                color: Colors.teal,
                onChanged: onSynopsisChanged,
                onChangeEnd: onSynopsisEnd,
              ),
              const SizedBox(height: 8),
              _WeightSliderCard(
                icon: Icons.palette_rounded,
                label: context.l10n.recommendations_weights_theme,
                value: theme,
                color: Colors.orange,
                onChanged: onThemeChanged,
                onChangeEnd: onThemeEnd,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeightSliderCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final ValueChanged<int> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _WeightSliderCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final percent = value.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  '$percent%',
                  key: ValueKey(percent),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              thumbColor: color,
              overlayColor: color.withOpacity(0.15),
              inactiveTrackColor: color.withOpacity(0.2),
              trackHeight: 4,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider.adaptive(
              min: 0,
              max: 100,
              value: value.toDouble(),
              onChanged: (v) => onChanged(v.toInt()),
              onChangeEnd: onChangeEnd,
            ),
          ),
        ],
      ),
    );
  }
}
