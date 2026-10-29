import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/modules/widgets/offline_content_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('identifies offline and empty network responses', () {
    expect(
      isOfflineContentError(
        FormatException('SyntaxError: Unexpected end of JSON input'),
      ),
      isTrue,
    );
    expect(
      isOfflineContentError(Exception('SocketException: Failed host lookup')),
      isTrue,
    );
    expect(
      isOfflineContentError(FormatException('Unexpected response format')),
      isFalse,
    );
  });

  testWidgets('renders the bundled offline animation', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: OfflineContentState()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Pas de connexion Internet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the network button and an optional retry action', (
    tester,
  ) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OfflineContentState(
            title: 'Aucune connexion réseau',
            message: 'Connectez-vous pour charger le catalogue.',
            onRetry: () => retried = true,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Aucune connexion réseau'), findsOneWidget);
    expect(
      find.text('Connectez-vous pour charger le catalogue.'),
      findsOneWidget,
    );
    // The network button is always offered so the state is never a dead end.
    expect(find.widgetWithText(FilledButton, 'Activer le réseau'), findsOneWidget);

    await tester.tap(find.text('Réessayer'));
    await tester.pump();
    expect(retried, isTrue);
  });

  testWidgets('hides the retry button when no callback is supplied', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: OfflineContentState()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Réessayer'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Activer le réseau'), findsOneWidget);
  });
}
