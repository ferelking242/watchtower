import 'package:flutter/material.dart';
import '../data/catalog.dart';
import '../widgets/poster_card.dart';

class DetailScreen extends StatelessWidget {
  final MediaItem item;
  final ValueChanged<String> onPerson;

  const DetailScreen({required this.item, required this.onPerson, super.key});

  @override
  Widget build(BuildContext context) {
    final isSeries = item.kind == MediaKind.series;
    return Scaffold(
      appBar: AppBar(title: Text(item.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          AspectRatio(
            aspectRatio: 1.5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: [item.color, item.color.withValues(alpha: .24)],
                ),
              ),
              child: Center(
                child: Icon(
                  isSeries ? Icons.live_tv_outlined : Icons.movie_outlined,
                  size: 72,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(item.title,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('${item.year}  ·  ${isSeries ? 'Series' : 'Movie'}  ·  4K',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Playback is intentionally excluded from this preview.'))),
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Preview details'),
          ),
          const SizedBox(height: 22),
          Text(item.description, style: const TextStyle(height: 1.5)),
          const SizedBox(height: 24),
          if (isSeries) ...[
            Text('Seasons',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            const _InfoTile(title: 'Season 1', value: '8 episodes'),
            const _InfoTile(title: 'Season 2', value: '6 episodes'),
          ],
          const SizedBox(height: 22),
          Text('Cast',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          for (final person in item.cast)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: item.color.withValues(alpha: .28),
                child: Text(person.substring(0, 1)),
              ),
              title: Text(person),
              subtitle: const Text('Actor / person detail'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onPerson(person),
            ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String title;
  final String value;
  const _InfoTile({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.video_library_outlined),
        title: Text(title),
        trailing: Text(value),
      ),
    );
  }
}