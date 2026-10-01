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
import 'volunteer_manual_only_test.dart' show CaptureCamera;

/// Confirm Identity on a registration that is ALREADY inside an active
/// standalone Found Report (the Volunteer lost local state, reopened Manual
/// Review, selected the same individual). The backend answers with the
/// existing report or a specific refusal; the app must continue at the real
/// stage or say exactly why -- never the generic "could not be completed",
/// never a duplicate report, never a Missing Case.
void main() {
  Future<ApiVolunteerRepository> workspace(
    WidgetTester tester,
    String language, {
    required http.Response Function(http.Request request) onConfirm,
    required List<String> posts,
    http.Response Function(http.Request request)? onVerify,
  }) async {
    final previousCamera = CameraPlatform.instance;
    final previousLocation = GeolocatorPlatform.instance;
    final location = LocationPlatform()
      ..permission = LocationPermission.whileInUse;
    GeolocatorPlatform.instance = location;
    CameraPlatform.instance = CaptureCamera();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    addTearDown(() async {
      CameraPlatform.instance = previousCamera;
      GeolocatorPlatform.instance = previousLocation;
      await location.positions.close();
      await location.services.close();
    });
    final person = {
      'id': 'profile-test',
      'full_name': 'Test Person',
      'age': 10,
      'gender': 'female',
      'relationship': 'daughter',
    };
    final repo = ApiVolunteerRepository(
      token: () async => 'unit-test',
      baseUrl: 'http://test',
      client: MockClient((request) async {
        final path = request.url.path;
        if (request.method == 'POST' && !path.contains('fcm-registrations')) {
          posts.add(path);
        }
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
        if (path.endsWith('/profiles')) response = [person];
        if (path.endsWith('/profiles/profile-test')) {
          response = {...person, 'confirmation_available': false};
        }
        if (path.endsWith('/profiles/profile-test/photo')) {
          return http.Response.bytes(CaptureCamera().bytes, 200);
        }
        if (path.endsWith('/found-reports/manual') &&
            request.method == 'POST') {
          return onConfirm(request);
        }
        if (path.endsWith('/candidates')) {
          response = {'state': 'unavailable', 'candidates': []};
        }
        if (path.endsWith('/verify-identifier') && onVerify != null) {
          return onVerify(request);
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
    return repo;
  }

  Future<AppLocalizations> confirmFromManualReview(WidgetTester tester) async {
    final s = AppLocalizations.of(
      tester.element(find.byType(VolunteerWorkspace)),
    )!;
    await tester.tap(find.byKey(const ValueKey('radd-tab-2')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(s.vManualReview),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await press(tester, s.vManualReview);
    await press(tester, s.vViewDetails);
    await press(tester, s.vConfirmIdentity);
    await tester.tap(find.widgetWithText(FilledButton, s.vConfirmMatch));
    // Bounded pumping: a refusal triggers a background state refresh whose
    // location request never resolves in the test fakes, so pumpAndSettle
    // would wait on its progress indicator forever.
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 100));
    }
    return s;
  }

  for (final language in ['en', 'ar']) {
    testWidgets(
      'Own report already awaiting verification: Confirm Identity resumes it '
      'at Guardian Verification with no duplicate ($language)',
      (tester) async {
        final posts = <String>[];
        await workspace(
          tester,
          language,
          posts: posts,
          onConfirm: (_) => http.Response(
            jsonEncode({
              'id': 'FR-existing',
              'created_at': '2026-09-28T08:00:00Z',
              'status': 'awaiting_guardian_verification',
              'found_status': 'awaiting_guardian_verification',
              'case_id': null,
              'photo_available': false,
              'verification': null,
              'person': {
                'id': 'profile-test',
                'full_name': 'Test Person',
                'age': 10,
                'gender': 'female',
                'guardian': {
                  'full_name': 'Private Guardian',
                  'phone': '+966500000099',
                },
              },
            }),
            201,
          ),
        );
        final s = await confirmFromManualReview(tester);
        // Straight to Guardian Verification -- not Manual Review, not
        // Guardian Contact, no second identification.
        expect(find.text(s.vScanInstruction), findsOneWidget);
        expect(find.text(s.vActionFailed), findsNothing);
        expect(find.text(s.vManualReview), findsNothing);
        expect(posts.where((p) => p.endsWith('/manual')).length, 1);
        expect(posts.where((p) => p.endsWith('/begin-verification')), isEmpty);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Another Volunteer holds the active report: a clear localized refusal, '
      'no generic message, no navigation ($language)',
      (tester) async {
        final posts = <String>[];
        await workspace(
          tester,
          language,
          posts: posts,
          onConfirm: (_) =>
              http.Response(jsonEncode({'detail': 'already_matched'}), 409),
        );
        final s = await confirmFromManualReview(tester);
        expect(find.text(s.vFailureAlreadyMatched), findsOneWidget);
        expect(find.text(s.vActionFailed), findsNothing);
        expect(find.text(s.vScanInstruction), findsNothing);
        expect(find.text('Private Guardian'), findsNothing);
        expect(
          find.text(s.vConfirmIdentity),
          findsOneWidget,
        ); // still on details
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }

  final awaitingReport = {
    'id': 'FR-existing',
    'created_at': '2026-09-28T08:00:00Z',
    'status': 'awaiting_guardian_verification',
    'found_status': 'awaiting_guardian_verification',
    'case_id': null,
    'photo_available': false,
    'verification': null,
    'person': {
      'id': 'profile-test',
      'full_name': 'Test Person',
      'age': 10,
      'gender': 'female',
      'guardian': {'full_name': 'Private Guardian', 'phone': '+966500000099'},
    },
  };

  Future<void> useIdentifier(WidgetTester tester, AppLocalizations s) async {
    await tester.scrollUntilVisible(
      find.text(s.vUseIdentifier),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await press(tester, s.vUseIdentifier);
  }

  Future<void> submitCode(
    WidgetTester tester,
    AppLocalizations s,
    String typed,
  ) async {
    await tester.enterText(find.byType(TextFormField), typed);
    await Scrollable.ensureVisible(
      tester.element(find.byType(CheckboxListTile)),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    final shown = tester.widget<CheckboxListTile>(
      find.byType(CheckboxListTile),
    );
    if (shown.value != true) {
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
    }
    await press(tester, s.vVerify);
    await tester.pumpAndSettle();
  }

  for (final language in ['en', 'ar']) {
    testWidgets(
      'Standalone fallback asks for the short Guardian code, not the report '
      'id, and sends it normalized ($language)',
      (tester) async {
        final posts = <String>[];
        final bodies = <Map<String, dynamic>>[];
        await workspace(
          tester,
          language,
          posts: posts,
          onConfirm: (_) => http.Response(jsonEncode(awaitingReport), 201),
          onVerify: (request) {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            bodies.add(body);
            final verified = body['identifier'] == '482913';
            return http.Response(
              jsonEncode({
                'verified': verified,
                'report': {
                  ...awaitingReport,
                  'verification': verified
                      ? {
                          'method': 'found_identifier',
                          'context_type': 'found_report',
                          'context_id': 'FR-existing',
                          'guardian_id': 'guardian',
                          'volunteer_uid': 'test',
                          'verified_at': '2026-09-28T08:05:00Z',
                        }
                      : null,
                },
              }),
              200,
            );
          },
        );
        final s = await confirmFromManualReview(tester);
        expect(find.text(s.vScanInstruction), findsOneWidget);
        await useIdentifier(tester, s);
        expect(find.text(s.vFoundReportIdentifier), findsOneWidget);
        expect(find.text(s.vFoundIdentifierHelp), findsOneWidget);
        // The old label/help asking to compare the full identifier is gone.
        expect(find.text('Found Report Identifier'), findsNothing);
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.keyboardType, TextInputType.number);
        expect(field.controller!.text, isEmpty); // never prefilled with the id
        // Too short / not a code: refused locally, nothing sent.
        await submitCode(tester, s, 'FR-existing');
        expect(find.text(s.vVerificationCodeFormat), findsOneWidget);
        expect(bodies, isEmpty);
        // A wrong 6-digit code goes to the server and fails there.
        await submitCode(tester, s, '000000');
        expect(bodies.single, {'identifier': '000000'});
        expect(find.text(s.vVerificationFailed), findsWidgets);
        // Read aloud with spacing and Arabic-Indic digits: normalized.
        await useIdentifier(tester, s);
        await submitCode(tester, s, '٤٨٢ 91-3');
        expect(bodies.last, {'identifier': '482913'});
        await tester.scrollUntilVisible(
          find.text(s.vContinueHandover),
          250,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text(s.vContinueHandover), findsOneWidget);
        expect(posts.where((p) => p.endsWith('/handover')), isEmpty);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }

  test('normalizeVerificationCode keeps only what a Guardian read aloud', () {
    expect(normalizeVerificationCode(' 48 29-13 '), '482913');
    expect(normalizeVerificationCode('#٤٨٢٩١٣'), '482913');
    expect(normalizeVerificationCode('۴۸۲۹۱۳'), '482913');
    expect(normalizeVerificationCode('FR-482913'), 'FR482913');
    expect(isVerificationCode('482913'), isTrue);
    expect(isVerificationCode('48291'), isFalse);
    expect(isVerificationCode('FR482913'), isFalse);
  });

  test(
    'Known backend refusals keep their meaning; unknown ones stay generic',
    () async {
      Future<Object?> code(int status, String body) async {
        final repo = ApiVolunteerRepository(
          token: () async => 'unit-test',
          baseUrl: 'http://test',
          client: MockClient((request) async {
            if (request.url.path == '/v1/volunteer') {
              return http.Response(
                jsonEncode({
                  'uid': 'test',
                  'full_name': 'Test',
                  'volunteer_id': 'TEST',
                  'active': true,
                  'consent_current': true,
                  'assigned': true,
                  'event_id': 'test-event',
                }),
                200,
              );
            }
            return http.Response(body, status);
          }),
        );
        await repo.loadProfile();
        try {
          await repo.confirmManualIdentity('a' * 64, 'request-0000000001');
          return null;
        } on StateError catch (error) {
          return error.message;
        } finally {
          repo.dispose();
        }
      }

      expect(
        await code(409, '{"detail":"already_matched"}'),
        'already-matched',
      );
      expect(
        await code(409, '{"detail":"resume_existing_report"}'),
        'resume-existing-report',
      );
      expect(
        await code(409, '{"detail":"profile_unavailable"}'),
        'profile-unavailable',
      );
      expect(
        await code(409, '{"detail":"guardian_verification_required"}'),
        'guardian-verification-required',
      );
      expect(
        await code(409, '{"detail":"something_new"}'),
        'backend-unavailable',
      );
      expect(await code(500, 'oops'), 'backend-unavailable');
      expect(await code(404, '{"detail":"not_found"}'), 'not-found');
    },
  );
}
