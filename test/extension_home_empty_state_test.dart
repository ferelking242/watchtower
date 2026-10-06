import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/modules/watch/home/extension_home_empty_state.dart';

void main() {
  testWidgets('shows the source header and retries from the empty state', (
    tester,
  ) async {
    var retries = 0;
    var refreshes = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ExtensionHomeEmptyState(
          onRetry: () async {
            retries++;
          },
          onRefresh: () async {
            refreshes++;
          },
          header: const Text('Extension source header'),
        ),
      ),
    );

    expect(find.text('Extension source header'), findsOneWidget);
    expect(find.byTooltip('Rechercher'), findsNothing);
    expect(
      find.byKey(const ValueKey('extension-empty-lottie')),
      findsOneWidget,
    );
    expect(find.text('Aucun contenu disponible'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
    expect(find.text('Tirer vers le bas pour actualiser'), findsOneWidget);

    await tester.tap(find.text('Réessayer'));
    await tester.pump();

    expect(retries, 1);
    expect(refreshes, 0);
  });

  testWidgets('pull-to-refresh invokes the supplied refresh callback', (
    tester,
  ) async {
    var refreshes = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ExtensionHomeEmptyState(
          onRetry: () async {},
          onRefresh: () async {
            refreshes++;
          },
          header: const SizedBox.shrink(),
        ),
      ),
    );

    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 360));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(refreshes, 1);
  });

  testWidgets('does not auto-open the source homepage for a vague CF error', (
    tester,
  ) async {
    expect(
      extensionErrorIsCloudflareChallenge(
        Exception('HTTP 403 blocked by Cloudflare challenge'),
      ),
      isFalse,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ExtensionHomeEmptyState(
          onRetry: () async {},
          onRefresh: () async {},
          header: const SizedBox.shrink(),
          manualCheckUrl: 'https://source.example/',
          error: Exception('HTTP 403 blocked by Cloudflare challenge'),
        ),
      ),
    );

    expect(find.text('Impossible de charger le contenu'), findsOneWidget);
    expect(find.text('Challenge Cloudflare'), findsNothing);
    expect(find.text('Vérifier l’accès à la source'), findsOneWidget);
  });

  testWidgets('requires an explicit tap when only an error message is known', (
    tester,
  ) async {
    final error = Exception('Cloudflare: Just a moment... Checking your browser');
    expect(extensionErrorIsCloudflareChallenge(error), isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: ExtensionHomeEmptyState(
          onRetry: () async {},
          onRefresh: () async {},
          header: const SizedBox.shrink(),
          manualCheckUrl: 'https://source.example/',
          error: error,
        ),
      ),
    );

    expect(find.text('Vérification Cloudflare requise'), findsOneWidget);
    expect(find.text('Challenge Cloudflare'), findsNothing);
    expect(find.text('Vérifier l’accès à la source'), findsOneWidget);
  });

  testWidgets('does not auto-open the panel for unrelated errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ExtensionHomeEmptyState(
          onRetry: () async {},
          onRefresh: () async {},
          header: const SizedBox.shrink(),
          manualCheckUrl: 'https://source.example/',
          error: Exception('SocketException: connection timed out'),
        ),
      ),
    );

    expect(find.text('Impossible de charger le contenu'), findsOneWidget);
    expect(find.text('Challenge Cloudflare'), findsNothing);
    expect(find.text('Vérifier l’accès à la source'), findsOneWidget);
  });
}