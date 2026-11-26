import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:watchtower/modules/music/services/audio_player/audio_player.dart';
import 'package:watchtower/modules/music/services/metadata/errors/exceptions.dart';
import 'package:watchtower/modules/music/services/metadata/metadata.dart';

part 'quality_presets.g.dart';
part 'quality_presets.freezed.dart';

@freezed
class AudioSourcePresetsState with _$AudioSourcePresetsState {
  factory AudioSourcePresetsState({
    @Default([]) final List<SpotubeAudioSourceContainerPreset> presets,
    @Default(0) final int selectedStreamingQualityIndex,
    @Default(0) final int selectedStreamingContainerIndex,
    @Default(0) final int selectedDownloadingQualityIndex,
    @Default(0) final int selectedDownloadingContainerIndex,
  }) = _AudioSourcePresetsState;

  factory AudioSourcePresetsState.fromJson(Map<String, dynamic> json) =>
      _$AudioSourcePresetsStateFromJson(json);
}

/// Containers used when a plugin reports no presets at all.
///
/// A preset is what maps a stream to a URL, so an empty list made every track
/// unplayable. The generic lossy container keeps playback working with the
/// streams the plugin actually returns.
final kFallbackAudioSourcePresets = <SpotubeAudioSourceContainerPreset>[
  SpotubeAudioSourceContainerPreset.lossy(
    type: SpotubeMediaCompressionType.lossy,
    name: 'mp4',
    qualities: [
      SpotubeAudioLossyContainerQuality(bitrate: 320000),
      SpotubeAudioLossyContainerQuality(bitrate: 192000),
      SpotubeAudioLossyContainerQuality(bitrate: 128000),
    ],
  ),
];

/// Keeps the selected container/quality inside the presets the current plugin
/// actually offers. The selection is persisted per plugin, so switching to a
/// plugin with fewer containers (or a plugin update dropping a quality) left an
/// out-of-range index behind and playback threw on the first track.
AudioSourcePresetsState _clampToPresets(AudioSourcePresetsState state) {
  final presets = state.presets;
  if (presets.isEmpty) return state;

  final container =
      state.selectedStreamingContainerIndex.clamp(0, presets.length - 1);
  final quality = presets[container].qualities.isEmpty
      ? 0
      : state.selectedStreamingQualityIndex.clamp(
          0,
          presets[container].qualities.length - 1,
        );
  final downloadContainer =
      state.selectedDownloadingContainerIndex.clamp(0, presets.length - 1);
  final downloadQuality = presets[downloadContainer].qualities.isEmpty
      ? 0
      : state.selectedDownloadingQualityIndex.clamp(
          0,
          presets[downloadContainer].qualities.length - 1,
        );

  if (container == state.selectedStreamingContainerIndex &&
      quality == state.selectedStreamingQualityIndex &&
      downloadContainer == state.selectedDownloadingContainerIndex &&
      downloadQuality == state.selectedDownloadingQualityIndex) {
    return state;
  }

  return state.copyWith(
    selectedStreamingContainerIndex: container,
    selectedStreamingQualityIndex: quality,
    selectedDownloadingContainerIndex: downloadContainer,
    selectedDownloadingQualityIndex: downloadQuality,
  );
}

class AudioSourceAvailableQualityPresetsNotifier
    extends Notifier<AudioSourcePresetsState> {
  @override
  build() {
    final audioSourceSnapshot = ref.watch(audioSourcePluginProvider);
    final audioSourceConfigSnapshot = ref.watch(
      metadataPluginsProvider.select((data) =>
          data.whenData((value) => value.defaultAudioSourcePluginConfig)),
    );

    _initialize(audioSourceSnapshot, audioSourceConfigSnapshot);

    listenSelf((previous, next) {
      final isNewLossless =
          next.presets.elementAtOrNull(next.selectedStreamingContainerIndex)
              is SpotubeAudioSourceContainerPresetLossless;
      final isOldLossless = previous?.presets
              .elementAtOrNull(previous.selectedStreamingContainerIndex)
          is SpotubeAudioSourceContainerPresetLossless;
      if (!isOldLossless && isNewLossless) {
        audioPlayer.setDemuxerBufferSize(6 * 1024 * 1024); // 6MB
      } else if (isOldLossless && !isNewLossless) {
        audioPlayer.setDemuxerBufferSize(4 * 1024 * 1024); // 4MB
      }
    });

    return AudioSourcePresetsState();
  }

  void _initialize(
    AsyncValue<MetadataPlugin?> audioSourceSnapshot,
    AsyncValue<PluginConfiguration?> audioSourceConfigSnapshot,
  ) async {
    audioSourceConfigSnapshot.whenData((audioSourceConfig) {
      audioSourceSnapshot.whenData((audioSource) async {
        if (audioSource == null || audioSourceConfig == null) {
          return;
        }
        final preferences = await SharedPreferences.getInstance();
        final persistedStateStr =
            preferences.getString("audioSourceState-${audioSourceConfig.slug}");

        final reported = audioSource.audioSource.supportedPresets;
        final presets = reported.isEmpty ? kFallbackAudioSourcePresets : reported;

        final restored = persistedStateStr != null
            ? AudioSourcePresetsState.fromJson(jsonDecode(persistedStateStr))
            : AudioSourcePresetsState();

        state = _clampToPresets(restored.copyWith(presets: presets));
      });
    });
  }

  void setSelectedStreamingContainerIndex(int index) {
    state = state.copyWith(
      selectedStreamingContainerIndex: index,
      selectedStreamingQualityIndex:
          0, // Resetting both because it's a different quality
    );
    _updatePreferences();
  }

  void setSelectedStreamingQualityIndex(int index) {
    state = state.copyWith(selectedStreamingQualityIndex: index);
    _updatePreferences();
  }

  void setSelectedDownloadingContainerIndex(int index) {
    state = state.copyWith(
      selectedDownloadingContainerIndex: index,
      selectedDownloadingQualityIndex:
          0, // Resetting both because it's a different quality
    );
    _updatePreferences();
  }

  void setSelectedDownloadingQualityIndex(int index) {
    state = state.copyWith(selectedDownloadingQualityIndex: index);
    _updatePreferences();
  }

  void _updatePreferences() async {
    final audioSourceConfig = await ref.read(metadataPluginsProvider
        .selectAsync((data) => data.defaultAudioSourcePluginConfig));
    if (audioSourceConfig == null) {
      throw MetadataPluginException.noDefaultAudioSourcePlugin();
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      "audioSourceState-${audioSourceConfig.slug}",
      jsonEncode(state),
    );
  }
}

final audioSourcePresetsProvider = NotifierProvider<
    AudioSourceAvailableQualityPresetsNotifier, AudioSourcePresetsState>(
  () => AudioSourceAvailableQualityPresetsNotifier(),
);
