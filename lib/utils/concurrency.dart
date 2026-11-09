import 'dart:async';

import 'package:pool/pool.dart';

/// Bounded-concurrency helpers.
///
/// Extension runtimes are non-reentrant per source within one isolate (see
/// `ExtensionServiceRegistry`), and calls there are serialized by their queue.
/// Running several `get` calls for the *same* source on that runtime is
/// pointless. The bulk-download sheet is a deliberate exception: it pins
/// independent entries to separate worker isolates, each with its own runtime.
/// For other work, run different sources or plain network/disk requests here.
///
/// They replace the common `for (final x in xs) { await f(x); }` pattern, which
/// serializes independent network and disk requests and is the main reason
/// bulk operations (library scan, extension updates, chapter page probing)
/// felt slow.

/// Default ceiling for network-bound work: enough to hide latency without
/// opening a connection storm that starves the OS or trips server throttling.
const int kNetworkConcurrency = 6;

/// Default ceiling for disk-bound probes: cheap syscalls, so a wider pool.
const int kDiskConcurrency = 8;

/// Maps [items] through [task] with at most [maxConcurrent] in flight at once,
/// preserving input order in the result.
///
/// Set [propagateErrors] to `false` to keep going when a task throws; the
/// failed slot then holds `null`. When it is `true` (default) the first error
/// aborts the whole map, matching `Future.wait`.
Future<List<R?>> mapParallel<T, R>(
  Iterable<T> items,
  int maxConcurrent,
  Future<R> Function(T item) task, {
  bool propagateErrors = true,
}) async {
  final list = items.toList(growable: false);
  final results = List<R?>.filled(list.length, null);
  if (list.isEmpty) return results;

  final pool = Pool(maxConcurrent < 1 ? 1 : maxConcurrent);
  Object? firstError;
  StackTrace? firstStack;

  Future<void> run(int i) async {
    // Once a failure is recorded, skip the tasks still queued behind it so a
    // broken item does not keep burning connections.
    if (firstError != null) return;
    try {
      results[i] = await task(list[i]);
    } catch (error, stackTrace) {
      if (propagateErrors) {
        firstError ??= error;
        firstStack ??= stackTrace;
      } else {
        results[i] = null;
      }
    }
  }

  try {
    await Future.wait(
      List.generate(list.length, (i) => pool.withResource(() => run(i))),
    );
  } finally {
    unawaited(pool.close());
  }
  if (firstError != null) {
    Error.throwWithStackTrace(firstError!, firstStack!);
  }
  return results;
}

/// Runs [task] over [items] with at most [maxConcurrent] in flight, discarding
/// the results. Convenience wrapper over [mapParallel] for side-effecting work.
Future<void> forEachParallel<T>(
  Iterable<T> items,
  int maxConcurrent,
  Future<void> Function(T item) task, {
  bool propagateErrors = true,
}) async {
  await mapParallel<T, void>(
    items,
    maxConcurrent,
    (item) => task(item),
    propagateErrors: propagateErrors,
  );
}

/// Runs [task] over [items] with bounded concurrency and a stable slot per
/// worker. Use the slot to pin a sequence of related calls to one isolate.
Future<void> forEachParallelWithWorkerSlots<T>(
  Iterable<T> items,
  int maxConcurrent,
  Future<void> Function(T item, int workerSlot) task,
) async {
  final list = items.toList(growable: false);
  if (list.isEmpty) return;
  final requested = maxConcurrent < 1 ? 1 : maxConcurrent;
  final limit = requested < list.length ? requested : list.length;

  var next = 0;
  Future<void> worker(int workerSlot) async {
    while (true) {
      final index = next++;
      if (index >= list.length) return;
      await task(list[index], workerSlot);
    }
  }

  await Future.wait([for (var slot = 0; slot < limit; slot++) worker(slot)]);
}
