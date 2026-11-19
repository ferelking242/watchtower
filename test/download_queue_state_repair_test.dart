import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/models/download.dart';
import 'package:watchtower/modules/manga/download/providers/download_provider.dart';
import 'package:watchtower/modules/more/download_queue/moviebox_card_widgets.dart';

Download _row({required String status, bool? isDownload, int? id = 1}) =>
    Download(
      id: id,
      succeeded: 0,
      failed: 0,
      total: 1,
      isDownload: isDownload ?? false,
      isStartDownload: true,
      status: status,
    );

void main() {
  group('repairOrphanedInFlightRow', () {
    test('requeues a row whose process died mid-transfer', () {
      // The regression: a row left in `downloading` after the OS killed the
      // process is not a pending status, so the scheduler ignored it forever
      // and the queue showed an animated bar that never moved.
      final row = _row(status: 'downloading');
      expect(
        repairOrphanedInFlightRow(row, isActive: false),
        isTrue,
      );
      expect(row.status, 'queued');
      expect(row.isStartDownload, isTrue);
      expect(row.isDownload, isFalse);
    });

    test('covers every in-flight status', () {
      for (final status in ['fetching_metadata', 'initializing', 'downloading']) {
        final row = _row(status: status);
        expect(
          repairOrphanedInFlightRow(row, isActive: false),
          isTrue,
          reason: '$status must be repairable',
        );
        expect(row.status, 'queued');
      }
    });

    test('leaves a row alone while a worker owns it', () {
      final row = _row(status: 'downloading');
      expect(repairOrphanedInFlightRow(row, isActive: true), isFalse);
      expect(row.status, 'downloading');
    });

    test('ignores terminal and queued rows', () {
      for (final status in ['queued', 'paused', 'failed', 'cancelled', 'completed', 'rate_limited']) {
        final row = _row(status: status);
        expect(
          repairOrphanedInFlightRow(row, isActive: false),
          isFalse,
          reason: '$status is not an orphan candidate',
        );
      }
    });

    test('never touches a finished download', () {
      final row = _row(status: 'downloading', isDownload: true);
      expect(repairOrphanedInFlightRow(row, isActive: false), isFalse);
    });

    test('does not mark the row as failed while it still has repairs left', () {
      // `failed > 0` paints the row red, so an interrupted-but-healthy transfer
      // must not be counted there or it looks broken between repair and restart.
      final row = _row(status: 'initializing');
      repairOrphanedInFlightRow(row, isActive: false, previousRepairs: 1);
      expect(row.failed, 0);
      expect(row.status, 'queued');
    });

    test('gives up after repeated repairs instead of looping forever', () {
      final row = _row(status: 'initializing');
      expect(
        repairOrphanedInFlightRow(row, isActive: false, previousRepairs: 2),
        isTrue,
      );
      expect(row.status, 'failed');
      expect(row.isStartDownload, isFalse);
    });
  });

  group('MbRowStateStyle', () {
    test('failure is red with its own icon', () {
      final style = MbRowStateStyle.resolve(
        isComplete: false,
        hasFailed: true,
        isPaused: false,
      );
      expect(style.accent, mbRed);
      expect(style.icon, Icons.refresh_rounded);
    });

    test('pause is grey, not orange', () {
      final style = MbRowStateStyle.resolve(
        isComplete: false,
        hasFailed: false,
        isPaused: true,
      );
      expect(style.accent, mbGrey);
      expect(style.icon, Icons.play_arrow_rounded);
      expect(style.gradient.colors, containsAll(<Color>[mbGrey, mbGreyLight]));
    });

    test('a rate-limited row is amber with a clock', () {
      final style = MbRowStateStyle.resolve(
        isComplete: false,
        hasFailed: false,
        isPaused: false,
        isRateLimited: true,
      );
      expect(style.accent, mbAmber);
      expect(style.icon, Icons.hourglass_top_rounded);
    });

    test('an active transfer keeps the green pause affordance', () {
      final style = MbRowStateStyle.resolve(
        isComplete: false,
        hasFailed: false,
        isPaused: false,
      );
      expect(style.accent, mbGreen);
      expect(style.icon, Icons.pause_rounded);
    });

    test('failure outranks every other state', () {
      final style = MbRowStateStyle.resolve(
        isComplete: true,
        hasFailed: true,
        isPaused: true,
        isWaiting: true,
        isRateLimited: true,
      );
      expect(style.accent, mbRed);
    });
  });
}
