import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:radd/features/volunteer/presentation/volunteer_workspace.dart';

import 'volunteer_navigation_test.dart' show harness;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:radd/features/volunteer/data/api_volunteer_repository.dart';
import 'package:radd/features/volunteer/domain/volunteer_models.dart';

void main() {
  Map<String, dynamic> profile({bool active = true}) => {
    'uid': 'server-uid',
    'full_name': 'اسم حقيقي',
    'volunteer_id': 'V-42',
    'active': active,
    'email': 'real@example.test',
    'phone': '+966500000001',
  };
  Map<String, dynamic> caseData({
    bool joined = false,
    String status = 'report_received',
    bool confirmed = false,
  }) => {
    'id': 'RD-real',
    'individual_id': 'person',
    'individual_name': 'Real Person',
    'age': 7,
    'gender': 'female',
    'status': status,
    'joined': joined,
    'confirmed_by_me': confirmed,
    'created_at': '2026-09-01T08:00:00Z',
    'updated_at': '2026-09-01T09:00:00Z',
    'guided_report': {
      'same_location': false,
      'last_seen_description': 'North Gate',
      'clothing': 'Blue shirt',
    },
  };
  http.Response json(Object value) => http.Response(
    jsonEncode(value),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  test('Profile, cases, private photos and join use verified bearer API; no submitted UID', () async {
    var joined = false;
    final requests = <http.Request>[];
    final repo = ApiVolunteerRepository(
      token: () async => 'firebase-token',
      baseUrl: 'http://localhost:8000',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/found-reports') ||
            request.url.path.endsWith('/notifications')) {
          return json([]);
        }
        requests.add(request);
        expect(request.headers['Authorization'], 'Bearer firebase-token');
        expect(request.body, isEmpty);
        switch (request.url.path) {
          case '/v1/volunteer':
            return json(profile());
          case '/v1/volunteer/cases/available':
            return json(joined ? [] : [caseData()]);
          case '/v1/volunteer/cases/mine':
            return json(
              joined
                  ? [caseData(joined: true, status: 'search_in_progress')]
                  : [],
            );
          case '/v1/volunteer/cases/RD-real/photo':
            return http.Response.bytes([1, 2, 3], 200);
          case '/v1/volunteer/cases/RD-real/start-search':
            expect(request.method, 'POST');
            joined = true;
            return json(caseData(joined: true, status: 'search_in_progress'));
          default:
            throw StateError('Unexpected request');
        }
      }),
    );
    addTearDown(repo.dispose);
    await repo.refresh();
    expect(repo.isPreview, isFalse);
    expect(repo.account!.name.ar, 'اسم حقيقي');
    expect(repo.account!.volunteerId, 'V-42');
    final item = repo.availableFor('server-uid').single;
    expect(item.person.photoBytes, [1, 2, 3]);
    expect(item.person.photo, isNull);
    expect(item.person.guardian.phone, isNull);
    expect(item.information!.coordinates, isNull);
    expect(repo.myCases('server-uid'), isEmpty);
    await repo.startSearch(repo.account!, item);
    expect(item.status, CaseStatus.searchInProgress);
    expect(repo.availableFor('server-uid'), isEmpty);
    expect(repo.myCases('server-uid').single.id, 'RD-real');
    await repo.refresh();
    expect(repo.myCases('server-uid').single.id, 'RD-real');
    expect(
      requests.every((r) => !r.url.queryParameters.containsKey('uid')),
      isTrue,
    );
  });

  test(
    'Admin deactivation clears all protected state and requests shared logout',
    () async {
      var active = true;
      String? lostReason;
      final repo = ApiVolunteerRepository(
        token: () async => 'token',
        onAccessLost: (reason) async {
          lostReason = reason;
        },
        baseUrl: 'http://localhost',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/found-reports') ||
              request.url.path.endsWith('/notifications')) {
            return json([]);
          }
          if (request.url.path == '/v1/volunteer') {
            return json(profile(active: active));
          }
          expect(active, isTrue);
          if (request.url.path.endsWith('/available')) {
            return json([caseData()]);
          }
          if (request.url.path.endsWith('/mine')) return json([]);
          return http.Response('', 404);
        }),
      );
      addTearDown(repo.dispose);
      await repo.refresh();
      expect(repo.cases, hasLength(1));
      active = false;
      await expectLater(repo.refresh(), throwsStateError);
      expect(lostReason, 'volunteer_inactive');
      expect(repo.account, isNull);
      expect(repo.profiles, isEmpty);
      expect(repo.foundReports, isEmpty);
      expect(repo.cases, isEmpty);
    },
  );

  test(
    'Backend failure clears stale cases and never loads sample data',
    () async {
      var fail = false;
      final repo = ApiVolunteerRepository(
        token: () async => 'token',
        baseUrl: 'http://localhost',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/found-reports') ||
              request.url.path.endsWith('/notifications')) {
            return json([]);
          }
          if (fail) return http.Response('', 503);
          if (request.url.path == '/v1/volunteer') return json(profile());
          if (request.url.path.endsWith('/available')) {
            return json([caseData()]);
          }
          if (request.url.path.endsWith('/mine')) return json([]);
          return http.Response('', 404);
        }),
      );
      addTearDown(repo.dispose);
      await repo.refresh();
      expect(repo.cases, isNotEmpty);
      fail = true;
      await expectLater(repo.refresh(), throwsStateError);
      expect(repo.cases, isEmpty);
      expect(repo.connected, isFalse);
      expect(repo.profiles, isEmpty);
      expect(repo.alertsFor('server-uid'), isEmpty);
    },
  );

  test(
    'Capture is required and unavailable AI never fabricates candidates',
    () async {
      var requests = 0;
      final repo = ApiVolunteerRepository(
        token: () async => 'token',
        baseUrl: 'http://localhost',
        client: MockClient((_) async {
          requests++;
          return json(profile());
        }),
      );
      addTearDown(repo.dispose);
      final account = await repo.loadProfile();
      await expectLater(repo.submitFound(account), throwsStateError);
      final report = FoundReport(
        id: 'not-a-real-report',
        volunteerUid: account.uid,
        photo: '',
      );
      await expectLater(repo.findMatches(report), throwsStateError);
      await expectLater(
        repo.verify(
          account,
          report,
          VerificationMethod.caseIdentifier,
          'RD-test',
        ),
        throwsStateError,
      );
      expect(requests, 2);
    },
  );

  test('Missing authentication sends no HTTP request', () async {
    final repo = ApiVolunteerRepository(
      token: () async => null,
      baseUrl: 'http://localhost',
      client: MockClient((_) async => throw StateError('must not call')),
    );
    addTearDown(repo.dispose);
    await expectLater(repo.loadProfile(), throwsStateError);
  });
  test('Backend inactive response requests logout and prevents later protected requests', () async {
    var calls = 0;
    String? reason;
    final repo = ApiVolunteerRepository(
      token: () async => 'token',
      baseUrl: 'http://localhost',
      onAccessLost: (value) async {
        reason = value;
      },
      client: MockClient((request) async {
        calls++;
        return http.Response('{"detail":"volunteer_inactive"}', 403);
      }),
    );
    addTearDown(repo.dispose);
    await expectLater(repo.loadProfile(), throwsStateError);
    expect(reason, 'volunteer_inactive');
    expect(repo.account, isNull);
    expect(repo.cases, isEmpty);
    await expectLater(repo.loadProfiles(), throwsStateError);
    expect(calls, 1);
  });
  for (final language in ['en', 'ar']) {
    testWidgets('API account drives Home, Profile and active ID in $language', (
      tester,
    ) async {
      final repo = ApiVolunteerRepository(
        token: () async => 'token',
        baseUrl: 'http://localhost',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/found-reports') ||
              request.url.path.endsWith('/notifications')) {
            return json([]);
          }
          if (request.url.path == '/v1/volunteer') {
            return json(profile());
          }
          if (request.url.path.endsWith('/available')) {
            return json([caseData()]);
          }
          if (request.url.path.endsWith('/mine')) return json([]);
          return http.Response('', 404);
        }),
      );
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
      await tester.pumpAndSettle();
      expect(find.text('اسم حقيقي'), findsWidgets);
      expect(repo.cases.single.id, 'RD-real');
      final navigation = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );
      navigation.onDestinationSelected!(4);
      await tester.pumpAndSettle();
      expect(find.text('real@example.test'), findsOneWidget);
      navigation.onDestinationSelected!(3);
      await tester.pump(const Duration(milliseconds: 400));
      final badge = tester.widget<VolunteerBadgeCard>(
        find.byType(VolunteerBadgeCard),
      );
      expect(badge.account.active, isTrue);
      expect(badge.account.volunteerId, 'V-42');
      expect(repo.cases, hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      repo.dispose();
    });
  }
}
