import 'dart:async';

import 'package:flutter/foundation.dart';

/// One active request and one pending follow-up. Resume is never discarded
/// because a push arrived: a failed fetch must still have a recovery path.
class CoalescedRefresh {
  Future<void>? _running;
  bool _again = false;
  Future<void> run(Future<void> Function() action) {
    if (_running != null) {
      _again = true;
      return _running!;
    }
    final completion = Completer<void>();
    _running = completion.future;
    unawaited(
      _loop(action)
          .then(completion.complete, onError: completion.completeError),
    );
    return completion.future;
  }

  Future<void> _loop(Future<void> Function() action) async {
    try {
      do {
        _again = false;
        try {
          await action();
        } catch (error) {
          if (kDebugMode) {
            debugPrint('Radd Guardian recovery failed (${error.runtimeType})');
          }
        }
      } while (_again);
    } finally {
      _running = null;
    }
  }
}
