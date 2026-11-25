import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:radd/core/localization/generated/app_localizations.dart';
import 'package:radd/features/volunteer/data/api_volunteer_repository.dart';
import 'package:radd/features/volunteer/presentation/volunteer_capture.dart';
import 'package:radd/features/volunteer/presentation/volunteer_components.dart';
import 'package:radd/features/volunteer/presentation/volunteer_face_scan.dart';
import 'package:radd/features/volunteer/presentation/volunteer_workspace.dart';

import 'volunteer_capture_manual_review_test.dart' show CaptureCamera;
import 'volunteer_location_test.dart' show LocationPlatform;
import 'volunteer_navigation_test.dart' show harness, press;

class AiBackend {
  AiBackend(this.candidates);
  Future<http.Response> Function() candidates;
  final png = CaptureCamera().bytes;
  int created = 0, aiRequests = 0, photoRequests = 0, ended = 0;

  Map<String, dynamic> report({bool ended = false}) => {
    'id': 'FR-test',
    'created_at': '2026-11-21T08:00:00Z',
    'status': 'identification_in_progress',
    'case_id': null,
    'ended': ended,
    'photo_available': !ended,
  };

  static Map<String, dynamic> person(String id, String name) => {
    'id': id,
    'full_name': name,
    'age': 7,
    'gender': 'female',
  };

  http.Client client() => MockClient((request) async {
    final path = request.url.path;
    Object body = [];
    if (path == '/v1/volunteer') {
      body = {
        'uid': 'test',
        'full_name': 'Test',
        'volunteer_id': 'TEST',
        'active': true,
        'consent_current': true,
        'assigned': true,
        'event_id': 'test-event',
      };
    } else if (path.endsWith('/found-reports') && request.method == 'POST') {
      created++;
      body = report();
    } else if (path.endsWith('/candidates')) {
      aiRequests++;
      return candidates();
    } else if (path.endsWith('/end')) {
      ended++;
      body = report(ended: true);
    } else if (path.contains('/profiles/') && path.endsWith('/photo')) {
      photoRequests++;
      return http.Response.bytes(png, 200);
    } else if (path.contains('/profiles/')) {
      final id = path.split('/').last;
      body = {...person(id, 'Fixture $id'), 'confirmation_available': true};
    }
    return http.Response(jsonEncode(body), 200);
  });
}

http.Response ranked() => http.Response(
  jsonEncode({
    'state': 'candidates',
    'candidates': [
      {'person': AiBackend.person('a', 'Fixture A'), 'similarity': .91},
      {'person': AiBackend.person('b', 'Fixture B'), 'similarity': .84},
      {'person': AiBackend.person('c', 'Fixture C'), 'similarity': .62},
    ],
  }),
  200,
);

Future<void> settle(WidgetTester tester, [int rounds = 10]) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
}

Future<(AppLocalizations, ApiVolunteerRepository)> startAttempt(
  WidgetTester tester,
  AiBackend backend,
  String language,
) async {
  tester.view.physicalSize = const Size(430, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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
  final repo = ApiVolunteerRepository(
    token: () async => 'unit-test',
    baseUrl: 'http://test',
    client: backend.client(),
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
  await settle(tester);
  final s = AppLocalizations.of(
    tester.element(find.byType(VolunteerWorkspace)),
  )!;
  await tester.tap(find.byKey(const ValueKey('radd-tab-2')));
  await tester.pumpAndSettle();
  await press(tester, s.vOpenCamera);
  await press(tester, s.capture);
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 20)),
  );
  await tester.pumpAndSettle();
  await press(tester, s.usePhoto);
  await settle(tester);
  expect(backend.created, 1);
  expect(find.byType(VolunteerOption), findsNWidgets(2));
  return (s, repo);
}

Future<void> tapAi(WidgetTester tester, AppLocalizations s) async {
  await tester.tap(find.text(s.vFindWithAi));
  await tester.pump();
}

Future<void> backButton(WidgetTester tester) async {
  await tester.tap(find.byType(BackButton));
  await tester.pumpAndSettle();
}

String percent(String language, int value) =>
    NumberFormat.decimalPattern(language).format(value);

void main() {
  for (final language in ['en', 'ar']) {
    testWidgets(
      'AI search shows a scan, then ranked candidates with reference photos ($language)',
      (tester) async {
        final pending = Completer<http.Response>();
        final backend = AiBackend(() => pending.future);
        final (s, repo) = await startAttempt(tester, backend, language);
        expect(backend.aiRequests, 0);

        await tester.tap(find.text(s.vFindWithAi));
        await tester.tap(find.text(s.vFindWithAi));
        await tester.pump();
        expect(backend.aiRequests, 1, reason: 'one request per search');
        expect(find.byType(FaceScanView), findsOneWidget);
        expect(find.text(s.vAnalyzingFace), findsOneWidget);
        expect(find.text(s.vManualReview), findsNothing);
        expect(find.text(s.vEndIdentification), findsNothing);
        expect(find.text(s.vViewDetails), findsNothing);
        expect(find.textContaining('%'), findsNothing);

        pending.complete(ranked());
        await settle(tester);
        await tester.pumpAndSettle();

        expect(find.byType(FaceScanView), findsNothing);
        final names = ['Fixture A', 'Fixture B', 'Fixture C'];
        final ys = [for (final n in names) tester.getTopLeft(find.text(n)).dy];
        expect(ys, orderedEquals([...ys]..sort()));
        for (final score in [91, 84, 62]) {
          expect(
            find.text(s.vSimilarityValue(percent(language, score))),
            findsOneWidget,
          );
        }
        expect(find.text(s.vViewDetails), findsNWidgets(3));
        expect(backend.photoRequests, 3);
        expect(
          tester
              .widgetList<PersonPhoto>(find.byType(PersonPhoto))
              .every((photo) => photo.person.photoBytes != null),
          isTrue,
        );

        await tester.tap(find.text(s.vViewDetails).first);
        await settle(tester);
        await tester.pumpAndSettle();
        expect(find.text(s.vCapturedPhoto), findsOneWidget);
        expect(find.text(s.vRegisteredPhoto), findsOneWidget);
        expect(find.text(s.vRankLabel(percent(language, 1))), findsOneWidget);
        expect(find.text(s.vGuardianName), findsNothing);
        expect(find.text(s.vSelectAndContact), findsOneWidget);

        await backButton(tester);
        expect(find.text('Fixture A'), findsOneWidget);
        await backButton(tester);
        expect(find.byType(VolunteerOption), findsNWidgets(2));
        await backButton(tester);
        expect(find.text(s.vLeaveAttemptHint), findsOneWidget);
        await press(tester, s.vCancel);
        expect(backend.ended, 0);
        expect(find.byType(VolunteerOption), findsNWidgets(2));
        final report = repo.foundReports.single;
        expect(report.photoBytes, isNotNull);

        await backButton(tester);
        await press(tester, s.vEndIdentification);
        await settle(tester);
        expect(backend.ended, 1);
        expect(report.photoBytes, isNull);
        expect(find.text(s.vOpenCamera), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'No match, unavailable, server failure and no connection are distinct ($language)',
      (tester) async {
        var outcome = 'none';
        final backend = AiBackend(() async {
          switch (outcome) {
            case 'unavailable':
              return http.Response(
                jsonEncode({'state': 'unavailable', 'candidates': []}),
                200,
              );
            case 'server':
              return http.Response('{"detail":"service_unavailable"}', 503);
            case 'network':
              throw http.ClientException('offline');
            default:
              return http.Response(
                jsonEncode({
                  'state': 'no_reliable_candidate',
                  'candidates': [],
                }),
                200,
              );
          }
        });
        final (s, _) = await startAttempt(tester, backend, language);
        Future<void> search() async {
          await tapAi(tester, s);
          await settle(tester);
          await tester.pumpAndSettle();
        }

        await search();
        expect(find.text(s.vNoMatchTitle), findsOneWidget);
        expect(find.byType(PersonPhoto), findsNothing);
        final manual = find.ancestor(
          of: find.text(s.vManualReview),
          matching: find.byType(VolunteerAction),
        );
        expect(tester.widget<VolunteerAction>(manual).secondary, isFalse);
        expect(find.text(s.vSearchAgain), findsOneWidget);

        final seen = <String>{};
        for (final (kind, title, retry) in [
          ('unavailable', s.vAiUnavailableTitle, false),
          ('server', s.vAiErrorTitle, true),
          ('network', s.vNetworkErrorTitle, true),
        ]) {
          await backButton(tester);
          outcome = kind;
          await search();
          expect(find.text(title), findsOneWidget, reason: kind);
          expect(find.text(s.vNoMatchTitle), findsNothing);
          expect(find.text(s.vTryAgain), retry ? findsOneWidget : findsNothing);
          expect(find.text(s.vManualReview), findsOneWidget);
          seen.add(title);
        }
        expect(seen, hasLength(3));
        expect({s.vAiUnavailable, s.vAiError, s.vAiNetworkError}, hasLength(3));

        outcome = 'none';
        final before = backend.aiRequests;
        await press(tester, s.vTryAgain);
        await settle(tester);
        await tester.pumpAndSettle();
        expect(backend.aiRequests, before + 1);
        expect(find.text(s.vNoMatchTitle), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets(
    'Cancelling a search returns to the options and ignores the late result',
    (tester) async {
      var pending = Completer<http.Response>();
      final backend = AiBackend(() => pending.future);
      final (s, _) = await startAttempt(tester, backend, 'ar');
      await tapAi(tester, s);
      expect(find.byType(FaceScanView), findsOneWidget);
      await tester.tap(find.text(s.vCancelSearch));
      await tester.pumpAndSettle();
      expect(find.byType(VolunteerOption), findsNWidgets(2));
      pending.complete(ranked());
      await settle(tester);
      await tester.pumpAndSettle();
      expect(
        find.text('Fixture A'),
        findsNothing,
        reason: 'late result ignored',
      );
      expect(find.byType(VolunteerOption), findsNWidgets(2));
      expect(backend.ended, 0, reason: 'cancel keeps the attempt');

      pending = Completer<http.Response>();
      await tapAi(tester, s);
      expect(backend.aiRequests, 2);
      pending.complete(ranked());
      await settle(tester);
      await tester.pumpAndSettle();
      expect(find.text('Fixture A'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('Switching tabs during an attempt ends it after confirmation', (
    tester,
  ) async {
    final backend = AiBackend(() async => ranked());
    final (s, repo) = await startAttempt(tester, backend, 'en');
    final report = repo.foundReports.single;
    await tester.tap(find.byKey(const ValueKey('radd-tab-0')));
    await tester.pumpAndSettle();
    expect(find.text(s.vLeaveAttemptHint), findsOneWidget);
    await press(tester, s.vEndIdentification);
    await settle(tester);
    await tester.pumpAndSettle();
    expect(backend.ended, 1);
    expect(report.photoBytes, isNull);
    expect(find.byType(VolunteerOption), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  test(
    'Capture cleanup removes this and stale plugin capture files only',
    () async {
      final dir = await Directory.systemTemp.createTemp('radd-capture-test');
      addTearDown(() => dir.delete(recursive: true));
      File named(String name) =>
          File('${dir.path}/$name')..writeAsBytesSync([1]);
      final current = named('CAP123456.jpg');
      final staleAndroid = named('CAP987654.jpg');
      final staleIos = named('CAP_9F2C.jpg');
      final unrelated = named('report.jpg');
      final otherType = named('CAP1.png');
      await deleteCaptureFiles(current.path);
      expect(current.existsSync(), isFalse);
      expect(staleAndroid.existsSync(), isFalse);
      expect(staleIos.existsSync(), isFalse);
      expect(unrelated.existsSync(), isTrue);
      expect(otherType.existsSync(), isTrue);
      await deleteCaptureFiles('');
    },
  );

  testWidgets('A concluded capture leaves no decoded copy in the image cache', (
    tester,
  ) async {
    final bytes = CaptureCamera().bytes;
    await tester.pumpWidget(Image.memory(bytes));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    final cache = PaintingBinding.instance.imageCache;
    expect(cache.containsKey(MemoryImage(bytes)), isTrue);
    await tester.pumpWidget(const SizedBox());
    forgetCapturedPhoto(bytes);
    expect(cache.containsKey(MemoryImage(bytes)), isFalse);
  });
}
