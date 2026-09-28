import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:radd/core/localization/generated/app_localizations.dart';
import 'package:radd/features/volunteer/data/api_volunteer_repository.dart';
import 'package:radd/features/volunteer/presentation/volunteer_workspace.dart';

import 'volunteer_navigation_test.dart' show harness;
import 'volunteer_location_test.dart' show LocationPlatform;

void main() {
  for (final language in ['en', 'ar']) {
    for (final status in [
      'identification_in_progress',
      'identity_confirmed',
      'awaiting_guardian_verification',
      'reunited',
    ]) {
      testWidgets(
        'Stored standalone $status resumes without Missing Case ($language)',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          final old = GeolocatorPlatform.instance;
          final location = LocationPlatform()
            ..permission = LocationPermission.whileInUse;
          GeolocatorPlatform.instance = location;
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          addTearDown(() async {
            GeolocatorPlatform.instance = old;
            await location.positions.close();
            await location.services.close();
          });
          var storedStatus = status;
          final writes = <String>[];
          Map<String, dynamic> report() => {
            'id': 'FR-resume',
            'created_at': '2026-09-28T08:00:00Z',
            'status': storedStatus,
            'found_status': storedStatus,
            'case_id': null,
            'photo_available': false,
            if (storedStatus == 'reunited')
              'handed_over_at': '2026-09-28T09:00:00Z',
            if (![
              'identification_in_progress',
              'reunited',
            ].contains(storedStatus))
              'person': {
                'id': 'person',
                'full_name': 'Test Person',
                'age': 7,
                'gender': 'female',
                'guardian': {'full_name': 'Guardian', 'phone': '0500000000'},
              },
          };
          final repo = ApiVolunteerRepository(
            token: () async => 'test',
            baseUrl: 'http://test',
            client: MockClient((request) async {
              final path = request.url.path;
              if (request.method != 'GET' &&
                  !path.contains('fcm-registrations')) {
                writes.add(path);
              }
              if (path == '/v1/volunteer') {
                return http.Response(
                  jsonEncode({
                    'uid': 'test',
                    'full_name': 'Volunteer',
                    'volunteer_id': 'TEST',
                    'active': true,
                    'consent_current': true,
                    'assigned': true,
                    'event_id': 'event',
                  }),
                  200,
                );
              }
              if (path.endsWith('/registered-photo')) {
                return http.Response('', 404);
              }
              if (path.endsWith('/found-reports/FR-resume')) {
                return http.Response(jsonEncode(report()), 200);
              }
              // Stale list card deliberately survives completion; detail is authoritative.
              if (path.endsWith('/found-reports')) {
                return http.Response(jsonEncode([report()]), 200);
              }
              return http.Response('[]', 200);
            }),
          );
          addTearDown(repo.dispose);
          Future<void> mount() async {
            await repo.loadProfile();
            await tester.pumpWidget(
              harness(
                VolunteerWorkspace(
                  account: repo.account!,
                  repository: repo,
                  onLogout: () async {},
                ),
                language,
              ),
            );
            for (var i = 0; i < 12; i++) {
              await tester.runAsync(() => Future<void>.delayed(Duration.zero));
              await tester.pump();
            }
            await tester.tap(find.byKey(const ValueKey('radd-tab-2')));
            await tester.pumpAndSettle();
            await tester.scrollUntilVisible(
              find.text('FR-resume'),
              250,
              scrollable: find.byType(Scrollable).last,
            );
            await tester.tap(find.text('FR-resume'));
            await tester.pumpAndSettle();
          }

          await mount();
          final s = AppLocalizations.of(
            tester.element(find.byType(VolunteerWorkspace)),
          )!;
          String expected() => switch (storedStatus) {
            'identity_confirmed' => s.vGuardianDetails,
            'awaiting_guardian_verification' => s.vScanInstruction,
            'reunited' => s.vCompleted,
            _ => s.vFindWithAi,
          };
          await tester.scrollUntilVisible(
            find.text(expected()),
            150,
            scrollable: find.byType(Scrollable).last,
          );
          expect(find.text(expected()), findsOneWidget);
          expect(writes, isEmpty);
          // Recreating the workspace must reconstruct exactly the same server state.
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          await mount();
          await tester.scrollUntilVisible(
            find.text(expected()),
            150,
            scrollable: find.byType(Scrollable).last,
          );
          expect(find.text(expected()), findsOneWidget);
          if (status == 'identity_confirmed') {
            storedStatus = 'awaiting_guardian_verification';
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.paused,
            );
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.resumed,
            );
            for (var i = 0; i < 15; i++) {
              await tester.runAsync(() => Future<void>.delayed(Duration.zero));
              await tester.pump();
            }
            await tester.pumpAndSettle();
            expect(find.text(s.vScanInstruction), findsOneWidget);
            expect(find.text(s.vGuardianDetails), findsNothing);
          }
          expect(writes, isEmpty);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );
    }
  }
}
