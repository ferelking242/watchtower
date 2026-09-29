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
    if (mode == DownloadMode.aria2) {
      return SelectedEngine.aria2;
    }

    // internalDownloader: always use internal HLS
    return SelectedEngine.internal;
  }
}

enum SelectedEngine { internal, aria2 }

extension SelectedEngineExt on SelectedEngine {
  String get badgeLabel {
    switch (this) {
      case SelectedEngine.internal:
        return 'HYDRA';
      case SelectedEngine.aria2:
        return 'ARES';
    }
  }

  String get fullName {
    switch (this) {
      case SelectedEngine.internal:
        return 'Hydra Stream';
      case SelectedEngine.aria2:
        return 'Ares Multi';
    }
  }
}
