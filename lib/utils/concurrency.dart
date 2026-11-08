import 'dart:async';

/// Bounded-concurrency helpers.
///
/// Extension runtimes are non-reentrant per source (see
/// `ExtensionServiceRegistry`), and every call for one source is serialized by
/// its queue. Running several `get` calls for the *same* source in parallel is
/// therefore pointless: they will run one after another anyway. Running them
/// for *different* sources (or plain network/disk work that does not touch an
/// extension runtime) is what these helpers are for.
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
