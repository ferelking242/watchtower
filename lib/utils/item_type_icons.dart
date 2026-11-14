import 'package:flutter/widgets.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/models/manga.dart';

/// Canonical Broken icon for an [ItemType].
///
/// This is the icon set used by the History page tabs. Every surface that
/// shows a per-type icon (Explorer title, Explorer tabs, History, local
/// source, Updates, …) must resolve it through this helper so the icons stay
/// identical everywhere.
IconData itemTypeIcon(ItemType type) {
  switch (type) {
    case ItemType.anime:
      return Broken.video_play;
    case ItemType.manga:
      return Broken.note;
    case ItemType.novel:
      return Broken.book;
    case ItemType.music:
      return Broken.music_play;
    case ItemType.game:
      return Broken.gameboy;
    case ItemType.plugin:
      return Broken.element_plus;
  }
}
