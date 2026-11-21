import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watchtower/services/download_manager/download_failure_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DownloadFailure', () {
    test('round-trips through JSON', () {
      final failure = DownloadFailure(
        message: 'Trop de requêtes envoyées (429).',
        at: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        partial: true,
        failedPages: 3,
        totalPages: 40,
      );
      final restored = DownloadFailure.fromJson(failure.toJson());
      expect(restored, isNotNull);
      expect(restored!.message, failure.message);
      expect(restored.at, failure.at);
      expect(restored.partial, isTrue);
      expect(restored.failedPages, 3);
      expect(restored.totalPages, 40);
    });

    test('rejects junk instead of throwing', () {
      expect(DownloadFailure.fromJson(null), isNull);
      expect(DownloadFailure.fromJson('nope'), isNull);
      expect(DownloadFailure.fromJson({'message': ''}), isNull);
      expect(DownloadFailure.fromJson({'message': 'x'}), isNull);
    });

    test('compares by value so a card can select its own entry', () {
      // The queue card selects its chapter's message out of the shared map;
      // without value equality every card rebuilt on any chapter's failure.
      final at = DateTime.fromMillisecondsSinceEpoch(1700000000000);
      DownloadFailure make({String message = 'HTTP 429', int failed = 1}) =>
          DownloadFailure(message: message, at: at, failedPages: failed);

      expect(make(), make());
      expect(make().hashCode, make().hashCode);
      expect(make(), isNot(make(message: 'HTTP 500')));
      expect(make(), isNot(make(failed: 2)));
    });
  });

  group('DownloadFailureStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      final store = DownloadFailureStore.instance;
      for (final id in store.failures.value.keys.toList()) {
        store.clear(id);
      }
    });

    test('stores and reads the reason for a chapter', () {
      final store = DownloadFailureStore.instance;
      store.set(
        7,
        DownloadFailure(
          message: 'Accès interdit (403).',
          at: DateTime.fromMillisecondsSinceEpoch(1),
        ),
      );
      expect(store.of(7)?.message, 'Accès interdit (403).');
    });

    test('clearing a reason removes it', () {
      final store = DownloadFailureStore.instance;
      store.set(
        8,
        DownloadFailure(
          message: 'Contenu introuvable (404).',
          at: DateTime.fromMillisecondsSinceEpoch(1),
        ),
      );
      store.clear(8);
      expect(store.of(8), isNull);
    });

    test('the value notifier reflects writes so the queue rebuilds', () {
      final store = DownloadFailureStore.instance;
      store.set(
        9,
        DownloadFailure(
          message: 'Erreur serveur interne (500).',
          at: DateTime.fromMillisecondsSinceEpoch(1),
        ),
      );
      expect(store.failures.value[9]?.message, 'Erreur serveur interne (500).');
    });

    test('persists the reason so it survives a missed toast', () async {
      final store = DownloadFailureStore.instance;
      store.set(
        10,
        DownloadFailure(
          message: 'Trop de requêtes envoyées (429).',
          at: DateTime.fromMillisecondsSinceEpoch(1),
        ),
      );
      // The write is fire-and-forget; give the microtask queue a chance.
      await Future<void>.delayed(Duration.zero);
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('watchtower_download_failures');
      expect(raw, isNotNull);
      expect(raw, contains('Trop de requêtes envoyées (429).'));
    });
  });
}
