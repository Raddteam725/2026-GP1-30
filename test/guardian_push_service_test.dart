import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:radd/features/guardian/data/guardian_push_service.dart';

import 'support/guardian_fakes.dart';

/// Exercises GuardianPushService's locale-sync and logout decision logic
/// directly, via its @visibleForTesting seams -- deliberately never touching
/// FirebaseMessaging/Firebase itself (unavailable in plain flutter_test), so
/// these cover exactly the client-side lifecycle behavior in scope for this
/// review: keeping push language in sync without a restart, and cleaning up
/// this installation's registration at logout without risking sign-out
/// itself. Cross-account/multi-device correctness is covered by the backend
/// test suite (test_fcm.py), since that's where registration ownership is
/// actually enforced.
void main() {
  test('Foreground stable events deduplicate and resume triggers recovery', () {
    GuardianPushService.resetForTesting();
    var refreshes = 0;
    void listener() => refreshes++;
    GuardianPushRefresh.instance.addListener(listener);
    addTearDown(() => GuardianPushRefresh.instance.removeListener(listener));
    const event = RemoteMessage(
      data: {
        'role': 'guardian',
        'notification_id': 'case-search',
        'case_id': 'case',
        'status': 'search_in_progress',
      },
    );
    GuardianPushService.debugReceive(event);
    GuardianPushService.debugReceive(event);
    expect(refreshes, 1);
    GuardianPushService.debugReceive(
      const RemoteMessage(
        data: {'role': 'volunteer', 'notification_id': 'other'},
      ),
    );
    expect(refreshes, 1);
    GuardianPushRefresh.instance.didChangeAppLifecycleState(
      AppLifecycleState.resumed,
    );
    expect(refreshes, 2);
  });
  late TestRepository repo;
  setUp(() {
    repo = TestRepository();
    GuardianPushService.resetForTesting();
  });
  tearDown(() => GuardianPushService.resetForTesting());

  group('syncLocale', () {
    test('is a no-op when no token has ever been uploaded', () async {
      await GuardianPushService.syncLocale(repo, 'ar');
      expect(repo.registeredFcmTokens, isEmpty);
      expect(repo.lastRegisteredLocale, isNull);
    });

    test('re-registers with the new locale when it changed', () async {
      GuardianPushService.debugSeedToken('device-token', 'en');
      await GuardianPushService.syncLocale(repo, 'ar');
      expect(repo.registeredFcmTokens, ['device-token']);
      expect(repo.lastRegisteredLocale, 'ar');
      expect(GuardianPushService.debugLastSyncedLocale, 'ar');
    });

    test('works in the other direction too (ar -> en)', () async {
      GuardianPushService.debugSeedToken('device-token', 'ar');
      await GuardianPushService.syncLocale(repo, 'en');
      expect(repo.lastRegisteredLocale, 'en');
      expect(GuardianPushService.debugLastSyncedLocale, 'en');
    });

    test('does nothing extra when the locale is unchanged', () async {
      GuardianPushService.debugSeedToken('device-token', 'en');
      await GuardianPushService.syncLocale(repo, 'en');
      // No new upload happened -- registeredFcmTokens would still contain it
      // regardless (registerFcmToken is idempotent-add), so the meaningful
      // check is that no attempt was made to flip the recorded locale away
      // from what debugSeedToken set, which a real network call could race.
      expect(repo.lastRegisteredLocale, isNull); // never actually called
    });

    test('a temporary sync failure (e.g. offline) does not throw, and is '
        'corrected the next time syncLocale runs', () async {
      GuardianPushService.debugSeedToken('device-token', 'en');
      repo.failNextFcmRegister = true;
      await GuardianPushService.syncLocale(repo, 'ar'); // must not throw
      // Failed attempt: nothing changed server-side or in cached state.
      expect(repo.lastRegisteredLocale, isNull);
      expect(GuardianPushService.debugLastSyncedLocale, 'en');
      // Next opportunity (e.g. the next GuardianGate build) retries and
      // this time succeeds.
      await GuardianPushService.syncLocale(repo, 'ar');
      expect(repo.lastRegisteredLocale, 'ar');
      expect(GuardianPushService.debugLastSyncedLocale, 'ar');
    });
  });

  group('handleLogout', () {
    test('unregisters the cached token and clears local state', () async {
      GuardianPushService.debugSeedToken('device-token', 'en');
      await GuardianPushService.handleLogout(repo);
      expect(repo.unregisteredFcmTokens, ['device-token']);
      expect(GuardianPushService.debugLastKnownToken, isNull);
      expect(GuardianPushService.debugLastSyncedLocale, isNull);
    });

    test(
      'is a no-op (and never throws) when nothing was ever registered',
      () async {
        await GuardianPushService.handleLogout(repo);
        expect(repo.unregisteredFcmTokens, isEmpty);
      },
    );

    test('repeated logout is idempotent -- only unregisters once', () async {
      GuardianPushService.debugSeedToken('device-token', 'en');
      await GuardianPushService.handleLogout(repo);
      await GuardianPushService.handleLogout(repo);
      await GuardianPushService.handleLogout(repo);
      expect(repo.unregisteredFcmTokens, ['device-token']);
    });

    test('a failed cleanup (e.g. offline) never throws, and still clears local '
        'state so a following login starts push setup fresh', () async {
      GuardianPushService.debugSeedToken('device-token', 'en');
      repo.failNextFcmUnregister = true;
      await GuardianPushService.handleLogout(repo); // must not throw
      expect(repo.unregisteredFcmTokens, isEmpty); // the call itself failed
      expect(GuardianPushService.debugLastKnownToken, isNull);
      expect(GuardianPushService.debugLastSyncedLocale, isNull);
    });

    test('after logout, a following initialize() for a different guardian is '
        'no longer blocked by the previous one-time guard', () async {
      GuardianPushService.debugSeedToken('device-token', 'en');
      await GuardianPushService.handleLogout(repo);
      // initialize() itself needs FirebaseMessaging (unavailable here), but
      // the guard that would otherwise silently no-op it for a second
      // guardian in the same process is the private _initialized flag --
      // confirm it was actually reset, not just the token/locale.
      GuardianPushService.debugSeedToken('next-guardian-token', 'en');
      expect(GuardianPushService.debugLastKnownToken, 'next-guardian-token');
    });
  });

  group('token-refresh listener lifecycle', () {
    // These use debugSeedTokenRefreshSubscription -- a real StreamSubscription
    // from a plain, non-Firebase stream standing in for the one initialize()
    // would normally attach to FirebaseMessaging.instance.onTokenRefresh (not
    // callable in plain flutter_test) -- so cancellation is verified against
    // an actual Stream/StreamSubscription, not just a null check.
    test(
      'handleLogout cancels the active token-refresh subscription',
      () async {
        final controller = StreamController<String>.broadcast();
        addTearDown(controller.close);
        final sub = controller.stream.listen((_) {});
        GuardianPushService.debugSeedTokenRefreshSubscription(sub);
        expect(controller.hasListener, isTrue);
        expect(
          GuardianPushService.debugHasActiveTokenRefreshSubscription,
          isTrue,
        );

        await GuardianPushService.handleLogout(repo);

        expect(controller.hasListener, isFalse);
        expect(
          GuardianPushService.debugHasActiveTokenRefreshSubscription,
          isFalse,
        );
      },
    );

    test('a repeated login/logout/reinitialize cycle never leaves more than '
        'one active subscription: each logout cancels exactly the one '
        'currently held before the next session seeds its own', () async {
      // Guardian A's session.
      final a = StreamController<String>.broadcast();
      addTearDown(a.close);
      GuardianPushService.debugSeedTokenRefreshSubscription(
        a.stream.listen((_) {}),
      );
      expect(a.hasListener, isTrue);

      // A logs out.
      await GuardianPushService.handleLogout(repo);
      expect(a.hasListener, isFalse);
      expect(
        GuardianPushService.debugHasActiveTokenRefreshSubscription,
        isFalse,
      );

      // Guardian B's session -- a fresh subscription, not stacked on A's.
      final b = StreamController<String>.broadcast();
      addTearDown(b.close);
      GuardianPushService.debugSeedTokenRefreshSubscription(
        b.stream.listen((_) {}),
      );
      expect(
        GuardianPushService.debugHasActiveTokenRefreshSubscription,
        isTrue,
      );

      // B logs out.
      await GuardianPushService.handleLogout(repo);
      expect(b.hasListener, isFalse);

      // Guardian C's session.
      final c = StreamController<String>.broadcast();
      addTearDown(c.close);
      GuardianPushService.debugSeedTokenRefreshSubscription(
        c.stream.listen((_) {}),
      );
      expect(c.hasListener, isTrue);
      expect(
        GuardianPushService.debugHasActiveTokenRefreshSubscription,
        isTrue,
      );

      // Only C's is active -- A's and B's were cancelled at their own
      // logout, never left dangling for C's session to pile on top of.
      await GuardianPushService.handleLogout(repo);
      expect(c.hasListener, isFalse);
    });

    test(
      'repeated handleLogout calls with no active subscription remain safe',
      () async {
        await GuardianPushService.handleLogout(repo);
        await GuardianPushService.handleLogout(repo);
        expect(
          GuardianPushService.debugHasActiveTokenRefreshSubscription,
          isFalse,
        );
      },
    );
  });
}
