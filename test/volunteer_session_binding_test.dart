import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:radd/features/volunteer/data/volunteer_session_binding.dart';

void main() {
  test(
    'Normal ID-token refresh renews the same session without ending it',
    () async {
      final stream = StreamController<String?>.broadcast();
      var renewals = 0, ends = 0;
      final binding = bindVolunteerSession(
        stream.stream,
        uid: 'test-user',
        renew: () async {
          renewals++;
        },
        end: () async {
          ends++;
        },
      );
      stream.add('test-user');
      stream.add('test-user');
      await pumpEventQueue();
      expect(renewals, 2);
      expect(ends, 0);
      await binding.cancel();
      await stream.close();
    },
  );
  for (final next in <String?>[null, 'another-account']) {
    test(
      'Logout/account switch ($next) ends the old registration and never revives it',
      () async {
        final stream = StreamController<String?>.broadcast();
        var renewals = 0, ends = 0;
        final binding = bindVolunteerSession(
          stream.stream,
          uid: 'test-user',
          renew: () async {
            renewals++;
          },
          end: () async {
            ends++;
          },
        );
        stream.add('test-user');
        stream.add(next);
        stream.add('test-user');
        await pumpEventQueue();
        expect(renewals, 1);
        expect(ends, 1);
        await binding.cancel();
        final loggedInAgain = bindVolunteerSession(
          stream.stream,
          uid: 'test-user',
          renew: () async {
            renewals++;
          },
          end: () async {
            ends++;
          },
        );
        stream.add('test-user');
        await pumpEventQueue();
        expect(renewals, 2);
        await loggedInAgain.cancel();
        await stream.close();
      },
    );
  }
  test('Auth stream errors stop delivery rather than renewing an unverified session', () async {
    final stream = StreamController<String?>.broadcast();
    var ends = 0, renewals = 0;
    final binding = bindVolunteerSession(
      stream.stream,
      uid: 'test-user',
      renew: () async {
        renewals++;
      },
      end: () async {
        ends++;
      },
    );
    stream.addError(StateError('invalid-session'));
    stream.add('test-user');
    await pumpEventQueue();
    expect(ends, 1);
    expect(renewals, 0);
    await binding.cancel();
    await stream.close();
  });
}
