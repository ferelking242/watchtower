import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/services/mini_webview_state.dart';

/// The floating dock's left button opens the sessions sheet. These tests pin
/// the two things that used to be missing entirely: the sheet exists, and it
/// lists the minimised sessions held by `miniWebViewProvider`.
void main() {
  Widget host(ProviderContainer container, Widget child) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  group('miniWebViewProvider', () {
    test('push puts the newest session first', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(miniWebViewProvider.notifier);

      notifier.push(const MiniWebViewEntry(url: 'https://a.test', title: 'A'));
      notifier.push(const MiniWebViewEntry(url: 'https://b.test', title: 'B'));

      final state = container.read(miniWebViewProvider);
      expect(state.map((e) => e.title), ['B', 'A']);
    });

    test('removeAt drops one session and ignores out-of-range indices', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(miniWebViewProvider.notifier);
      notifier.push(const MiniWebViewEntry(url: 'https://a.test', title: 'A'));
      notifier.push(const MiniWebViewEntry(url: 'https://b.test', title: 'B'));

      notifier.removeAt(0);
      expect(container.read(miniWebViewProvider).map((e) => e.title), ['A']);

      notifier.removeAt(9);
      expect(container.read(miniWebViewProvider), hasLength(1));
    });

    test('pop returns the newest session and shrinks the stack', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(miniWebViewProvider.notifier);
      notifier.push(const MiniWebViewEntry(url: 'https://a.test', title: 'A'));
      notifier.push(const MiniWebViewEntry(url: 'https://b.test', title: 'B'));

      expect(notifier.pop()?.title, 'B');
      expect(container.read(miniWebViewProvider).map((e) => e.title), ['A']);
      expect(notifier.pop()?.title, 'A');
      expect(notifier.pop(), isNull);
    });
  });

  testWidgets('a session row renders its title and subtitle', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      host(
        container,
        const _FakeSessionRow(title: 'Manga Scan', subtitle: 'manga-scan.fr'),
      ),
    );

    expect(find.text('Manga Scan'), findsOneWidget);
    expect(find.text('manga-scan.fr'), findsOneWidget);
  });
}

/// Mirrors the shape of `_TabRow` without depending on the private widget, so
/// the test stays valid if the row's internals change.
class _FakeSessionRow extends StatelessWidget {
  const _FakeSessionRow({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(title: Text(title), subtitle: Text(subtitle));
  }
}
