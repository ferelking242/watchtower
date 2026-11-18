import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/local_indexer/engine/indexer_engine.dart';
import 'package:watchtower/local_indexer/providers/local_indexer_provider.dart';

/// The notification and the on-screen bar both need a real percentage, so the
/// engine must publish a total during the analysis phase and a processed count
/// that grows with it.
void main() {
  group('IndexerStatus progress', () {
    test('is indeterminate while discovery is still counting', () {
      const status = IndexerStatus.scanning(
        120,
        0,
        phase: IndexerPhase.discovering,
      );
      expect(status.isDiscovering, isTrue);
      expect(status.progress, isNull);
    });

    test('is determinate once analysis has a total', () {
      const status = IndexerStatus.scanning(
        500,
        250,
        processed: 250,
        total: 500,
        phase: IndexerPhase.analyzing,
      );
      expect(status.isAnalyzing, isTrue);
      expect(status.progress, closeTo(0.5, 0.0001));
    });

    test('clamps to 1.0 when cache hits push processed past the total', () {
      const status = IndexerStatus.scanning(
        100,
        0,
        processed: 140,
        total: 100,
        phase: IndexerPhase.analyzing,
      );
      expect(status.progress, 1.0);
    });
  });

  group('SmartLibraryScanState', () {
    test('idle is not busy and has no progress', () {
      const state = SmartLibraryScanState();
      expect(state.isBusy, isFalse);
      expect(state.progress, isNull);
    });

    test('reports a fraction while analyzing', () {
      const state = SmartLibraryScanState(
        phase: SmartLibraryScanPhase.analyzing,
        processed: 3,
        total: 4,
      );
      expect(state.isBusy, isTrue);
      expect(state.progress, closeTo(0.75, 0.0001));
    });

    test('enrichment keeps the bar busy without a fraction', () {
      const state = SmartLibraryScanState(
        phase: SmartLibraryScanPhase.enriching,
      );
      expect(state.isBusy, isTrue);
      expect(state.progress, isNull);
    });
  });
}
