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
}
