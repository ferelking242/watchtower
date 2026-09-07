import 'package:flutter/material.dart';
import 'package:watchtower/modules/music/modules/player/sibling_tracks_sheet.dart';

class PlayerTrackSourcesPage extends StatelessWidget {
  const PlayerTrackSourcesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SiblingTracksSheet(floating: false),
    );
  }
}
