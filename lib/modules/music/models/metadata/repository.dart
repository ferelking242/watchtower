part of './metadata.dart';

@freezed
class MetadataPluginRepository with _$MetadataPluginRepository {
  factory MetadataPluginRepository({
    required String name,
    required String owner,
    required String description,
    required String repoUrl,
    required List<String> topics,

    /// Repository-hosted icon published by the extensions catalogue. Null when
    /// the catalogue does not ship one, in which case the UI falls back to a
    /// generated placeholder.
    String? iconUrl,
  }) = _MetadataPluginRepository;

  factory MetadataPluginRepository.fromJson(Map<String, dynamic> json) =>
      _$MetadataPluginRepositoryFromJson(json);
}
