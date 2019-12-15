import 'dart:async';

import "package:pool/pool.dart";
import "package:async/async.dart";
import "dart:collection";

/// Handles rate limited scheduling of tasks.
///
/// Designed to allow prefetching tasks tht will likely be needed
/// later with [enqueue].
class Retriever<K, V> {
  final CancelableOperation<V> Function(K, Retriever) _get;
  final Map<K, Completer<V>> _cache = Map<K, Completer<V>>();

  /// Operations that are waiting to run.
  final Queue<K> _queue = Queue<K>();

  final Pool _pool;

  /// The active operations
  final Map<K, CancelableOperation<V>> _active = <K, CancelableOperation<V>>{};
  bool started = false;

  Retriever(this._get, {maxConcurrentOperations = 10})
      : _pool = Pool(maxConcurrentOperations);

  /// Starts operations from the beginning of the queue.
  void _process() async {
    assert(!started);
    started = true;
    while (_queue.isNotEmpty) {
      final resource = await _pool.request();
      // This checks if [stop] has been called while waiting for a resource.
      if (!started) {
        resource.release();
        break;
      }
      // Take the highest priority task from the queue.
      final task = _queue.removeFirst();
      // Create or get the completer to deliver the result to.
      final completer = _cache.putIfAbsent(task, () => Completer());
      // Already done or already scheduled => do nothing.
      if (completer.isCompleted || _active.containsKey(task)) {
        resource.release();
        continue;
      }

      // Schedule task.
      final operation = _get(task, this);
      _active[task] = operation;
      operation
          .then((result) {
            completer.complete(result);
          }, onError: (error, stackTrace) {
            completer.completeError(error, stackTrace);
          })
          .value
          .whenComplete(() {
            resource.release();
            _active.remove(task);
          });
    }
    started = false;
  }

  /// Cancels all active computations, and clears the queue.
  void stop() {
    // Stop the processing loop
    started = false;
    // Cancel all active operatios
    for (final operation in _active.values) {
      operation.cancel();
    }
    // Do not process anymore.
    _queue.clear();
  }

  // Puts [task] in the back of the work queue.
  void enqueue(K task) {
    _queue.addLast(task);
    if (!started) _process();
  }

  /// Returns the result of [_get]ting [task].
  ///
  /// If [task] is already done, the cached result will be returned.
  /// If [task] is not yet active, it will go to the front of the work queue
  /// to be scheduled when there are free resources.
  Future<V> get(K task) {
    final completer = _cache.putIfAbsent(task, () => Completer());
    if (!completer.isCompleted) {
      // We don't worry about adding the same task twice.
      // It will get dedupped by the [_process] loop.
      _queue.addFirst(task);
      if (!started) _process();
    }
    return completer.future;
  }
}
