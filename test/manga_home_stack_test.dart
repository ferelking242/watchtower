import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/models/gallery_component_palette.dart';
import 'package:watchtower/models/layout_component_registry.dart';

void main() {
  test('the manga home stack is the single source of truth', () {
    final presets = GalleryComponentPalette.mangaHomeStack;
    expect(presets, isNotEmpty);

    // The stack opens with the shared spotlight, the same hero every
    // extension layout must start with, so a source without its own layout
    // still gets the production home instead of a source-specific mock.
    expect(presets.first.component, 'spotlight');

    final ids = <String>{};
    for (final preset in presets) {
      expect(
        ids.add(preset.id),
        isTrue,
        reason: 'duplicate section id ${preset.id}',
      );
      expect(
        LayoutComponentRegistry.resolve(preset.component),
        isNotNull,
        reason: '${preset.component} must resolve to a layout component',
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
