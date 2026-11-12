import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/modules/manga/reader/mixins/reader_gestures.dart';

/// Counters recording which reader action a key triggered.
class _Calls {
  int previousPage = 0;
  int nextPage = 0;
  int previousChapter = 0;
  int nextChapter = 0;
  int escape = 0;
  int fullScreen = 0;

  ReaderKeyboardHandler handler({bool reverse = false}) => ReaderKeyboardHandler(
    onPreviousPage: () => previousPage++,
    onNextPage: () => nextPage++,
    onPreviousChapter: () => previousChapter++,
    onNextChapter: () => nextChapter++,
    onEscape: () => escape++,
    onFullScreen: () => fullScreen++,
  );
}

// The handler switches on the logical key only; a placeholder physical key is
// enough to build the event.
KeyDownEvent _key(LogicalKeyboardKey key) => KeyDownEvent(
  physicalKey: const PhysicalKeyboardKey(0x00000000),
  logicalKey: key,
  timeStamp: Duration.zero,
);

void main() {
  group('ReaderKeyboardHandler', () {
    test('arrow keys step pages and honour the reverse-horizontal flag', () {
      final calls = _Calls();
      final handler = calls.handler();
      expect(handler.handleKeyEvent(_key(LogicalKeyboardKey.arrowDown)), isTrue);
      expect(handler.handleKeyEvent(_key(LogicalKeyboardKey.arrowLeft)), isTrue);
      expect(handler.handleKeyEvent(_key(LogicalKeyboardKey.arrowRight)), isTrue);
      expect(calls.nextPage, 2); // down + right
      expect(calls.previousPage, 1); // left
    });

    test('reverse-horizontal swaps the left/right page actions', () {
      final calls = _Calls();
      final handler = calls.handler(reverse: true);
      handler.handleKeyEvent(_key(LogicalKeyboardKey.arrowLeft));
      handler.handleKeyEvent(_key(LogicalKeyboardKey.arrowRight));
      expect(calls.nextPage, 1);
      expect(calls.previousPage, 1);
    });

    test('N/P and PageDown/PageUp move chapters, Escape and F11 are handled', () {
      final calls = _Calls();
      final handler = calls.handler();
      handler.handleKeyEvent(_key(LogicalKeyboardKey.keyN));
      handler.handleKeyEvent(_key(LogicalKeyboardKey.pageUp));
      handler.handleKeyEvent(_key(LogicalKeyboardKey.escape));
      handler.handleKeyEvent(_key(LogicalKeyboardKey.f11));
      expect(calls.nextChapter, 1);
      expect(calls.previousChapter, 1);
      expect(calls.escape, 1);
      expect(calls.fullScreen, 1);
    });

    test('key-up events are ignored so a held key fires once per press', () {
      final calls = _Calls();
      final handler = calls.handler();
      final up = KeyUpEvent(
        physicalKey: const PhysicalKeyboardKey(0x00000000),
        logicalKey: LogicalKeyboardKey.arrowDown,
        timeStamp: Duration.zero,
      );
      expect(handler.handleKeyEvent(up), isFalse);
      expect(calls.nextPage, 0);
    });

    test('an unmapped key is not swallowed', () {
      final handler = _Calls().handler();
      expect(handler.handleKeyEvent(_key(LogicalKeyboardKey.keyZ)), isFalse);
    });
  });

  testWidgets('wrapWithKeyboardListener keeps one focus node across rebuilds', (
    tester,
  ) async {
    final calls = _Calls();
    final handler = calls.handler();
    // Owned by the caller (in the real reader it lives in the State), so the
    // same node must be reused frame after frame instead of leaking a new one.
    final node = FocusNode(debugLabel: 'test-reader');
    addTearDown(node.dispose);

    Widget build() => MaterialApp(
      home: handler.wrapWithKeyboardListener(
        focusNode: node,
        child: const SizedBox.expand(),
      ),
    );

    await tester.pumpWidget(build());
    await tester.pumpWidget(build());
    await tester.pump();

    expect(node.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(calls.nextPage, 1);
  });
}
