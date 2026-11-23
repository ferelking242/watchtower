import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/browse/marketplace_palette.dart';
import 'package:watchtower/modules/live_tv/models/live_provider.dart';
import 'package:watchtower/modules/live_tv/providers/live_providers.dart';
import 'package:watchtower/modules/live_tv/screens/live_channels_screen.dart';
import 'package:watchtower/providers/l10n_providers.dart';

/// The Live tab of the Marketplace.
///
/// Live TV providers are published in `index/live.json` like any other
/// extension, but they were only reachable from a sheet buried in the Live TV
/// settings, so a user who opened the Marketplace had no way to discover them —
/// and the Live TV screen even claimed they were installed "from the
/// Marketplace's Watch section", which was not true.
///
/// Installing here writes a [LiveProvider] record. Nothing is downloaded or
/// executed: a provider is data (a playlist URL, a panel address, or a bundled
/// asset path), so a hostile index can only offer bad channels.
class MarketplaceLiveSection extends ConsumerWidget {
  const MarketplaceLiveSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = MarketplacePalette.of(context);
    final l10n = context.l10n;
    final installed = ref.watch(liveProvidersProvider);
    final stats = ref.watch(liveFetchStatsProvider);
    final catalog = ref.watch(liveCatalogProvider);
    final installedIds = {for (final provider in installed) provider.id};

    final available = catalog.maybeWhen(
      data: (entries) =>
          entries.where((entry) => !installedIds.contains(entry.id)).toList(),
      orElse: () => const <LiveProviderCatalogEntry>[],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(palette: palette, title: l10n.marketplace_live_title),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 4),
          child: Text(
            l10n.marketplace_live_subtitle,
            style: TextStyle(
              color: palette.muted,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
        ),
        if (installed.isNotEmpty) ...[
          _GroupLabel(palette: palette, text: l10n.marketplace_live_installed),
          for (final provider in installed)
            _InstalledProviderRow(
              provider: provider,
              channelCount: stats[provider.id]?.channelCount,
            ),
        ],
        _GroupLabel(palette: palette, text: l10n.marketplace_live_available),
        catalog.when(
          loading: () => const _CatalogLoading(),
          error: (error, _) => _CatalogError(
            message: '$error',
            onRetry: () => ref.invalidate(liveCatalogProvider),
          ),
          data: (_) {
            if (available.isEmpty) {
              return _CatalogEmpty(
                palette: palette,
                text: l10n.marketplace_live_empty,
              );
            }
            return Column(
              children: [
                for (final entry in available) _CatalogEntryRow(entry: entry),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.palette, required this.title});

  final MarketplacePalette palette;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: palette.accentCyan.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.live_tv_rounded,
              size: 16,
              color: palette.accentCyan,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: palette.text,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.palette, required this.text});

  final MarketplacePalette palette;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: palette.muted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// One installed provider: opens its channel browser.
class _InstalledProviderRow extends StatelessWidget {
  const _InstalledProviderRow({
    required this.provider,
    required this.channelCount,
  });

  final LiveProvider provider;
  final int? channelCount;

  @override
  Widget build(BuildContext context) {
    final palette = MarketplacePalette.of(context);
    final subtitle = _subtitle(context);
    return _RowShell(
      palette: palette,
      onTap: provider.isEnabled
          ? () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => LiveChannelsScreen(provider: provider),
              ),
            )
          : null,
      leading: _ProviderAvatar(provider: provider),
      title: provider.name,
      subtitle: subtitle,
      trailing: Icon(
        provider.isEnabled ? Broken.play_circle : Broken.close_circle,
        size: 22,
        color: provider.isEnabled ? palette.accent : palette.muted,
      ),
    );
  }

  String _subtitle(BuildContext context) {
    final l10n = context.l10n;
    final parts = <String>[];
    if (channelCount != null && channelCount! > 0) {
      parts.add(l10n.marketplace_live_channels(channelCount!));
    }
    parts.add('v${provider.version}');
    if (!provider.isEnabled) parts.add(l10n.marketplace_live_disabled);
    return parts.join(' · ');
  }
}

/// One published provider the user has not installed yet.
class _CatalogEntryRow extends ConsumerStatefulWidget {
  const _CatalogEntryRow({required this.entry});

  final LiveProviderCatalogEntry entry;

  @override
  ConsumerState<_CatalogEntryRow> createState() => _CatalogEntryRowState();
}

class _CatalogEntryRowState extends ConsumerState<_CatalogEntryRow> {
  bool _busy = false;

  Future<void> _install() async {
    if (_busy) return;
    setState(() => _busy = true);
    final entry = widget.entry;
    try {
      await ref.read(liveProvidersProvider.notifier).install(entry);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.marketplace_live_installed_toast(entry.name),
          ),
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = MarketplacePalette.of(context);
    return _RowShell(
      palette: palette,
      title: widget.entry.name,
      subtitle: widget.entry.description?.isNotEmpty == true
          ? widget.entry.description!
          : 'v${widget.entry.version}',
      leading: _ProviderAvatar(entry: widget.entry),
      trailing: _busy
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: palette.accent,
              ),
            )
          : FilledButton(
              onPressed: _install,
              style: FilledButton.styleFrom(
                backgroundColor: palette.accentCyan,
                foregroundColor: palette.onAccent,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                minimumSize: const Size(0, 34),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(context.l10n.install),
            ),
    );
  }
}

/// Shared row chrome: a card-shaped tappable row that never overflows.
///
/// The title and subtitle are the only flexible parts, so a long playlist name
/// or a long description ellipsises instead of pushing the trailing action off
/// a 320 dp screen.
class _RowShell extends StatelessWidget {
  const _RowShell({
    required this.palette,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final MarketplacePalette palette;
  final Widget leading;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 3, 16, 3),
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.text,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 11.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProviderAvatar extends StatelessWidget {
  const _ProviderAvatar({this.provider, this.entry});

  final LiveProvider? provider;
  final LiveProviderCatalogEntry? entry;

  @override
  Widget build(BuildContext context) {
    final palette = MarketplacePalette.of(context);
    final url = provider?.iconUrl ?? entry?.iconUrl;
    final kind = provider?.kind ?? entry?.kind ?? LiveProviderKind.m3u;
    final icon = switch (kind) {
      LiveProviderKind.m3u => Broken.video_play,
      LiveProviderKind.xtream => Broken.lock,
      LiveProviderKind.json => Broken.document_text,
      LiveProviderKind.bundled => Broken.folder,
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: SizedBox(
        width: 38,
        height: 38,
        child: url != null && url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(palette, icon),
              )
            : _fallback(palette, icon),
      ),
    );
  }

  Widget _fallback(MarketplacePalette palette, IconData icon) => ColoredBox(
    color: palette.surfaceHighest,
    child: Icon(icon, size: 19, color: palette.accentCyan),
  );
}

class _CatalogLoading extends StatelessWidget {
  const _CatalogLoading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 28),
    child: Center(child: CircularProgressIndicator()),
  );
}

class _CatalogEmpty extends StatelessWidget {
  const _CatalogEmpty({required this.palette, required this.text});

  final MarketplacePalette palette;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
      child: Text(
        text,
        style: TextStyle(color: palette.muted, fontSize: 12.5, height: 1.4),
      ),
    );
  }
}

class _CatalogError extends StatelessWidget {
  const _CatalogError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = MarketplacePalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: TextStyle(color: palette.muted, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: Icon(Broken.refresh, size: 16, color: palette.text),
            label: Text(
              context.l10n.retry,
              style: TextStyle(color: palette.text, fontSize: 12.5),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: palette.border),
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
          ),
        ],
      ),
    );
  }
}
