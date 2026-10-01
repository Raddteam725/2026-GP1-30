import 'dart:convert';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:radd/core/localization/generated/app_localizations.dart';
import 'package:radd/features/volunteer/data/api_volunteer_repository.dart';
import 'package:radd/features/volunteer/presentation/volunteer_workspace.dart';

import 'volunteer_navigation_test.dart' show harness, press;
import 'volunteer_location_test.dart' show LocationPlatform;
import 'volunteer_camera_lifecycle_test.dart' show FailingCamera;

class CaptureCamera extends FailingCamera {
  final bytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAE0lEQVR4nGP8//8/AwwwwVl4OQCWbgMF7ZjH1AAAAABJRU5ErkJggg==',
  );
  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int id) => Stream.value(
    CameraInitializedEvent(
      id,
      640,
      480,
      ExposureMode.auto,
      false,
      FocusMode.auto,
      false,
    ),
  );
  @override
  Future<void> initializeCamera(
    int id, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {}
  @override
  Widget buildPreview(int cameraId) => const SizedBox.expand();
  @override
  Future<XFile> takePicture(int cameraId) async =>
      XFile.fromData(bytes, name: 'test.png', mimeType: 'image/png');
  @override
  Future<void> dispose(int id) async {}
}

void main() {
  for (final language in ['en', 'ar']) {
    testWidgets(
      'Manual entry confirms a photo-free report only after explicit confirmation ($language)',
      (tester) async {
        final previousCamera = CameraPlatform.instance;
        final previousLocation = GeolocatorPlatform.instance;
        final location = LocationPlatform()
          ..permission = LocationPermission.whileInUse;
        GeolocatorPlatform.instance = location;
        CameraPlatform.instance = CaptureCamera();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        addTearDown(() async {
          CameraPlatform.instance = previousCamera;
          GeolocatorPlatform.instance = previousLocation;
          await location.positions.close();
          await location.services.close();
        });
        var aiRequests = 0, created = 0;
        final repo = ApiVolunteerRepository(
          token: () async => 'unit-test',
          baseUrl: 'http://test',
          client: MockClient((request) async {
            final path = request.url.path;
            Object response = [];
            if (path == '/v1/volunteer') {
              response = {
                'uid': 'test',
                'full_name': 'Test',
                'volunteer_id': 'TEST',
                'active': true,
                'consent_current': true,
                'assigned': true,
                'event_id': 'test-event',
              };
            }
            final person = {
              'id': 'profile-test',
              'full_name': 'Test Person',
              'age': 10,
              'gender': 'female',
              'relationship': 'daughter',
            };
            if (path.endsWith('/profiles')) response = [person];
            if (path.endsWith('/profiles/profile-test')) {
              response = {...person, 'confirmation_available': false};
            }
            if (path.endsWith('/profiles/profile-test/photo')) {
              return http.Response.bytes(CaptureCamera().bytes, 200);
            }
            if (path.endsWith('/found-reports/manual') &&
                request.method == 'POST') {
              created++;
              final body = jsonDecode(request.body);
              expect(body.keys, unorderedEquals(['profile_id', 'request_id']));
              expect(body['profile_id'], 'profile-test');
              response = {
                'id': 'FR-manual',
                'created_at': '2026-09-28T08:00:00Z',
                'status': 'identity_confirmed',
                'photo_available': false,
                'person': {
                  ...person,
                  'guardian': {
                    'full_name': 'Private Guardian',
                    'phone': '+966500000099',
                  },
                },
              };
            }
            if (path.endsWith('/candidates')) {
              aiRequests++;
              response = {'state': 'unavailable', 'candidates': []};
            }
            return http.Response(jsonEncode(response), 200);
          }),
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
            language,
          ),
        );
        for (var i = 0; i < 10; i++) {
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pump();
        }
        final s = AppLocalizations.of(
          tester.element(find.byType(VolunteerWorkspace)),
        )!;
        expect(find.text(s.vManualReview), findsNothing);
        await tester.tap(find.byKey(const ValueKey('radd-tab-2')));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text(s.vOpenCamera),
          150,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text(s.vOpenCamera), findsOneWidget);
        expect(find.text(s.vManualReview), findsOneWidget);
        await press(tester, s.vManualReview);
        expect(created, 0);
        expect(aiRequests, 0);
        expect(find.byType(TextField), findsOneWidget);
        await press(tester, s.vViewDetails);
        expect(created, 0);
        expect(find.text('Private Guardian'), findsNothing);
        expect(find.text('+966500000099'), findsNothing);
        await press(tester, s.vConfirmIdentity);
        expect(created, 0); // Opening confirmation dialog is not consent.
        await tester.tap(find.widgetWithText(FilledButton, s.vConfirmMatch));
        await tester.pumpAndSettle();
        expect(created, 1);
        expect(aiRequests, 0);
        expect(repo.foundReports.single.photoBytes, isNull);
        expect(repo.foundReports.single.caseId, isNull);
        expect(find.text('Private Guardian'), findsWidgets);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        // Confirmation removes stale Manual Review/profile routes from Back.
        await tester.scrollUntilVisible(
          find.text(s.vOpenCamera),
          150,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text(s.vOpenCamera), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        await tester.tap(find.byKey(const ValueKey('radd-tab-1')));
        await tester.pumpAndSettle();
        expect(find.text(s.vFoundReportTitle), findsNothing);
        expect(find.text('FR-manual'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('radd-tab-2')));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('FR-manual'),
          150,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text('FR-manual'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
