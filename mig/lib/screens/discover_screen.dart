import 'package:flutter/material.dart';
import '../data/catalog.dart';
import '../widgets/poster_card.dart';
import '../widgets/screen_scaffold.dart';
import '../widgets/shimmer_widgets.dart';
import 'detail_screen.dart';

class DiscoverScreen extends StatefulWidget {
  final ValueChanged<MediaItem> onOpen;
  const DiscoverScreen({required this.onOpen, super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  MediaKind _kind = MediaKind.movie;
  bool _loading = false;

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final items = const WatchtowerMetadataProvider().discover(_kind);
    return MigScreenScaffold(
      title: 'Discover',
      actions: [
        IconButton(
          tooltip: 'Refresh fixtures',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Find your next story',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  )),
          const SizedBox(height: 8),
          Text('Movies and series, ready for the Watchtower UI.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 22),
          SegmentedButton<MediaKind>(
            segments: const [
              ButtonSegment(value: MediaKind.movie, label: Text('Movies')),
              ButtonSegment(value: MediaKind.series, label: Text('Series')),
            ],
            selected: {_kind},
            onSelectionChanged: (value) => setState(() => _kind = value.first),
          ),
          const SizedBox(height: 24),
          if (_loading)
            const LoadingPosterRow()
          else
            Wrap(
              spacing: 16,
              runSpacing: 24,
              children: [
                for (final item in items)
                  PosterCard(item: item, onTap: () => widget.onOpen(item)),
              ],
            ),
        ],
      ),
    );
  }
}