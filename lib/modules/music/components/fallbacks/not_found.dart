import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/modules/media/app_ui_components.dart';
import 'package:watchtower/modules/music/extensions/context.dart';

/// Empty-result state for the music module, rendered with the shared
/// [AppEmptyState] so it matches the movie/series/manga empty screens.
class NotFound extends StatelessWidget {
  const NotFound({super.key});

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Broken.music_square_remove,
      title: context.l10n.nothing_found,
      message: context.l10n.search_to_get_results,
    );
  }
}
