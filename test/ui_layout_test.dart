import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/models/ui_layout.dart';

void main() {
  test('keeps the extension section order and presentation metadata', () {
    final layout = UiLayout.fromJson({
      'schemaVersion': 2,
      'home': {
        'sections': [
          {
            'id': 'trending',
            'component': 'grid',
            'title': 'Tendances',
            'columns': 4,
          },
          {
            'id': 'latest',
            'component': 'landscapeStacked',
            'title': 'Nouveautés',
          },
        ],
      },
    });

    expect(layout.schemaVersion, 2);
    expect(layout.home.sections.map((section) => section.id), [
      'trending',
      'latest',
    ]);
    expect(layout.home.sections.first.component, 'grid');
    expect(layout.home.sections.first.columns, 4);
    expect(layout.home.sections.last.component, 'landscapeStacked');
  });

  test('maps declarative components without replacing their section ids', () {
    final section = UiSection.fromJson({
      'id': 'for_you',
      'component': 'compactRow',
      'title': 'Pour vous',
      'accent': 'primary',
      'seeAll': true,
    });

    final legacy = section.toLegacyMap();

    expect(legacy['id'], 'for_you');
    expect(legacy['component'], 'compactRow');
    expect(legacy['layout'], 'compact');
    expect(legacy['name'], 'Pour vous');
    expect(legacy['color'], 'primary');
    expect(legacy['seeAll'], 'for_you');
  });
}