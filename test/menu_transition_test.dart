import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/router/router.dart';

void main() {
  test('menu destinations cross-fade instead of sliding', () {
    // The dock/menu siblings the user complained about, plus the settings
    // homepage (which otherwise uses the heavy Bare slide).
    expect(
      menuFadeRoutes,
      containsAll([
        'settings',
        'statistics',
        'downloadQueue',
        'history',
        'updates',
        'notifications',
        'browse',
        'marketplace',
        'schedule',
        'liveTv',
      ]),
    );
    // A tab is not a menu destination: it keeps its instant switch.
    expect(menuFadeRoutes, isNot(contains('WatchtowerHome')));
  });

  test('menuFadePage fades the child in and out', () {
    final page = menuFadePage(
      key: const ValueKey('page'),
      child: const SizedBox(key: Key('child')),
    );
    expect(page.transitionDuration, menuFadeDuration);
    expect(page.reverseTransitionDuration, menuFadeDuration);

    final faded = page.transitionsBuilder(
      _FakeBuildContext(),
      const AlwaysStoppedAnimation<double>(1),
      const AlwaysStoppedAnimation<double>(0),
      const SizedBox(key: Key('child')),
    );
    expect(faded, isA<FadeTransition>());
    expect((faded as FadeTransition).opacity.value, 1);
  });
}

/// The transitions builder only forwards the context to the child; a bare
/// instance is enough to exercise it without pumping a widget tree.
class _FakeBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
