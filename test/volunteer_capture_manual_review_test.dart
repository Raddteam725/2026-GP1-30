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
import 'package:radd/features/volunteer/presentation/volunteer_components.dart';

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
      'Real capture route Use Photo shows AI and Manual Review before any AI request ($language)',
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
        var aiRequests = 0, created = 0, profiles = 0;
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
            if (path.endsWith('/found-reports') && request.method == 'POST') {
              created++;
              expect(jsonDecode(request.body)['photo_base64'], isNotEmpty);
              response = {
                'id': 'FR-test',
                'created_at': '2026-09-28T08:00:00Z',
                'status': 'identification_in_progress',
                'case_id': null,
                'photo_available': true,
              };
            }
            if (path.endsWith('/candidates')) {
              aiRequests++;
              response = {'state': 'unavailable', 'candidates': []};
            }
            if (path.endsWith('/profiles')) profiles++;
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
        await press(tester, s.vOpenCamera);
        await press(tester, s.capture);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pumpAndSettle();
        expect(find.text(s.retakePhoto), findsOneWidget);
        await press(tester, s.usePhoto);
        expect(created, 1);
        expect(repo.foundReports.single.caseId, isNull);
        expect(aiRequests, 0);
        final ai = find.ancestor(
          of: find.text(s.vFindWithAi),
          matching: find.byType(VolunteerAction),
        );
        final manual = find.ancestor(
          of: find.text(s.vManualReview),
          matching: find.byType(VolunteerAction),
        );
        expect(tester.widget<VolunteerAction>(ai).secondary, isFalse);
        expect(tester.widget<VolunteerAction>(manual).secondary, isTrue);
        await press(tester, s.vManualReview);
        expect(profiles, greaterThan(0));
        expect(aiRequests, 0);
        expect(find.byType(TextField), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
