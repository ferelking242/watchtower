import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class CategoryMeta {
  final int? iconCodePoint;
  final String? description;

  const CategoryMeta({this.iconCodePoint, this.description});

  factory CategoryMeta.fromJson(Map<String, dynamic> json) => CategoryMeta(
    iconCodePoint: json['iconCodePoint'] as int?,
    description: json['description'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'iconCodePoint': iconCodePoint,
    'description': description,
  };

  CategoryMeta copyWith({int? iconCodePoint, String? description}) => CategoryMeta(
    iconCodePoint: iconCodePoint ?? this.iconCodePoint,
    description: description ?? this.description,
  );
}

class CategoryMetadataNotifier extends Notifier<Map<int, CategoryMeta>> {
  static const _fileName = 'category_meta.json';

  @override
  Map<int, CategoryMeta> build() {
    _load();
    return {};
  }

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _fileName));
  }

  Future<void> _load() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final raw = await file.readAsString();
        final json = jsonDecode(raw) as Map<String, dynamic>;
        state = json.map(
          (k, v) => MapEntry(int.parse(k), CategoryMeta.fromJson(v as Map<String, dynamic>)),
        );
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final file = await _getFile();
      final json = state.map((k, v) => MapEntry(k.toString(), v.toJson()));
      await file.writeAsString(jsonEncode(json));
    } catch (_) {}
  }

  Future<void> set(int categoryId, CategoryMeta meta) async {
    state = {...state, categoryId: meta};
    await _save();
  }

  Future<void> remove(int categoryId) async {
    final newState = Map<int, CategoryMeta>.from(state)..remove(categoryId);
    state = newState;
    await _save();
  }

  CategoryMeta? get(int categoryId) => state[categoryId];
}

final categoryMetadataProvider =
    NotifierProvider<CategoryMetadataNotifier, Map<int, CategoryMeta>>(
  CategoryMetadataNotifier.new,
);
