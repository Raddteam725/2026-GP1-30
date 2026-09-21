import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Case-update SIGNALS for the Guardian app -- never case data.
///
/// The real-time contract is FastAPI (authoritative) + Firestore (durable)
/// + FCM (signal) + authoritative refetch: when the backend commits a case
/// change it writes the Guardian's durable notification record and pushes a
/// small data message (`role`, `kind`, `status`, `case_id`, `event_id`). This
/// module validates that a received message belongs to that contract,
/// de-duplicates repeated delivery of the same (case, status), and fans a
/// [GuardianCaseEvent] out to whichever screens are open. Every listener
/// reacts by re-fetching its OWN state from the authenticated API; nothing
/// here is ever displayed or trusted as the case's state.
///
/// App resume is the recovery signal for anything missed while the app was
/// backgrounded, suspended or offline (an FCM message is not guaranteed):
/// it emits a case-less event that makes every open screen refetch.
enum GuardianEventSource {
  /// A foreground FCM data message that passed validation.
  push,

  /// The app returned to the foreground (see [GuardianCaseEvents.resume]).
  resume,

  /// A caller asked for a generic refresh (see GuardianPushRefresh).
  manual,
}

class GuardianCaseEvent {
  const GuardianCaseEvent({
    required this.source,
    this.caseId,
    this.status,
    this.kind,
  });
  final GuardianEventSource source;

  /// Which case changed -- null for a recovery/generic signal, which means
  /// "anything may have changed".
  final String? caseId;
  final String? status;
  final String? kind;

  /// Whether a screen showing case [id] should refetch for this event.
  bool concerns(String id) => caseId == null || caseId == id;
}

class GuardianCaseEvents extends ChangeNotifier {
  GuardianCaseEvents._();
  static final instance = GuardianCaseEvents._();

  GuardianCaseEvent? _last;

  /// The event that caused the most recent notification.
  GuardianCaseEvent? get last => _last;

  // Stable identifiers already in the push contract: one entry per
  // (case, status) seen. A retried/duplicated delivery of the SAME status
  // is dropped; a NEWER status for the same case has a different key and is
  // never suppressed. Bounded and insertion-ordered; cleared at logout.
  final List<String> _seen = [];
  static const _seenLimit = 256;
  DateTime? _lastPushAt;
  AppLifecycleListener? _lifecycle;

  /// Validates an FCM `data` payload against the Guardian update contract
  /// and emits a [GuardianCaseEvent] for it. Returns false (and emits
  /// nothing) for a message that is not a Guardian case update or that
  /// repeats an already-processed (case, status).
  bool acceptPush(Map<Object?, Object?> data) {
    final role = data['role'];
    if (role != null && role != 'guardian') return false;
    final caseId = data['case_id'], status = data['status'];
    if (caseId is! String ||
        caseId.isEmpty ||
        status is! String ||
        status.isEmpty) {
      return false;
    }
    final key = '$caseId|$status';
    if (_seen.contains(key)) {
      _log('duplicate push ignored case=$caseId status=$status');
      return false;
    }
    _seen.add(key);
    if (_seen.length > _seenLimit) _seen.removeAt(0);
    _lastPushAt = DateTime.now();
    _log('T6 push received case=$caseId status=$status');
    final kind = data['kind'];
    _emit(
      GuardianCaseEvent(
        source: GuardianEventSource.push,
        caseId: caseId,
        status: status,
        kind: kind is String ? kind : null,
      ),
    );
    return true;
  }

  /// Recovery refresh on app resume. Skipped when a push was just processed,
  /// so a notification tap (which resumes the app AND delivers the message)
  /// does not make every screen fetch twice.
  void resume() {
    final lastPush = _lastPushAt;
    if (lastPush != null &&
        DateTime.now().difference(lastPush) < const Duration(seconds: 2)) {
      return;
    }
    _log('resume: recovery refresh');
    _emit(const GuardianCaseEvent(source: GuardianEventSource.resume));
  }

  /// Generic "something may have changed" signal (no case context).
  void signal() =>
      _emit(const GuardianCaseEvent(source: GuardianEventSource.manual));

  /// Attaches the app-lifecycle observer that turns a return to the
  /// foreground into [resume]. Idempotent: called on every authenticated
  /// Guardian build (see GuardianGate), effective once until [reset].
  void ensureLifecycle() {
    _lifecycle ??= AppLifecycleListener(onResume: resume);
  }

  /// Logout / account switch: forget processed events and stop observing
  /// the lifecycle, so the next Guardian's session starts clean.
  void reset() {
    _seen.clear();
    _lastPushAt = null;
    _last = null;
    _lifecycle?.dispose();
    _lifecycle = null;
  }

  @visibleForTesting
  bool get debugHasLifecycleListener => _lifecycle != null;

  void _emit(GuardianCaseEvent event) {
    _last = event;
    notifyListeners();
  }

  static void _log(String message) {
    if (kDebugMode) debugPrint('Radd timing: $message');
  }
}

/// Runs one screen's authoritative refetch at a time. A signal that arrives
/// while a refetch is in flight (a push and a resume almost together, or two
/// pushes) does not start a parallel request -- it schedules exactly one
/// more run after the current one, so the newest server state is still
/// picked up without duplicate requests. Failures are swallowed: a transient
/// background refresh failure keeps the last valid state on screen (the
/// caller's own error handling covers its initial load).
class CoalescedRefresh {
  CoalescedRefresh(this.label);
  final String label;
  Future<void>? _running;
  bool _again = false;

  bool get inFlight => _running != null;

  Future<void> run(Future<void> Function() action) {
    if (_running != null) {
      _again = true;
      return _running!;
    }
    return _running = _loop(action);
  }

  Future<void> _loop(Future<void> Function() action) async {
    try {
      do {
        _again = false;
        final clock = Stopwatch()..start();
        GuardianCaseEvents._log('T7 refetch begin screen=$label');
        try {
          await action();
          GuardianCaseEvents._log(
            'T8 refetch done screen=$label ms=${clock.elapsedMilliseconds}',
          );
        } catch (error) {
          GuardianCaseEvents._log(
            'refetch failed screen=$label (${error.runtimeType}); last state kept',
          );
        }
      } while (_again);
    } finally {
      _running = null;
    }
  }
}
