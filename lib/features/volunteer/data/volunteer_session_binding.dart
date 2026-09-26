import 'dart:async';

/// Renewal belongs to the same signed-in account. A sign-out, account switch,
/// or failed auth stream ends this binding; a new login creates a new binding.
StreamSubscription<String?> bindVolunteerSession(
  Stream<String?> sessions, {
  required String uid,
  required Future<void> Function() renew,
  required Future<void> Function() end,
}) {
  var ended = false;
  void stop() {
    if (ended) return;
    ended = true;
    unawaited(end());
  }

  return sessions.listen((currentUid) {
    if (ended) return;
    if (currentUid != uid) {
      stop();
    } else {
      unawaited(renew());
    }
  }, onError: (Object error) => stop());
}
