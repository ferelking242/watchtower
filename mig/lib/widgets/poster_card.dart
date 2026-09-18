import 'package:flutter/material.dart';
import '../data/catalog.dart';

class PosterCard extends StatelessWidget {
  final MediaItem item;
  final VoidCallback? onTap;

  const PosterCard({required this.item, this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: .72,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [item.color, item.color.withValues(alpha: .32)],
                  ),
                ),
                child: Stack(
                  children: [
                    const Positioned(
                      top: 14,
                      left: 14,
                      child: Icon(Icons.movie_outlined,
                          color: Colors.white70, size: 28),
                    ),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 16,
                      child: Text(
                        item.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          height: 1.05,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 9),
            Text(item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text('${item.year} · ${item.kind == MediaKind.movie ? 'Movie' : 'Series'}',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }
}