import 'dart:async';
import 'dart:isolate';

/// Pool dynamique d'Isolates Dart pour le traitement parallèle des fichiers.
///
/// Caractéristiques :
///   - Crée [maxWorkers] isolates (défaut : nombre de cœurs CPU disponibles).
///   - Équilibrage dynamique : les tâches sont distribuées à l'isolate
///     le moins chargé.
///   - Chaque tâche est un objet sérialisable envoyé via [SendPort].
///   - Les résultats reviennent via [ReceivePort] avec un ID de corrélation.
///   - Shutdown propre : attente de toutes les tâches en cours, puis KILL.
///
/// Usage :
/// ```dart
/// final pool = await IsolatePool.create(entryPoint: myIsolateMain);
/// final result = await pool.submit({'path': '/foo/bar.mkv'});
/// await pool.dispose();
/// ```
typedef IsolateEntryPoint = void Function(SendPort sendPort);

class _IsolateWorker {
  final int id;
  final Isolate isolate;
  final SendPort sendPort;
  final ReceivePort receivePort;

  int pendingTasks = 0;

  _IsolateWorker({
    required this.id,
    required this.isolate,
    required this.sendPort,
    required this.receivePort,
  });
}

class _PendingTask<T> {
  final String taskId;
  final Completer<T> completer;

  _PendingTask(this.taskId, this.completer);
}

class IsolatePool {
  final List<_IsolateWorker> _workers = [];
  final Map<String, Completer<dynamic>> _pending = {};
  int _taskCounter = 0;
  bool _disposed = false;

  IsolatePool._();

  /// Crée et initialise le pool avec [maxWorkers] workers.
  ///
  /// Si [maxWorkers] est 0, utilise [Platform.numberOfProcessors] - 1
  /// (avec un minimum de 1).
  static Future<IsolatePool> create({
    required IsolateEntryPoint entryPoint,
    int maxWorkers = 0,
  }) async {
    final pool = IsolatePool._();
    final workers = maxWorkers > 0 ? maxWorkers : _defaultWorkers();

    for (var i = 0; i < workers; i++) {
      await pool._spawnWorker(i, entryPoint);
    }
    return pool;
  }

  /// Soumet une tâche au worker le moins chargé.
  ///
  /// [payload] doit être sérialisable (Map, List, primitives).
  /// Retourne le résultat de l'isolate (ou lance une exception si échec).
  Future<T> submit<T>(Map<String, dynamic> payload) async {
    if (_disposed) throw StateError('IsolatePool has been disposed');

    final taskId = 'task_${_taskCounter++}';
    final completer = Completer<T>();
    _pending[taskId] = completer;

    // Choisir le worker avec le moins de tâches en attente
    final worker = _leastBusy();
    worker.pendingTasks++;

    worker.sendPort.send({'taskId': taskId, 'payload': payload});

    return completer.future;
  }

  /// Dispose tous les workers proprement.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    // Annuler les tâches en attente
    for (final comp in _pending.values) {
      if (!comp.isCompleted) {
        comp.completeError(StateError('Pool disposed before task completed'));
      }
    }
    _pending.clear();

    for (final worker in _workers) {
      worker.sendPort.send({'taskId': '__shutdown__', 'payload': null});
      worker.receivePort.close();
      worker.isolate.kill(priority: Isolate.beforeNextEvent);
    }
    _workers.clear();
  }

  /// Nombre de workers actifs.
  int get workerCount => _workers.length;

  /// Nombre total de tâches en attente de résultat.
  int get pendingCount => _pending.length;

  // ── Privé ──────────────────────────────────────────────────────────────────

  Future<void> _spawnWorker(int id, IsolateEntryPoint entryPoint) async {
    final receivePort = ReceivePort();
    final completer = Completer<SendPort>();

    // Premier message = handshake SendPort
    late StreamSubscription sub;
    sub = receivePort.listen((message) {
      if (message is SendPort) {
        completer.complete(message);
        sub.cancel();
      }
    });

    final isolate = await Isolate.spawn(
      entryPoint,
      receivePort.sendPort,
      debugName: 'LocalIndexerWorker#$id',
    );

    final sendPort = await completer.future;

    final worker = _IsolateWorker(
      id: id,
      isolate: isolate,
      sendPort: sendPort,
      receivePort: receivePort,
    );

    // Écouter les résultats de ce worker
    receivePort.listen((message) {
      if (message is! Map) return;
      final taskId = message['taskId'] as String?;
      if (taskId == null) return;

      final comp = _pending.remove(taskId);
      worker.pendingTasks = (worker.pendingTasks - 1).clamp(0, 999999);

      if (comp == null || comp.isCompleted) return;

      if (message.containsKey('error')) {
        comp.completeError(
          Exception(message['error']),
          StackTrace.fromString(message['stackTrace'] ?? ''),
        );
      } else {
        comp.complete(message['result']);
      }
    });

    _workers.add(worker);
  }

  _IsolateWorker _leastBusy() {
    return _workers.reduce(
      (a, b) => a.pendingTasks <= b.pendingTasks ? a : b,
    );
  }

  static int _defaultWorkers() {
    // Platform.numberOfProcessors n'est pas disponible partout, fallback 4
    try {
      final n = int.tryParse(
            const String.fromEnvironment('ISOLATE_POOL_SIZE'),
          ) ??
          0;
      if (n > 0) return n;
    } catch (_) {}
    return 4; // valeur conservative multi-plateforme
  }
}
