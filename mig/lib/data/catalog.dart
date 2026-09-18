import 'package:flutter/material.dart';

enum MediaKind { movie, series }

class MediaItem {
  final String title;
  final String subtitle;
  final String description;
  final String year;
  final MediaKind kind;
  final Color color;
  final List<String> cast;

  const MediaItem({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.year,
    required this.kind,
    required this.color,
    required this.cast,
  });
}

/// Fixture-backed provider for the standalone migration preview.
///
/// The production integration point remains Watchtower's existing data and
/// metadata providers. No network, Firebase, auth, ads or player is needed
/// to validate the screen composition.
class WatchtowerMetadataProvider {
  const WatchtowerMetadataProvider();

  List<MediaItem> discover(MediaKind kind) =>
      catalog.where((item) => item.kind == kind).toList();

  List<MediaItem> search(String query) {
    final value = query.trim().toLowerCase();
    if (value.isEmpty) return catalog;
    return catalog
        .where((item) =>
            item.title.toLowerCase().contains(value) ||
            item.subtitle.toLowerCase().contains(value))
        .toList();
  }
}

const catalog = <MediaItem>[
  MediaItem(
    title: 'The Last Signal',
    subtitle: 'A mystery beyond the stars',
    description:
        'A quiet astronaut discovers a signal that changes the course of a missing expedition.',
    year: '2025',
    kind: MediaKind.movie,
    color: Color(0xFF6B4F9B),
    cast: ['Maya Stone', 'Noah Reed', 'Elena Park'],
  ),
  MediaItem(
    title: 'Neon Harbor',
    subtitle: 'Every secret has a tide',
    description:
        'A detective returns to the harbor where she grew up to solve a case tied to her family.',
    year: '2024',
    kind: MediaKind.movie,
    color: Color(0xFF0D6E83),
    cast: ['Ari Cole', 'Jon Bell', 'Sofia Lane'],
  ),
  MediaItem(
    title: 'Northbound',
    subtitle: 'The journey starts here',
    description:
        'Three friends leave their hometown and find a new version of themselves on the road.',
    year: '2023',
    kind: MediaKind.movie,
    color: Color(0xFFB46A3C),
    cast: ['Lina Gray', 'Sam West', 'Owen Hart'],
  ),
  MediaItem(
    title: 'Afterlight',
    subtitle: 'A city built on memories',
    description:
        'In a city where memories can be traded, one archivist risks everything to recover her past.',
    year: '2025',
    kind: MediaKind.series,
    color: Color(0xFF8B426A),
    cast: ['Nia James', 'Theo Ward', 'Luca Miles'],
  ),
  MediaItem(
    title: 'The Quiet District',
    subtitle: 'Nothing stays hidden',
    description:
        'A slow-burn crime series about a neighborhood that protects its own at any cost.',
    year: '2024',
    kind: MediaKind.series,
    color: Color(0xFF4B657A),
    cast: ['Mara King', 'Eli Ross', 'June Avery'],
  ),
  MediaItem(
    title: 'Orbit School',
    subtitle: 'Learn to reach farther',
    description:
        'Young pilots train on a remote station while a storm closes in around them.',
    year: '2022',
    kind: MediaKind.series,
    color: Color(0xFFB08135),
    cast: ['Iris Moon', 'Kian Holt', 'Rhea West'],
  ),
];

const profileSections = [
  ('Account', Icons.person_outline),
  ('About Watchtower', Icons.info_outline),
  ('Server status', Icons.cloud_done_outlined),
  ('Check for updates', Icons.system_update_outlined),
  ('Language and appearance', Icons.palette_outlined),
];