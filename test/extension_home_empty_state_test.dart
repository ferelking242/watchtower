import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/modules/watch/home/extension_home_empty_state.dart';

void main() {
  test('extracts real HTTP status codes from response errors', () {
    expect(
      extensionHttpStatusCode(Exception('HttpException: HTTP 404 Not Found')),
      404,
    );
    expect(extensionHttpStatusCode(Exception('statusCode: 503')), 503);
    expect(
      extensionRequestFailureMessage(Exception('HTTP 503 Service Unavailable')),
      contains('HTTP 503'),
    );
  });

  test(
    'distinguishes an API block from an interactive Cloudflare challenge',
    () {
      final apiError = Exception(
        'Error: [AllManga] Cloudflare challenge blocked the API request',
      );

      expect(extensionErrorIsCloudflareApiBlock(apiError), isTrue);
      expect(extensionErrorIsCloudflareChallenge(apiError), isFalse);
      expect(extensionHttpStatusCode(apiError), isNull);
      expect(
        extensionRequestFailureMessage(apiError),
        contains('aucun code HTTP'),
      );
      expect(
        extensionErrorIsCloudflareChallenge(
          Exception('HTTP 403: cf-chl-out challenge page'),
        ),
        isTrue,
      );
    },
  );

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

  testWidgets('shows a compact Cloudflare challenge and real response code', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ExtensionHomeEmptyState(
          onRetry: () async {},
          onRefresh: () async {},
          header: const SizedBox.shrink(),
          error: Exception('HTTP 403: cf-chl-out challenge page'),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('Vérification Cloudflare requise'), findsOneWidget);
    expect(find.text('HTTP 403'), findsOneWidget);
    expect(find.byIcon(Icons.shield_rounded), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_rounded), findsNothing);
  });

  testWidgets(
    'does not open a challenge panel for an API-only Cloudflare block',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ExtensionHomeEmptyState(
            onRetry: () async {},
            onRefresh: () async {},
            header: const SizedBox.shrink(),
            challengeUrl: 'https://allmanga.to/',
            error: Exception(
              'Error: [AllManga] Cloudflare challenge blocked the API request',
            ),
          ),
        ),
      );

      expect(find.text('Accès API bloqué'), findsOneWidget);
      expect(
        find.textContaining('Cloudflare bloque l’API'),
        findsOneWidget,
      );
      expect(find.textContaining('aucun code HTTP'), findsOneWidget);
      expect(find.text('HTTP 403'), findsNothing);
      expect(find.text('Vérification Cloudflare requise'), findsNothing);
      expect(find.text('Aucun challenge détecté'), findsNothing);
      expect(find.text('Vérifier l’accès à la source'), findsNothing);
      expect(find.byIcon(Icons.cloud_off_rounded), findsNothing);
    },
  );

  testWidgets('shows the HTTP code for a missing source page', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ExtensionHomeEmptyState(
          onRetry: () async {},
          onRefresh: () async {},
          header: const SizedBox.shrink(),
          error: Exception('HTTP 404 Not Found'),
        ),
      ),
    );

    expect(find.text('HTTP 404'), findsOneWidget);
    expect(find.textContaining('page introuvable'), findsOneWidget);
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
          challengeUrl: 'https://source.example/',
          error: Exception('SocketException: connection timed out'),
        ),
      ),
    );

    expect(find.text('Impossible de charger le contenu'), findsOneWidget);
    expect(find.text('Challenge Cloudflare'), findsNothing);
    expect(find.text('Vérifier l’accès à la source'), findsOneWidget);
  });
}