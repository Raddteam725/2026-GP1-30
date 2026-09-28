import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:radd/core/localization/generated/app_localizations.dart';
import 'package:radd/features/volunteer/data/api_volunteer_repository.dart';
import 'package:radd/features/volunteer/domain/volunteer_models.dart';
import 'package:radd/features/volunteer/presentation/volunteer_workspace.dart';

import 'volunteer_navigation_test.dart' show harness;
import 'support/guardian_fakes.dart' show TestAuth;

import 'package:radd/features/guardian/data/guardian_api.dart';

import 'volunteer_location_test.dart' show LocationPlatform;

void main() {
  testWidgets('Fresh API profile with assignment authorizes the Digital ID', (
    tester,
  ) async {
    final auth = TestAuth()..active = true;
    addTearDown(auth.events.close);
    for (var session = 0; session < 2; session++) {
      // A fresh API/model per launch; the authenticated session persists.
      expect(await auth.restoreSession(), isTrue);
      final roles = GuardianApi(
        token: () async => 'test-token',
        baseUrl: 'http://test',
        client: MockClient((request) async {
          expect(request.url.path, '/v1/session');
          expect(request.headers['Authorization'], 'Bearer test-token');
          return http.Response('{"role":"volunteer"}', 200);
        }),
      );
      expect(await roles.accountRole(), 'volunteer');
      final repo = ApiVolunteerRepository(
        token: () async => 'test-token',
        baseUrl: 'http://test',
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'uid': 'test-volunteer',
              'full_name': 'Test Volunteer',
              'volunteer_id': 'V-TEST',
              'active': true,
              'consent_current': true,
              'assigned': true,
              'event_id': 'active-test-event',
            }),
            200,
          ),
        ),
      );
      await repo.loadProfile();
      expect(repo.account!.eventAuthorized, isTrue);
      expect(repo.account!.eventId, 'active-test-event');
      await tester.pumpWidget(
        harness(
          Scaffold(body: VolunteerBadgeCard(account: repo.account!)),
          'en',
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final s = AppLocalizations.of(
        tester.element(find.byType(VolunteerBadgeCard)),
      )!;
      expect(find.text(s.vEventAuthorized), findsWidgets);
      expect(find.text(s.vEventUnassigned), findsNothing);
      await tester.pumpWidget(const SizedBox());
      repo.dispose();
    }
  });

  testWidgets(
    'Removal stops background location, clears data and reassignment restores access',
    (tester) async {
      final previous = GeolocatorPlatform.instance;
      final platform = LocationPlatform()
        ..permission = LocationPermission.whileInUse;
      GeolocatorPlatform.instance = platform;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      addTearDown(() async {
        GeolocatorPlatform.instance = previous;
        await platform.positions.close();
        await platform.services.close();
      });
      var assigned = true;
      final repo = ApiVolunteerRepository(
        token: () async => 'test-token',
        baseUrl: 'http://test',
        client: MockClient(
          (request) async => http.Response(
            jsonEncode(
              request.url.path == '/v1/volunteer'
                  ? {
                      'uid': 'test-volunteer',
                      'full_name': 'Volunteer',
                      'volunteer_id': 'V-1',
                      'active': true,
                      'consent_current': true,
                      'assigned': assigned,
                      'event_id': 'test-event',
                    }
                  : [],
            ),
            200,
          ),
        ),
      );
      addTearDown(repo.dispose);
      await repo.loadProfile();
      await tester.pumpWidget(
        harness(
          VolunteerWorkspace(
            account: repo.account!,
            repository: repo,
            onLogout: () async {},
          ),
          'en',
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      Future<void> drainPlatformCancellation() async {
        for (var i = 0; i < 10; i++) {
          await tester.runAsync(() async {
            await Future<void>.delayed(Duration.zero);
          });
          await tester.pump();
        }
      }

      await drainPlatformCancellation();
      expect(find.text('Manual Review'), findsNothing);
      expect(find.text('Report Found Individual'), findsWidgets);
      expect(
        (platform.lastSettings as AndroidSettings).foregroundNotificationConfig,
        isNotNull,
        reason:
            'Lifecycle: ${tester.binding.lifecycleState}; streams: ${platform.streams}',
      );
      assigned = false;
      unawaited(
        Navigator.of(tester.element(find.byType(VolunteerWorkspace)))
            .push<void>(
              MaterialPageRoute(
                builder: (_) => const Scaffold(body: Text('Protected capture')),
              ),
            ),
      );
      await tester.pumpAndSettle();
      await repo.refresh();
      await tester.pumpAndSettle();
      expect(find.text('Protected capture'), findsNothing);
      expect(find.text('Not Assigned to Current Event'), findsOneWidget);
      expect(platform.positions.hasListener, isFalse);
      expect(repo.cases, isEmpty);
      expect(repo.account!.active, isTrue);
      assigned = true;
      await repo.refresh();
      await drainPlatformCancellation();
      await tester.pumpAndSettle();
      await drainPlatformCancellation();
      expect(find.text('Manual Review'), findsNothing);
      expect(find.text('Report Found Individual'), findsWidgets);
      expect(platform.positions.hasListener, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  for (final language in ['en', 'ar']) {
    testWidgets(
      'Digital ID separates account enablement from assignment in $language',
      (tester) async {
        for (final assigned in [true, false]) {
          for (final active in [true, false]) {
            await tester.pumpWidget(
              harness(
                Scaffold(
                  body: SingleChildScrollView(
                    child: VolunteerBadgeCard(
                      account: VolunteerAccount(
                        uid: 'test',
                        name: const LocalizedData('Name', 'اسم'),
                        volunteerId: 'V-1',
                        active: active,
                        assigned: assigned,
                        eventId: 'event',
                      ),
                    ),
                  ),
                ),
                language,
              ),
            );
            await tester.pump(const Duration(milliseconds: 100));
            final s = AppLocalizations.of(
              tester.element(find.byType(VolunteerBadgeCard)),
            )!;
            expect(
              find.text(assigned ? s.vEventAuthorized : s.vEventUnassigned),
              findsWidgets,
            );
            expect(tester.takeException(), isNull);
          }
        }
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  test(
    'Missing assignment fields fail closed and do not fetch event data',
    () async {
      final paths = <String>[];
      final repo = ApiVolunteerRepository(
        token: () async => 'test-token',
        baseUrl: 'http://test',
        client: MockClient((request) async {
          paths.add(request.url.path);
          return http.Response(
            jsonEncode({
              'uid': 'test',
              'full_name': 'Name',
              'volunteer_id': 'V-1',
              'active': true,
            }),
            200,
          );
        }),
      );
      addTearDown(repo.dispose);
      await repo.refresh();
      expect(repo.account!.eventAuthorized, isFalse);
      expect(paths, ['/v1/volunteer']);
      await expectLater(repo.loadProfiles(), throwsStateError);
      expect(paths, ['/v1/volunteer']);
    },
  );
}
