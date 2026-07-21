import 'package:riverpod/riverpod.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/audio_source/quality_presets.dart';

final audioSourceQualityLabelProvider = Provider<String>((ref) {
  final sourceQuality = ref.watch(audioSourcePresetsProvider);
  final sourceContainer = sourceQuality.presets
      .elementAtOrNull(sourceQuality.selectedStreamingContainerIndex);
  final quality = sourceContainer?.qualities
      .elementAtOrNull(sourceQuality.selectedStreamingQualityIndex);

  return "${sourceContainer?.name ?? "Unknown"} • ${quality?.toString() ?? "Unknown"}";
});
