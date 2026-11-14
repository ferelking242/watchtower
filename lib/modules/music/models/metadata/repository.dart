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

    /// Direct `.smplug` artifact URL. Every plugin of the shared catalogue
    /// lives in one repository, so `repoUrl` no longer identifies a plugin;
    /// this is the URL actually downloaded and the identity used to match an
    /// installed plugin against its catalogue entry.
    String? downloadUrl,
  }) = _MetadataPluginRepository;

  factory MetadataPluginRepository.fromJson(Map<String, dynamic> json) =>
      _$MetadataPluginRepositoryFromJson(json);
}
