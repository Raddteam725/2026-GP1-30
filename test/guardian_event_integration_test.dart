import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radd/features/guardian/data/guardian_push_service.dart';
import 'package:radd/features/guardian/data/coalesced_refresh.dart';
import 'package:radd/features/volunteer/domain/volunteer_notification_event.dart';
import 'package:radd/features/volunteer/domain/volunteer_models.dart';

void main() {
  final channel = GuardianPushRefresh.instance;
  setUp(channel.reset);
  tearDown(channel.reset);
  Map<String, dynamic> event(String id, {String status = 'report_received'}) =>
      {'role': 'guardian', 'case_id': id, 'status': status};
  test('Guardian contract validation, role, concerns and bounded dedup', () {
    for (final invalid in [
      <String, dynamic>{},
      {...event('x'), 'role': 'volunteer'},
      event(''),
      event('a/b'),
      event('x', status: 'nonsense'),
    ]) {
      expect(channel.acceptPush(invalid), isFalse);
    }
    expect(
      channel.acceptPush({...event('x'), 'notification_id': 'stable'}),
      isTrue,
    );
    expect(channel.concerns('x'), isTrue);
    expect(channel.concerns('other'), isFalse);
    expect(
      channel.acceptPush({...event('x'), 'notification_id': 'different'}),
      isFalse,
    );
    expect(channel.acceptPush(event('x', status: 'match_confirmed')), isTrue);
    for (var i = 0; i < 300; i++) {
      channel.acceptPush(event('case-$i'));
    }
    expect(channel.acceptPush(event('x')), isTrue);
    channel.ping();
    expect(channel.concerns('anything'), isTrue);
  });
  test('One active fetch and one pending follow-up, including resume after failure', () async {
    final refresh = CoalescedRefresh();
    final blocked = Completer<void>();
    var calls = 0, active = 0, peak = 0;
    Future<void> action() async {
      calls++;
      active++;
      if (active > peak) peak = active;
      try {
        if (calls == 1) {
          await blocked.future;
          throw StateError('offline');
        }
      } finally {
        active--;
      }
    }

    void listener() {
      refresh.run(action);
    }

    channel.addListener(listener);
    addTearDown(() => channel.removeListener(listener));
    channel.acceptPush(event('x'));
    channel.didChangeAppLifecycleState(AppLifecycleState.resumed);
    channel.ping();
    blocked.complete();
    await refresh.run(action);
    expect(calls, 2);
    expect(peak, 1);
    channel.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);
    expect(calls, 3);
  });
  test(
    'A synchronous refresh failure cannot leave the coalescer stuck',
    () async {
      final refresh = CoalescedRefresh();
      await refresh.run(() => throw StateError('offline'));
      var recovered = false;
      await refresh.run(() async {
        recovered = true;
      });
      expect(recovered, isTrue);
    },
  );
  for (final status in ['cancelled', 'resolved']) {
    test(
      'Compatibility $status normalizes meaning while preserving source ID',
      () {
        final canonical = VolunteerNotificationEvent.fromData({
          'role': 'volunteer',
          'case_id': 'RD-one',
          'kind': status,
          'notification_id': 'original',
        });
        final alias = VolunteerNotificationEvent.fromData({
          'role': 'volunteer',
          'case_id': 'RD-one',
          'kind': 'case_closed',
          'status': status,
          'notification_id': 'legacy',
        });
        expect(alias!.id, 'legacy');
        expect(alias.kind, canonical!.kind);
        expect(alias.opensCase, isFalse);
        final dedup = VolunteerNotificationDeduplicator();
        expect(dedup.accept(canonical), isTrue);
        expect(dedup.accept(alias), isFalse);
      },
    );
  }
  test('Unknown closure never becomes New Case; reunited is preserved', () {
    for (final status in [null, '', 'reunited', 'transferred_to_authority']) {
      expect(
        VolunteerNotificationEvent.fromData({
          'role': 'volunteer',
          'case_id': 'x',
          'kind': 'case_closed',
          'status': status,
        }),
        isNull,
      );
    }
    expect(
      VolunteerNotificationEvent.parseKind('reunited', 'reunited'),
      AlertKind.reunited,
    );
  });
}
