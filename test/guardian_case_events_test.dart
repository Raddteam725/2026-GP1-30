import 'package:flutter_test/flutter_test.dart';
import 'package:radd/features/guardian/data/guardian_case_events.dart';
import 'package:radd/features/guardian/data/guardian_push_service.dart';

import 'support/guardian_fakes.dart';

/// The Guardian-side half of the real-time contract, without Firebase:
/// what counts as a valid case-update signal, how duplicates are dropped
/// without ever hiding a newer status, and how refetches are coalesced.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // AppLifecycleListener
  final events = GuardianCaseEvents.instance;
  setUp(events.reset);
  tearDown(events.reset);

  Map<String, Object?> push(String caseId, String status, {String? role}) => {
    'role': ?role,
    'kind': 'status_update',
    'status': status,
    'case_id': caseId,
    'event_id': 'test-event',
  };

  group('acceptPush', () {
    test('accepts a Guardian contract message and exposes its case', () {
      var notified = 0;
      events.addListener(() => notified++);
      expect(events.acceptPush(push('RD-1', 'search_in_progress')), isTrue);
      expect(notified, 1);
      expect(events.last!.source, GuardianEventSource.push);
      expect(events.last!.caseId, 'RD-1');
      expect(events.last!.status, 'search_in_progress');
      expect(events.last!.kind, 'status_update');
      expect(events.last!.concerns('RD-1'), isTrue);
      expect(events.last!.concerns('RD-2'), isFalse);
    });

    test('accepts role=guardian, rejects a Volunteer message', () {
      expect(
        events.acceptPush(push('RD-1', 'search_in_progress', role: 'guardian')),
        isTrue,
      );
      expect(
        events.acceptPush(
          push('RD-2', 'search_in_progress', role: 'volunteer'),
        ),
        isFalse,
      );
      expect(events.last!.caseId, 'RD-1');
    });

    test('rejects a message outside the contract without notifying', () {
      var notified = 0;
      events.addListener(() => notified++);
      expect(events.acceptPush({'kind': 'status_update'}), isFalse);
      expect(events.acceptPush({'case_id': '', 'status': 'x'}), isFalse);
      expect(events.acceptPush({'case_id': 'RD-1', 'status': 7}), isFalse);
      expect(events.acceptPush({'case_id': 'RD-1'}), isFalse);
      expect(notified, 0);
      expect(events.last, isNull);
    });

    test('a duplicate delivery of the same case+status is dropped', () {
      var notified = 0;
      events.addListener(() => notified++);
      expect(events.acceptPush(push('RD-1', 'search_in_progress')), isTrue);
      expect(events.acceptPush(push('RD-1', 'search_in_progress')), isFalse);
      expect(events.acceptPush(push('RD-1', 'search_in_progress')), isFalse);
      expect(notified, 1);
    });

    test('a newer status for the same case is never suppressed', () {
      var notified = 0;
      events.addListener(() => notified++);
      expect(events.acceptPush(push('RD-1', 'search_in_progress')), isTrue);
      expect(events.acceptPush(push('RD-1', 'match_confirmed')), isTrue);
      expect(
        events.acceptPush(push('RD-1', 'awaiting_guardian_verification')),
        isTrue,
      );
      expect(events.acceptPush(push('RD-1', 'reunited')), isTrue);
      // ...and the same status for a DIFFERENT case is its own event.
      expect(events.acceptPush(push('RD-2', 'search_in_progress')), isTrue);
      expect(notified, 5);
    });

    test('the de-duplication memory is bounded', () {
      for (var i = 0; i < 400; i++) {
        expect(events.acceptPush(push('RD-$i', 'report_received')), isTrue);
      }
      // The oldest entries were evicted, so the very first one is accepted
      // again (bounded memory), while recent ones are still de-duplicated.
      expect(events.acceptPush(push('RD-0', 'report_received')), isTrue);
      expect(events.acceptPush(push('RD-399', 'report_received')), isFalse);
    });
  });

  group('resume / signal / reset', () {
    test('resume emits a case-less recovery event', () {
      events.resume();
      expect(events.last!.source, GuardianEventSource.resume);
      expect(events.last!.caseId, isNull);
      expect(events.last!.concerns('anything'), isTrue);
    });

    test('a resume right after a push does not double-refetch', () {
      var notified = 0;
      events.addListener(() => notified++);
      events.acceptPush(push('RD-1', 'search_in_progress'));
      events.resume(); // e.g. the notification tap that also resumed the app
      expect(notified, 1);
    });

    test('GuardianPushRefresh.ping is a generic signal through the same '
        'channel', () {
      GuardianPushRefresh.instance.ping();
      expect(events.last!.source, GuardianEventSource.manual);
      expect(events.last!.caseId, isNull);
    });

    test('logout resets processed events and the lifecycle observer', () async {
      events.acceptPush(push('RD-1', 'search_in_progress'));
      events.ensureLifecycle();
      expect(events.debugHasLifecycleListener, isTrue);
      await GuardianPushService.handleLogout(TestRepository());
      expect(events.debugHasLifecycleListener, isFalse);
      expect(events.last, isNull);
      // The next Guardian's session starts with an empty memory.
      expect(events.acceptPush(push('RD-1', 'search_in_progress')), isTrue);
    });

    test('ensureLifecycle is idempotent', () {
      events.ensureLifecycle();
      events.ensureLifecycle();
      expect(events.debugHasLifecycleListener, isTrue);
      events.reset();
      expect(events.debugHasLifecycleListener, isFalse);
    });
  });

  group('CoalescedRefresh', () {
    test('a signal during an in-flight refetch runs exactly one more, never '
        'a parallel request', () async {
      final refresh = CoalescedRefresh('test');
      var started = 0, concurrent = 0, peak = 0;
      Future<void> action() async {
        started++;
        concurrent++;
        peak = peak > concurrent ? peak : concurrent;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        concurrent--;
      }

      final first = refresh.run(action);
      refresh.run(action);
      refresh.run(action);
      refresh.run(action);
      await first;
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(started, 2);
      expect(peak, 1);
      expect(refresh.inFlight, isFalse);
    });

    test(
      'a failing refetch is swallowed and does not block later ones',
      () async {
        final refresh = CoalescedRefresh('test');
        await refresh.run(() async => throw StateError('offline'));
        var ran = false;
        await refresh.run(() async => ran = true);
        expect(ran, isTrue);
      },
    );
  });
}
