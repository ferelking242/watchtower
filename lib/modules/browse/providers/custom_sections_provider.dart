import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

const _kBox = 'ui_prefs';
const _kKey = 'browse_custom_sections';

Box? get _box => Hive.isBoxOpen(_kBox) ? Hive.box(_kBox) : null;

/// A user-created shelf in the Explorer source list.
///
/// Pinning answers "which extensions do I open most often"; a section answers
/// "which extensions belong together" — e.g. a "Hentai" section holding every
/// adult extension. An extension can live in any number of sections, so
/// [sourceIds] is a plain membership list.
class CustomSection {
  final String id;
  String name;
  final Set<int> sourceIds;

  CustomSection({
    required this.id,
    required this.name,
    Set<int>? sourceIds,
  }) : sourceIds = sourceIds ?? <int>{};

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sourceIds': sourceIds.toList(),
      };

  static CustomSection fromJson(Map<String, dynamic> json) => CustomSection(
        id: json['id'] as String? ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        name: json['name'] as String? ?? 'Section',
        sourceIds: (json['sourceIds'] as List<dynamic>?)
                ?.whereType<num>()
                .map((e) => e.toInt())
                .toSet() ??
            <int>{},
      );
}

class CustomSectionsNotifier extends Notifier<List<CustomSection>> {
  @override
  List<CustomSection> build() {
    final raw = _box?.get(_kKey);
    if (raw is! String || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(CustomSection.fromJson)
          .toList();
    } catch (_) {
      // A malformed blob must never take the Explorer down: start empty.
      return const [];
    }
  }

  void _persist() {
    _box?.put(
      _kKey,
      jsonEncode(state.map((section) => section.toJson()).toList()),
    );
  }

  /// Creates a section and returns it so the caller can open it immediately.
  CustomSection create(String name) {
    final section = CustomSection(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim().isEmpty ? 'Section' : name.trim(),
    );
    state = [...state, section];
    _persist();
    return section;
  }

  void rename(String id, String name) {
    state = [
      for (final section in state)
        if (section.id == id)
          CustomSection(
            id: section.id,
            name: name.trim().isEmpty ? section.name : name.trim(),
            sourceIds: section.sourceIds,
          )
        else
          section,
    ];
    _persist();
  }

  void remove(String id) {
    state = state.where((section) => section.id != id).toList();
    _persist();
  }

  /// Adds [sourceId] to the section, or removes it when already a member.
  void toggleSource(String sectionId, int sourceId) {
    state = [
      for (final section in state)
        if (section.id == sectionId)
          CustomSection(
            id: section.id,
            name: section.name,
            sourceIds: () {
              final next = {...section.sourceIds};
              if (!next.add(sourceId)) next.remove(sourceId);
              return next;
            }(),
          )
        else
          section,
    ];
    _persist();
  }
}

final customSectionsProvider =
    NotifierProvider<CustomSectionsNotifier, List<CustomSection>>(
  CustomSectionsNotifier.new,
);
