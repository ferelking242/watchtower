import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/modules/anti_bot/cloudflare_bypass_panel.dart';
import 'package:watchtower/modules/watch/home/extension_home_empty_state.dart';

void main() {
  test('extracts the exact failing URL from an extension error', () {
    expect(
      extensionFailedUrl(
        Exception(
          '[AllManga] Cloudflare challenge blocked the API request '
          '(https://api.allanime.day/api?variables=%7B%7D&query=x)',
        ),
      ),
      'https://api.allanime.day/api?variables=%7B%7D&query=x',
    );
    expect(
      extensionFailedUrl(
        Exception(
          'Cloudflare challenge detected (cf-chl-) for '
          'https://imhentai.xxx/search/?key=&pp=1&page=1 — HTTP 403',
        ),
      ),
      'https://imhentai.xxx/search/?key=&pp=1&page=1',
    );
    expect(extensionFailedUrl(Exception('SocketException: timed out')), isNull);
  });

  test('keeps parentheses inside the query, drops sentence punctuation', () {
    expect(
      extensionFailedUrl(
        Exception(
          '[AllManga] Cloudflare challenge blocked the API request '
          '(https://api.allanime.day/api?query=query(%24x)&v=1)',
        ),
      ),
      'https://api.allanime.day/api?query=query(%24x)&v=1',
    );
    expect(
      extensionFailedUrl(
        Exception('Cloudflare detected for https://site.test/a?b=1.'),
      ),
      'https://site.test/a?b=1',
    );
  });

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

  test('an unrecognised failure shows the real detail, not a catch-all', () {
    final error = Exception(
      '[AllManga] Popular response did not contain recommendations',
    );
    // The extension's own message must survive instead of the generic
    // “La source est momentanément indisponible”.
    expect(
      extensionRequestFailureMessage(error),
      'Popular response did not contain recommendations',
    );
    expect(
      extensionErrorDetail(Exception('Exception: plain failure')),
      'plain failure',
    );
    expect(extensionErrorDetail(Exception('   ')), isNull);
  });

  test('HTTP 0 is reported as an anti-bot cut, never as “HTTP 0”', () {
    // The HTTP bridge returns statusCode 0 when the request itself threw (the
    // anti-bot closed the connection). It must not leak as a status code.
    final dropped = Exception(
      'Error: [AllManga] Cloudflare blocked the API request — connection '
      'closed before any response (HTTP 0) (https://api.allanime.day/api?q=1)',
    );
    // The parser only accepts a real 1xx-5xx status line, so “HTTP 0” is never
    // surfaced as a code — the dedicated helper names the cause instead.
    expect(extensionHttpStatusCode(dropped), isNull);
    expect(extensionErrorIsConnectionDropped(dropped), isTrue);
    expect(extensionErrorIsCloudflareApiBlock(dropped), isTrue);
    expect(extensionErrorTitle(dropped), 'Accès API bloqué');
    expect(
      extensionRequestFailureMessage(dropped),
      contains('coupé la requête API'),
    );
    expect(extensionRequestFailureMessage(dropped), isNot(contains('HTTP 0')));
    expect(extensionFailedUrl(dropped), 'https://api.allanime.day/api?q=1');

    // A cut connection with no API wording is still labelled as an anti-bot cut.
    final generic = Exception(
      '[IMHentai] Cloudflare: connection closed before full header was received',
    );
    expect(extensionErrorIsConnectionDropped(generic), isTrue);
    expect(extensionErrorTitle(generic), 'Blocage anti-bot — connexion coupée');
    expect(
      extensionRequestFailureMessage(generic),
      contains('coupé la connexion'),
    );
  });

  test('a plain connection drop without anti-bot context is not mislabelled', () {
    final plain = Exception('ClientException: Connection closed before full '
        'header was received');
    expect(extensionErrorIsConnectionDropped(plain), isFalse);
  });

  testWidgets('reveals the raw error behind a “Détails” disclosure', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ExtensionHomeEmptyState(
          onRetry: () async {},
          onRefresh: () async {},
          header: const SizedBox.shrink(),
          error: Exception(
            'Error: [IMHentai] page contained no gallery card (HTTP 200, '
            '91234 bytes) — likely a Cloudflare interstitial',
          ),
        ),
      ),
    );
    await tester.pump();

    // Collapsed by default: the raw text is not shown yet.
    expect(find.text('Détails de l’erreur'), findsOneWidget);
    expect(find.textContaining('91234 bytes'), findsNothing);

    await tester.tap(find.text('Détails de l’erreur'));
    // The Lottie empty-state animation never settles, so pump fixed frames.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.textContaining('91234 bytes'), findsOneWidget);
    expect(find.textContaining('Cloudflare interstitial'), findsOneWidget);
  });

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
    'opens the bypass panel on the failing URL for a Cloudflare API block',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ExtensionHomeEmptyState(
            onRetry: () async {},
            onRefresh: () async {},
            header: const SizedBox.shrink(),
            challengeUrl: 'https://allmanga.to/',
            error: Exception(
              'Error: [AllManga] Cloudflare challenge blocked the API request '
              '(https://api.allanime.day/api?query=x)',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Accès API bloqué'), findsOneWidget);
      expect(find.textContaining('Cloudflare bloque l’API'), findsOneWidget);
      expect(find.text('Réessayer la source'), findsOneWidget);
      expect(find.text('Vérifier la page'), findsNothing);
      // The panel opens on the exact challenged request, not the site root.
      final panel = tester.widget<CloudflareBypassPanel>(
        find.byType(CloudflareBypassPanel),
      );
      expect(panel.url, 'https://api.allanime.day/api?query=x');
      expect(find.text('Vérification Cloudflare requise'), findsNothing);
      expect(find.byIcon(Icons.cloud_off_rounded), findsNothing);
    },
  );

  testWidgets('shows concise HTTP 403, 404 and 500 errors', (tester) async {
    for (final code in [403, 404, 500]) {
      const verboseDetail = 'verbose upstream diagnostic trace';
      await tester.pumpWidget(
        MaterialApp(
          home: ExtensionHomeEmptyState(
            onRetry: () async {},
            onRefresh: () async {},
            header: const SizedBox.shrink(),
            error: Exception(
              'HttpException: HTTP $code response — $verboseDetail',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Erreur HTTP $code'), findsOneWidget);
      expect(find.textContaining('HTTP $code'), findsWidgets);
      expect(find.textContaining(verboseDetail), findsNothing);
      // The generic fallback must never replace a known response code.
      expect(find.text('Impossible de charger le contenu'), findsNothing);
    }
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

    expect(find.text('Connexion impossible'), findsOneWidget);
    expect(find.text('Impossible de charger le contenu'), findsNothing);
    expect(find.text('Challenge Cloudflare'), findsNothing);
    expect(find.text('Vérifier l’accès à la source'), findsOneWidget);
  });
}