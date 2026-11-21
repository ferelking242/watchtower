import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/live_tv/models/live_provider.dart';
import 'package:watchtower/modules/live_tv/providers/live_providers.dart';
import 'package:watchtower/modules/live_tv/screens/live_player_screen.dart';

/// Channel browser for one provider.
///
/// Filtering happens in memory: a playlist is fetched once and can hold tens of
/// thousands of entries, so typing must not trigger a request per keystroke.
class LiveChannelsScreen extends ConsumerStatefulWidget {
  const LiveChannelsScreen({super.key, required this.provider});

  final LiveProvider provider;

  @override
  ConsumerState<LiveChannelsScreen> createState() => _LiveChannelsScreenState();
}

class _LiveChannelsScreenState extends ConsumerState<LiveChannelsScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _group;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final channelsAsync = ref.watch(liveChannelsProvider(widget.provider.id));

    return Scaffold(
      appBar: AppBar(title: Text(widget.provider.name)),
      body: channelsAsync.when(
        loading: () => const _LoadingState(),
        error: (error, _) => _ErrorState(
          message: '$error',
          onRetry: () => ref.invalidate(liveChannelsProvider(widget.provider.id)),
        ),
        data: (channels) {
          if (channels.isEmpty) return const _NoChannelsState();
          final visible = _filter(channels);
          return Column(
            children: [
              _buildSearch(),
              _buildGroupChips(channels),
              Expanded(
                child: visible.isEmpty
                    ? const _NoMatchState()
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: visible.length,
                        itemBuilder: (context, index) =>
                            _ChannelTile(channel: visible[index]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Rechercher une chaîne',
          prefixIcon: const Icon(Broken.search_normal, size: 20),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Broken.close_circle, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                ),
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        onChanged: (value) => setState(() => _query = value.trim()),
      ),
    );
  }

  Widget _buildGroupChips(List<LiveChannel> channels) {
    final groups = <String>{};
    for (final channel in channels) {
      final group = channel.group;
      if (group != null && group.isNotEmpty) groups.add(group);
    }
    if (groups.isEmpty) return const SizedBox.shrink();

    final sorted = groups.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: sorted.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final group = isAll ? null : sorted[index - 1];
          final selected = _group == group;
          return ChoiceChip(
            label: Text(isAll ? 'Tout' : group!),
            selected: selected,
            onSelected: (_) => setState(() => _group = group),
          );
        },
      ),
    );
  }

  List<LiveChannel> _filter(List<LiveChannel> channels) {
    final query = _query.toLowerCase();
    return [
      for (final channel in channels)
        if ((_group == null || channel.group == _group) &&
            (query.isEmpty || channel.name.toLowerCase().contains(query)))
          channel,
    ];
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({required this.channel});

  final LiveChannel channel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: _ChannelLogo(channel: channel),
      title: Text(channel.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: channel.group == null
          ? null
          : Text(
              channel.group!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
      trailing: const Icon(Broken.play, size: 20),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LivePlayerScreen(channel: channel),
        ),
      ),
    );
  }
}

class _ChannelLogo extends StatelessWidget {
  const _ChannelLogo({required this.channel});

  final LiveChannel channel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = channel.logoUrl;
    final fallback = ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(Broken.video, size: 20, color: theme.disabledColor),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 44,
        height: 44,
        child: url == null || url.isEmpty
            ? fallback
            : Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Téléchargement des chaînes…'),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Broken.video_slash, size: 48, color: theme.disabledColor),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Broken.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoChannelsState extends StatelessWidget {
  const _NoChannelsState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text('Ce fournisseur ne renvoie aucune chaîne.'),
      ),
    );
  }
}

class _NoMatchState extends StatelessWidget {
  const _NoMatchState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text('Aucune chaîne ne correspond.'),
      ),
    );
  }
}
