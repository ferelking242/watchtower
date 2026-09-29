import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/models/manga.dart';

extension ItemTypeLocalization on ItemType {
  String localized(AppLocalizations l10n) {
    switch (this) {
      case ItemType.manga:
        return l10n.manga;
      case ItemType.anime:
        return l10n.watch;
      case ItemType.novel:
        return l10n.novel;
      case ItemType.music:
        return 'Music';
      case ItemType.game:
        return 'Games';
      case ItemType.plugin:
        return 'Plugins';
    }
  }

  String localizedSources(AppLocalizations l10n) {
    switch (this) {
      case ItemType.manga:
        return l10n.manga_sources;
      case ItemType.anime:
        return l10n.anime_sources;
      case ItemType.novel:
        return l10n.novel_sources;
      case ItemType.music:
        return 'Music sources';
      case ItemType.game:
        return 'Game sources';
      case ItemType.plugin:
        return 'Plugin sources';
    }
  }

  String localizedExtensions(AppLocalizations l10n) {
    switch (this) {
      case ItemType.manga:
        return l10n.manga_extensions;
      case ItemType.anime:
        return l10n.anime_extensions;
      case ItemType.novel:
        return l10n.novel_extensions;
      case ItemType.music:
        return 'Music extensions';
      case ItemType.game:
        return 'Game extensions';
      case ItemType.plugin:
        return 'Plugin extensions';
    }
  }
}
