import 'package:watchtower/models/manga.dart';
import 'package:watchtower/services/download_manager/download_settings_service.dart';

/// Decides which download engine to use based on mode settings and URL type.
class EngineSelector {
  static SelectedEngine select({
    required String url,
    required ItemType itemType,
    required DownloadMode mode,
    bool hasFailed = false,
    int retryCount = 0,
  }) {
    switch (mode) {
      case DownloadMode.aria2:
        return SelectedEngine.aria2;
      case DownloadMode.zeus:
        return SelectedEngine.zeus;
      case DownloadMode.external:
        // External hand-off is decided upstream; keep the internal fallback so
        // a caller that reaches the selector still gets a working engine.
        return SelectedEngine.internal;
      case DownloadMode.internalDownloader:
        return SelectedEngine.internal;
    }
  }
}

enum SelectedEngine { internal, aria2, zeus }

extension SelectedEngineExt on SelectedEngine {
  String get badgeLabel {
    switch (this) {
      case SelectedEngine.internal:
        return 'HYDRA';
      case SelectedEngine.aria2:
        return 'ARES';
      case SelectedEngine.zeus:
        return 'ZEUS';
    }
  }

  String get fullName {
    switch (this) {
      case SelectedEngine.internal:
        return 'Hydra Stream';
      case SelectedEngine.aria2:
        return 'Ares Multi';
      case SelectedEngine.zeus:
        return 'ZeusDL';
    }
  }
}
