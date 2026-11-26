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
  int volumeUp = 0;
  int volumeDown = 0;

  ReaderKeyboardHandler handler({bool reverse = false}) => ReaderKeyboardHandler(
    onPreviousPage: () => previousPage++,
    onNextPage: () => nextPage++,
    onPreviousChapter: () => previousChapter++,
    onNextChapter: () => nextChapter++,
    onEscape: () => escape++,
    onFullScreen: () => fullScreen++,
    onVolumeUp: () => volumeUp++,
    onVolumeDown: () => volumeDown++,
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

    test('volume keys turn pages when no native interception is available', () {
      final calls = _Calls();
      final handler = calls.handler();
      expect(
        handler.handleKeyEvent(_key(LogicalKeyboardKey.audioVolumeUp)),
        isTrue,
      );
      expect(
        handler.handleKeyEvent(_key(LogicalKeyboardKey.audioVolumeDown)),
        isTrue,
      );
      expect(calls.volumeUp, 1);
      expect(calls.volumeDown, 1);
    });

    test('volume keys stay untouched when the reader did not opt in', () {
      // Without callbacks the key must not be claimed, otherwise the system
      // volume would stop working for a reader that never asked for it.
      final handler = ReaderKeyboardHandler();
      expect(
        handler.handleKeyEvent(_key(LogicalKeyboardKey.audioVolumeUp)),
        isFalse,
      );
      expect(
        handler.handleKeyEvent(_key(LogicalKeyboardKey.audioVolumeDown)),
        isFalse,
      );
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

  testWidgets('a volume key is claimed so the system volume does not move', (
    tester,
  ) async {
    final calls = _Calls();
    final handler = calls.handler();
    final node = FocusNode(debugLabel: 'test-reader-volume');
    addTearDown(node.dispose);

    // The reader claims volume keys through a global handler, not the focus
    // tree: a focus node only sees keys while it holds focus, and an unclaimed
    // key is redispatched to the platform, which raises the volume.
    bool claim(KeyEvent event) => handler.claimVolumeKeyEvent(event);
    HardwareKeyboard.instance.addHandler(claim);
    addTearDown(() => HardwareKeyboard.instance.removeHandler(claim));

    await tester.pumpWidget(
      MaterialApp(
        home: handler.wrapWithKeyboardListener(
          focusNode: node,
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();

    // `sendKeyEvent` reports whether the framework claimed the event. Only a
    // claimed event stops Android from raising the volume, so this assertion is
    // the actual fix: a callback that fires but returns "ignored" would still
    // let the system volume move.
    expect(
      await tester.sendKeyEvent(LogicalKeyboardKey.audioVolumeUp),
      isTrue,
      reason: 'an unclaimed volume key falls through to the system volume',
    );
    expect(
      await tester.sendKeyEvent(LogicalKeyboardKey.audioVolumeDown),
      isTrue,
    );
    await tester.pump();

    expect(calls.volumeUp, 1);
    expect(calls.volumeDown, 1);
  });

  testWidgets('the focus path does not turn the page a second time', (
    tester,
  ) async {
    final calls = _Calls();
    final handler = calls.handler();
    final node = FocusNode(debugLabel: 'test-reader-volume-double');
    addTearDown(node.dispose);

    bool claim(KeyEvent event) => handler.claimVolumeKeyEvent(event);
    HardwareKeyboard.instance.addHandler(claim);
    addTearDown(() => HardwareKeyboard.instance.removeHandler(claim));

    await tester.pumpWidget(
      MaterialApp(
        home: handler.wrapWithKeyboardListener(
          focusNode: node,
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();
    expect(node.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.audioVolumeUp);
    await tester.pump();

    // Both HardwareKeyboard handlers and the focus tree receive every event.
    // Handling volume keys in both places turned the page twice per press.
    expect(calls.volumeUp, 1);
  });

  testWidgets('a locked reader claims volume keys without turning the page', (
    tester,
  ) async {
    final calls = _Calls();
    final handler = calls.handler();
    final node = FocusNode(debugLabel: 'test-reader-volume-locked');
    addTearDown(node.dispose);

    // Mirrors `_claimVolumeKey` in the reader while `_isLocked` is true.
    bool claim(KeyEvent event) => handler.claimsVolumeKey(event);
    HardwareKeyboard.instance.addHandler(claim);
    addTearDown(() => HardwareKeyboard.instance.removeHandler(claim));

    await tester.pumpWidget(
      MaterialApp(
        home: handler.wrapWithKeyboardListener(
          focusNode: node,
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();

    // Still claimed, so the system volume does not move behind the lock.
    expect(
      await tester.sendKeyEvent(LogicalKeyboardKey.audioVolumeUp),
      isTrue,
    );
    await tester.pump();
    expect(calls.volumeUp, 0);
  });
}
