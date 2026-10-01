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
import 'package:radd/features/volunteer/presentation/volunteer_policy_screen.dart';

import 'volunteer_location_test.dart' show LocationPlatform;
import 'volunteer_navigation_test.dart' show harness;

void main() {
  for (final language in ['ar', 'en']) {
    testWidgets(
      'Operational notice precedes real permission; all current location checks remain ($language)',
      (tester) async {
        tester.view.physicalSize = const Size(600, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final previous = GeolocatorPlatform.instance;
        final platform = LocationPlatform();
        GeolocatorPlatform.instance = platform;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        addTearDown(() async {
          GeolocatorPlatform.instance = previous;
          await platform.positions.close();
          await platform.services.close();
        });
        final writes = <String>[];
        final repo = ApiVolunteerRepository(
          token: () async => 'test',
          baseUrl: 'http://test',
          client: MockClient((request) async {
            if (request.method != 'GET') writes.add(request.url.path);
            return http.Response(
              jsonEncode(
                request.url.path == '/v1/volunteer'
                    ? {
                        'uid': 'test',
                        'full_name': 'Test',
                        'volunteer_id': 'TEST',
                        'active': true,
                        'assigned': true,
                        'event_id': 'test-event',
                        'terms_version': 'obsolete',
                      }
                    : [],
              ),
              200,
            );
          }),
        );
        addTearDown(repo.dispose);
        await repo.loadProfile();
        Future<void> mount() async {
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
          await tester.pumpAndSettle();
        }

        Future<void> settle() async {
          for (var i = 0; i < 15; i++) {
            await tester.runAsync(() => Future<void>.delayed(Duration.zero));
            await tester.pump();
          }
          await tester.pumpAndSettle();
        }

        await mount();
        final s = AppLocalizations.of(
          tester.element(find.byType(VolunteerWorkspace)),
        )!;
        expect(find.text(s.vLocationPrivacyTitle), findsOneWidget);
        expect(find.text(s.vLocationPrivacyBody), findsOneWidget);
        expect(find.byType(CheckboxListTile), findsNothing);
        expect(
          find.text(language == 'ar' ? 'شروط الاستخدام' : 'Terms of Use'),
          findsNothing,
        );
        expect(platform.requests, 0);
        expect(platform.streams, 0);
        await tester.tap(find.text(s.vViewPrivacyPolicy));
        await tester.pumpAndSettle();
        expect(find.byType(VolunteerPolicyScreen), findsOneWidget);
        expect(find.text(s.vPrivacyTitle), findsOneWidget);
        expect(
          Directionality.of(tester.element(find.byType(VolunteerPolicyScreen))),
          language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        // Inspect the complete localized document, including off-screen content.
        for (final internal in [
          'draft',
          'draft-2026-09',
          'Development / academic',
          'project owner',
          'not legally reviewed',
          'TODO',
          'مسودة',
          'مالك المشروع',
        ]) {
          expect(s.vPrivacyDocument.contains(internal), isFalse);
          expect(find.textContaining(internal), findsNothing);
        }
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text(s.continueLabel));
        await settle();
        expect(platform.requests, 1);
        expect(platform.permission, LocationPermission.denied);
        expect(find.text(s.vLocationPrivacyTitle), findsOneWidget);
        expect(platform.streams, 0);
        // Continue did not invent a permission grant or write any consent.
        expect(writes.where((path) => path.contains('consent')), isEmpty);
        platform.response = LocationPermission.whileInUse;
        await tester.tap(find.text(s.continueLabel));
        await settle();
        expect(platform.requests, 2);
        expect(find.text(s.vLocationPrivacyTitle), findsNothing);
        // No estimate has arrived: ordinary participation still works.
        await tester.tap(find.byKey(const ValueKey('radd-tab-2')));
        await tester.pumpAndSettle();
        expect(find.text(s.vOpenCamera), findsOneWidget);
        await repo.refresh();
        await tester.pumpAndSettle();
        expect(find.text(s.vLocationPrivacyTitle), findsNothing);
        platform.enabled = false;
        platform.services.add(ServiceStatus.disabled);
        await tester.pumpAndSettle();
        expect(find.text(s.vLocationServicesDisabled), findsOneWidget);
        expect(find.text(s.vOpenCamera), findsNothing);
        platform.enabled = true;
        platform.services.add(ServiceStatus.enabled);
        await tester.pumpAndSettle();
        expect(find.text(s.vLocationPrivacyTitle), findsNothing);
        // Existing notice presentation cannot bypass revoked permission on resume.
        platform.permission = LocationPermission.denied;
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await settle();
        expect(find.text(s.vLocationPrivacyTitle), findsOneWidget);
        expect(find.text(s.vOpenCamera), findsNothing);
        platform.permission = LocationPermission.whileInUse;
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await mount();
        await settle();
        expect(find.text(s.vLocationPrivacyTitle), findsNothing);
        expect(platform.requests, 2);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
