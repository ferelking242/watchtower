import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/models/gallery_component_catalog.dart';
import 'package:watchtower/models/gallery_component_palette.dart';

void main() {
  test('the manga home stack is the single source of truth', () {
    final presets = GalleryComponentPalette.mangaHomeStack;
    expect(presets, isNotEmpty);

    final ids = <String>{};
    for (final preset in presets) {
      expect(
        ids.add(preset.id),
        isTrue,
        reason: 'duplicate section id ${preset.id}',
      );
      expect(
        GalleryComponentCatalog.resolve(preset.component),
        isNotNull,
        reason: '${preset.component} must resolve to a gallery component',
      );
    }
  });

  test('buildSections preserves ids, components, titles and params', () {
    final sections = GalleryComponentPalette.buildSections(
      GalleryComponentPalette.mangaHomeStack,
    );
    expect(sections.length, GalleryComponentPalette.mangaHomeStack.length);
    for (var i = 0; i < sections.length; i++) {
      final preset = GalleryComponentPalette.mangaHomeStack[i];
      expect(sections[i].id, preset.id);
      expect(sections[i].component, preset.component);
      expect(sections[i].title, preset.title);
      expect(sections[i].params, preset.params);
    }
  });
}
