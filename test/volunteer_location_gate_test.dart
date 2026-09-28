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
import 'package:radd/features/volunteer/presentation/volunteer_consent_screen.dart';

import 'volunteer_location_test.dart' show LocationPlatform;
import 'volunteer_navigation_test.dart' show harness;

void main() {
  for (final language in ['ar', 'en']) {
    testWidgets(
      'Mandatory explanation precedes permission; recovery enforces services ($language)',
      (tester) async {
        tester.view.physicalSize = const Size(600, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final previous = GeolocatorPlatform.instance;
        final platform = LocationPlatform()
          ..response = LocationPermission.whileInUse;
        GeolocatorPlatform.instance = platform;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        addTearDown(() async {
          GeolocatorPlatform.instance = previous;
          await platform.positions.close();
          await platform.services.close();
        });
        var consentAccepted = false;
        final repo = ApiVolunteerRepository(
          token: () async => 'test',
          baseUrl: 'http://test',
          client: MockClient((request) async {
            if (request.url.path.endsWith('/consent')) {
              consentAccepted = true;
              return http.Response('{}', 200);
            }
            return http.Response(
              jsonEncode(
                request.url.path == '/v1/volunteer'
                    ? {
                        'uid': 'test',
                        'full_name': 'Test',
                        'volunteer_id': 'TEST',
                        'active': true,
                        'consent_current': consentAccepted,
                        'required_terms_version': 'draft-2026-09',
                        'required_privacy_version': 'draft-2026-09',
                        'assigned': true,
                        'event_id': 'test-event',
                      }
                    : [],
              ),
              200,
            );
          }),
        );
        addTearDown(repo.dispose);
        await repo.loadProfile();
        await tester.pumpWidget(
          harness(
            VolunteerConsentGate(
              repository: repo,
              onLogout: () async {},
              childBuilder: (_) => VolunteerWorkspace(
                account: repo.account!,
                repository: repo,
                onLogout: () async {},
              ),
            ),
            language,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(VolunteerWorkspace), findsNothing);
        expect(platform.requests, 0);
        expect(platform.streams, 0);
        await tester.scrollUntilVisible(
          find.byType(CheckboxListTile),
          250,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pump();
        final accept = find.byKey(const Key('volunteer-consent-continue'));
        await tester.ensureVisible(accept);
        await tester.tap(accept);
        await tester.pumpAndSettle();
        final s = AppLocalizations.of(
          tester.element(find.byType(VolunteerWorkspace)),
        )!;
        expect(find.text(s.vLocationHelp), findsOneWidget);
        expect(platform.requests, 0);
        await tester.tap(find.text(s.vAllowLocation));
        for (var i = 0; i < 15; i++) {
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pump();
        }
        expect(platform.requests, 1);
        expect(find.text(s.vLocationRequired), findsNothing);
        // No GPS fix was provided: permission and services still permit access.
        await tester.tap(find.byKey(const ValueKey('radd-tab-2')));
        await tester.pumpAndSettle();
        expect(find.text(s.vOpenCamera), findsOneWidget);
        expect(find.text(s.vLocationRequired), findsNothing);
        platform.enabled = false;
        platform.services.add(ServiceStatus.disabled);
        await tester.pumpAndSettle();
        expect(find.text(s.vLocationServicesDisabled), findsOneWidget);
        expect(find.text(s.vOpenCamera), findsNothing);
        platform.enabled = true;
        platform.services.add(ServiceStatus.enabled);
        await tester.pumpAndSettle();
        expect(find.text(s.vLocationRequired), findsNothing);
        expect(platform.requests, 1);
        // Re-consent removes the workspace and stops existing location access.
        consentAccepted = false;
        await repo.loadProfile();
        await tester.pumpAndSettle();
        expect(find.byType(VolunteerConsentScreen), findsOneWidget);
        expect(find.byType(VolunteerWorkspace), findsNothing);
        expect(platform.positions.hasListener, isFalse);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
