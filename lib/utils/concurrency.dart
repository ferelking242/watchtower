import 'dart:async';

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
  final limit = maxConcurrent < 1 ? 1 : maxConcurrent;

  var next = 0;
  Object? firstError;
  StackTrace? firstStack;

  Future<void> worker() async {
    while (true) {
      if (propagateErrors && firstError != null) return;
      final i = next++;
      if (i >= list.length) return;
      try {
        results[i] = await task(list[i]);
      } catch (error, stackTrace) {
        if (propagateErrors) {
          firstError = error;
          firstStack = stackTrace;
          return;
        }
        results[i] = null;
      }
    }
  }

  await Future.wait(
    List.generate(limit < list.length ? limit : list.length, (_) => worker()),
  );
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
  final list = items.toList(growable: false);
  if (list.isEmpty) return;
  final limit = maxConcurrent < 1 ? 1 : maxConcurrent;

  var next = 0;
  Object? firstError;
  StackTrace? firstStack;

  Future<void> worker() async {
    while (true) {
      if (propagateErrors && firstError != null) return;
      final i = next++;
      if (i >= list.length) return;
      try {
        await task(list[i]);
      } catch (error, stackTrace) {
        if (propagateErrors) {
          firstError = error;
          firstStack = stackTrace;
          return;
        }
      }
    }
  }

  await Future.wait(
    List.generate(limit < list.length ? limit : list.length, (_) => worker()),
  );
  if (firstError != null) {
    Error.throwWithStackTrace(firstError!, firstStack!);
  }
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
