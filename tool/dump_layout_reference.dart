// Dumps the layout component catalogue and its parameter palette as JSON.
//
// The website build reads the result to generate the `layout-json` reference
// and the `layout-components` id list, so the published documentation can never
// drift from the Dart registry. Regenerate with:
//
//   dart run tool/dump_layout_reference.dart > layout-reference.json
//
// See watchtower-website/scripts/generate-layout-docs.mjs.
import 'dart:convert';

import 'package:watchtower/models/gallery_component_catalog.dart';
import 'package:watchtower/models/gallery_component_palette.dart';

Map<String, Object?> _parameter(GalleryComponentParameter p) => {
  'key': p.key,
  'label': p.label,
  'type': p.typeName,
  'kind': p.kind.name,
  'default': p.effectiveDefault,
  'aliases': p.aliases,
  'description': p.description,
  'example': p.example,
  'group': p.group.name,
};

void main() {
  final categories = <String, List<String>>{};
  final aliases = <String, List<String>>{};
  for (final d in GalleryComponentCatalog.descriptors) {
    categories.putIfAbsent(d.category, () => []).add(d.id);
    if (d.aliases.isNotEmpty) aliases[d.id] = d.aliases;
  }

  final families = <String, Object?>{};
  for (final family in GalleryComponentFamily.values) {
    families[family.name] = [
      for (final p in GalleryComponentPalette.forFamily(family)) _parameter(p),
    ];
  }

  final components = [
    for (final d in GalleryComponentCatalog.descriptors)
      {
        'id': d.id,
        'className': d.className,
        'label': d.label,
        'category': d.category,
        'description': d.description,
        'family': d.renderer.name,
        'selectable': d.selectable,
        'aliases': d.aliases,
      },
  ];

  final payload = {
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'idCount': GalleryComponentCatalog.descriptors.length,
    'aliasCount': aliases.values.fold<int>(0, (n, a) => n + a.length),
    'categories': [
      for (final entry in categories.entries)
        {'name': entry.key, 'ids': entry.value},
    ],
    'aliases': aliases,
    'components': components,
    'commonParams': [
      for (final p in GalleryComponentPalette.common) _parameter(p),
    ],
    'familyParams': families,
  };

  const encoder = JsonEncoder.withIndent('  ');
  print(encoder.convert(payload));
}
