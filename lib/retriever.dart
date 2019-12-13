import 'dart:async';

import "package:pool/pool.dart";
import "package:collection/collection.dart";

class Task<K, V> extends Comparable {
  final K key;
  final Future<V> Function(K) get;
  final void Function(K) cancel;
  final int priority;
  Task(this.key, this.get, this.cancel, this.priority);

  int compareTo(other) => priority.compareTo(other.priority);
}

class PooledRetriever<K, V> {
  final Map<K, Completer<V>> _cache = Map<K, Completer<V>>();
  final PriorityQueue<Task<K, V>> queue = PriorityQueue<Task<K, V>>();
  final Pool pool = Pool(5);
  final Map<K, Task> active = <K, Task>{};
  bool started = false;
  void process() async {
    started = true;
    while (started && queue.isNotEmpty) {
      print("**** ${active.length}");
      final resource = await pool.request();
      if (!started) break;
      final task = queue.removeFirst();
      final completer = _cache.putIfAbsent(task.key, () => Completer());
      // Already done.
      if (completer.isCompleted) continue;
      // Already actively retrieving.
      if (active.containsKey(task.key)) continue;
      active[task.key] = task;
      task.get(task.key).then((result) {
        completer.complete(result);
      }, onError: (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }).whenComplete(() {
        resource.release();
        active.remove(task.key);
      });
    }
    started = false;
  }

  void stop() {
    started = false;
    for (final task in active.values) {
      task.cancel(task.key);
    }
  }

  void enqueue(Task task) {
    queue.add(task);
    if (!started) {
      process();
    }
  }

  Future<V> fetch(Task task) {
    enqueue(task);
    return _cache.putIfAbsent(task.key, () => Completer()).future;
  }
}
