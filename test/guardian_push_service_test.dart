import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:radd/features/guardian/data/guardian_push_service.dart';

import 'support/guardian_fakes.dart';

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
      expect(repo.lastRegisteredLocale, isNull);
    });

    test('a temporary sync failure (e.g. offline) does not throw, and is '
        'corrected the next time syncLocale runs', () async {
      GuardianPushService.debugSeedToken('device-token', 'en');
      repo.failNextFcmRegister = true;
      await GuardianPushService.syncLocale(repo, 'ar');
      expect(repo.lastRegisteredLocale, isNull);
      expect(GuardianPushService.debugLastSyncedLocale, 'en');
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
      await GuardianPushService.handleLogout(repo);
      expect(repo.unregisteredFcmTokens, isEmpty);
      expect(GuardianPushService.debugLastKnownToken, isNull);
      expect(GuardianPushService.debugLastSyncedLocale, isNull);
    });

    test('after logout, a following initialize() for a different guardian is '
        'no longer blocked by the previous one-time guard', () async {
      GuardianPushService.debugSeedToken('device-token', 'en');
      await GuardianPushService.handleLogout(repo);
      GuardianPushService.debugSeedToken('next-guardian-token', 'en');
      expect(GuardianPushService.debugLastKnownToken, 'next-guardian-token');
    });
  });

  group('token-refresh listener lifecycle', () {
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
      final a = StreamController<String>.broadcast();
      addTearDown(a.close);
      GuardianPushService.debugSeedTokenRefreshSubscription(
        a.stream.listen((_) {}),
      );
      expect(a.hasListener, isTrue);

      await GuardianPushService.handleLogout(repo);
      expect(a.hasListener, isFalse);
      expect(
        GuardianPushService.debugHasActiveTokenRefreshSubscription,
        isFalse,
      );

      final b = StreamController<String>.broadcast();
      addTearDown(b.close);
      GuardianPushService.debugSeedTokenRefreshSubscription(
        b.stream.listen((_) {}),
      );
      expect(
        GuardianPushService.debugHasActiveTokenRefreshSubscription,
        isTrue,
      );

      await GuardianPushService.handleLogout(repo);
      expect(b.hasListener, isFalse);

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
