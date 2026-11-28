import 'dart:async';

import 'package:flutter/foundation.dart';

import 'guardian_repository.dart';

Duration guardianRevisitFreshness = const Duration(seconds: 15);

bool guardianAccessLost(Object error) =>
    error is AppFailure &&
    const {'unauthorized', 'role', 'accountInactive'}.contains(error.code);

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
