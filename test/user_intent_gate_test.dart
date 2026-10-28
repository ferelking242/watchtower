import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/services/user_intent_gate.dart';

/// The interceptor must stay inert until the user actually touches the page.
/// These tests pin the two failure modes that mattered: hijacking a media URL
/// the page fetched on its own, and never letting a genuine tap through.
void main() {
  group('UserIntentGate', () {
    test('is inert before any gesture', () {
      expect(UserIntentGate().hasIntent, isFalse);
    });

    test('a gesture opens the gate for the whole window', () {
      final gate = UserIntentGate(window: const Duration(seconds: 15));
      gate.markIntent();
      expect(gate.hasIntent, isTrue);
    });

    test('a stale gesture does not authorise interception', () {
      final gate = UserIntentGate(window: const Duration(milliseconds: 1));
      gate.markIntent();
      // Busy-wait past the window without relying on timers.
      final deadline = DateTime.now().add(const Duration(milliseconds: 5));
      while (DateTime.now().isBefore(deadline)) {}
      expect(gate.hasIntent, isFalse);
    });

    test('reset closes the gate', () {
      final gate = UserIntentGate();
      gate.markIntent();
      expect(gate.hasIntent, isTrue);
      gate.reset();
      expect(gate.hasIntent, isFalse);
    });

    test('a fresh gesture re-opens a closed gate', () {
      final gate = UserIntentGate(window: const Duration(milliseconds: 1));
      gate.markIntent();
      final deadline = DateTime.now().add(const Duration(milliseconds: 5));
      while (DateTime.now().isBefore(deadline)) {}
      expect(gate.hasIntent, isFalse);

      gate.markIntent();
      expect(gate.hasIntent, isTrue);
    });

    test('default window is 15 seconds', () {
      expect(UserIntentGate().window, const Duration(seconds: 15));
    });
  });
}
