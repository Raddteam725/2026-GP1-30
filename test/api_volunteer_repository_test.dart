import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'volunteer_location_test.dart' show LocationPlatform;

import 'package:radd/features/guardian/presentation/guardian_components.dart';
import 'package:radd/features/volunteer/presentation/volunteer_workspace.dart';

import 'volunteer_navigation_test.dart' show harness;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:radd/features/volunteer/data/api_volunteer_repository.dart';
import 'package:radd/features/volunteer/domain/volunteer_models.dart';
import 'package:radd/features/volunteer/domain/volunteer_notification_event.dart';

void main() {
  late GeolocatorPlatform previousLocation;
  late LocationPlatform locationPlatform;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    previousLocation = GeolocatorPlatform.instance;
    locationPlatform = LocationPlatform()
      ..permission = LocationPermission.whileInUse;
    GeolocatorPlatform.instance = locationPlatform;
  });
  tearDown(() async {
    GeolocatorPlatform.instance = previousLocation;
    await locationPlatform.positions.close();
    await locationPlatform.services.close();
  });
  Map<String, dynamic> profile({bool active = true}) => {
    'uid': 'server-uid',
    'full_name': 'اسم حقيقي',
    'volunteer_id': 'V-42',
    'consent_current': true,
    'assigned': true,
    'event_id': 'test-event',
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

  test(
    'Handover removes completed workload and counts before and after refetch',
    () async {
      var completed = false;
      var mineReads = 0;
      final repo = ApiVolunteerRepository(
        token: () async => 'token',
        baseUrl: 'http://test',
        client: MockClient((request) async {
          final path = request.url.path;
          if (path == '/v1/volunteer') return json(profile());
          if (path.endsWith('/handover')) {
            completed = true;
            return json({
              'id': 'FR-test',
              'created_at': '2026-09-01T08:00:00Z',
              'volunteer_uid': 'server-uid',
              'case_id': 'RD-real',
              'status': 'reunited',
              'photo_available': false,
            });
          }
          if (path.endsWith('/cases/mine')) {
            mineReads++;
            return json(
              completed
                  ? []
                  : [
                      caseData(
                        joined: true,
                        status: 'awaiting_guardian_verification',
                        confirmed: true,
                      ),
                    ],
            );
          }
          return json([]);
        }),
      );
      addTearDown(repo.dispose);
      await repo.refresh();
      expect(repo.myCases('server-uid').length, 1);
      expect(repo.availableFor('server-uid'), isEmpty);
      final report = FoundReport(
        id: 'FR-test',
        volunteerUid: 'server-uid',
        photo: '',
      )..caseId = 'RD-real';
      await repo.handover(repo.account!, report);
      // The successful response updates the local model even before list recovery.
      expect(repo.myCases('server-uid'), isEmpty);
      expect(repo.availableFor('server-uid'), isEmpty);
      for (var i = 0; i < 20 && mineReads < 2; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(mineReads, greaterThanOrEqualTo(2));
      await repo.refresh();
      expect(repo.myCases('server-uid').length, 0);
      expect(repo.availableFor('server-uid').length, 0);
      expect(repo.cases, isEmpty);
    },
  );

  test('Volunteer proximity uses the authenticated backend radius', () async {
    final repo = ApiVolunteerRepository(
      token: () async => 'test-token',
      baseUrl: 'http://test',
      client: MockClient(
        (request) async => json({...profile(), 'proximity_radius_meters': 375}),
      ),
    );
    addTearDown(repo.dispose);
    await repo.loadProfile();
    expect(repo.proximityRadiusMeters, 375);
  });

  testWidgets('Location access gates event UI, not a temporarily missing fix', (
    tester,
  ) async {
    locationPlatform.permission = LocationPermission.denied;
    locationPlatform.response = LocationPermission.whileInUse;
    final repo = ApiVolunteerRepository(
      token: () async => 'test-token',
      baseUrl: 'http://test',
      client: MockClient(
        (request) async =>
            json(request.url.path == '/v1/volunteer' ? profile() : []),
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
    await tester.pumpAndSettle();
    expect(locationPlatform.requests, 0); // Explanation precedes OS dialog.
    expect(find.text('Manual Review'), findsNothing);
    // Use the existing Radd action's label independently of button subclass.
    final label = find.text('Continue');
    expect(label, findsOneWidget);
    await tester.tap(label);
    await tester.pumpAndSettle();
    expect(locationPlatform.requests, 1);
    expect(
      find.text('Report Found Individual'),
      findsWidgets,
    ); // No fix needed.
    locationPlatform.enabled = false;
    locationPlatform.services.add(ServiceStatus.disabled);
    await tester.pumpAndSettle();
    expect(find.text('Manual Review'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Open Settings'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Open Settings'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('radd-tab-4')));
    await tester.pumpAndSettle();
    expect(find.text('Account Information'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  test('Closure history compatibility preserves read document IDs and suppresses aliases', () async {
    final writes = <String>[];
    final rows = <Map<String, dynamic>>[
      {
        'id': 'original-cancel',
        'case_id': 'one',
        'kind': 'case_closed',
        'status': 'cancelled',
      },
      {
        'id': 'canonical-cancel',
        'case_id': 'one',
        'kind': 'cancelled',
        'status': 'cancelled',
      },
      {
        'id': 'original-resolve',
        'case_id': 'two',
        'kind': 'case_closed',
        'status': 'resolved',
      },
      {
        'id': 'invalid',
        'case_id': 'three',
        'kind': 'case_closed',
        'status': 'unknown',
      },
    ].map((r) => {...r, 'created_at': '2026-09-01T08:00:00Z'}).toList();
    final repo = ApiVolunteerRepository(
      token: () async => 'test-token',
      baseUrl: 'http://localhost',
      client: MockClient((request) async {
        if (request.method == 'PUT') {
          writes.add(request.url.path);
          return json({});
        }
        if (request.url.path == '/v1/volunteer') return json(profile());
        if (request.url.path.endsWith('/notifications')) return json(rows);
        return json([]);
      }),
    );
    addTearDown(repo.dispose);
    await repo.refresh();
    final alerts = repo.alertsFor('server-uid');
    expect(
      alerts.map((a) => a.kind),
      containsAll([AlertKind.cancelled, AlertKind.resolved]),
    );
    expect(alerts.length, 2);
    await repo.markRead(
      alerts.singleWhere((a) => a.kind == AlertKind.cancelled),
    );
    expect(writes, ['/v1/volunteer/notifications/original-cancel/read']);
  });

  testWidgets(
    'Resume performs immediate authoritative recovery without polling',
    (tester) async {
      var requests = 0;
      final repo = ApiVolunteerRepository(
        token: () async => 'test-token',
        baseUrl: 'http://localhost',
        client: MockClient((request) async {
          if (request.url.path == '/v1/volunteer') return json(profile());
          if (request.url.path.endsWith('/available')) requests++;
          return json([]);
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
          'en',
        ),
      );
      await tester.pumpAndSettle();
      final before = requests;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(requests, greaterThan(before));
    },
  );

  for (final outcome in ['cancelled', 'resolved']) {
    testWidgets(
      'Open case explains $outcome after targeted foreground refresh',
      (tester) async {
        var closed = false;
        var fail = false;
        var profiles = 0;
        var reports = 0;
        var lists = 0;
        final events = StreamController<VolunteerNotificationEvent>();
        final repo = ApiVolunteerRepository(
          token: () async => 'test-token',
          baseUrl: 'http://localhost',
          client: MockClient((request) async {
            final path = request.url.path;
            if (fail) throw http.ClientException('isolated network outage');
            if (path == '/v1/volunteer') {
              profiles++;
              return json(profile());
            }
            if (path.endsWith('/found-reports')) {
              reports++;
              return json([]);
            }
            if (path.endsWith('/available')) {
              lists++;
              return json(closed ? [] : [caseData()]);
            }
            if (path.endsWith('/mine')) return json([]);
            if (path.endsWith('/state')) {
              return json({
                'id': 'RD-real',
                'status': closed ? outcome : 'report_received',
              });
            }
            if (path.endsWith('/notifications')) {
              return json(
                closed
                    ? [
                        {
                          'id': 'RD-real-$outcome',
                          'case_id': 'RD-real',
                          'kind': outcome,
                          'created_at': '2026-09-21T15:00:00Z',
                        },
                      ]
                    : [],
              );
            }
            if (path.endsWith('/cases/RD-real')) {
              return json({...caseData(), 'photo_available': false});
            }
            if (path.endsWith('/photo')) return http.Response('', 404);
            return json([]);
          }),
        );
        addTearDown(repo.dispose);
        addTearDown(events.close);
        await repo.refresh();
        await tester.pumpWidget(
          harness(
            VolunteerWorkspace(
              account: repo.account!,
              repository: repo,
              notificationEvents: events.stream,
              onLogout: () async {},
            ),
            'en',
          ),
        );
        await tester.pumpAndSettle();
        // A background outage preserves cases and does not expose a global error.
        fail = true;
        await expectLater(repo.refresh(), throwsA(isA<http.ClientException>()));
        await tester.pumpAndSettle();
        expect(repo.cases, isNotEmpty);
        expect(
          find.text('Couldn’t load right now. Tap to try again.'),
          findsNothing,
        );
        fail = false;
        events.add(
          const VolunteerNotificationEvent(
            id: 'RD-real-new',
            caseId: 'RD-real',
            kind: AlertKind.newCase,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('View Case').first);
        await tester.pumpAndSettle();
        expect(find.text('Case Details'), findsOneWidget);
        final beforeProfiles = profiles, beforeReports = reports;
        closed = true;
        final event = VolunteerNotificationEvent(
          id: 'RD-real-$outcome',
          caseId: 'RD-real',
          kind: outcome == 'cancelled'
              ? AlertKind.cancelled
              : AlertKind.resolved,
        );
        events.add(event);
        await tester.pumpAndSettle();
        expect(find.text('Case Details'), findsOneWidget);
        expect(
          find.text(outcome == 'cancelled' ? 'Case Cancelled' : 'Person Found'),
          findsWidgets,
        );
        expect(repo.cases, isEmpty);
        expect(repo.caseStates['RD-real'], outcome);
        expect(profiles, beforeProfiles);
        expect(reports, beforeReports);
        final afterLists = lists;
        events.add(event);
        await tester.pumpAndSettle();
        expect(lists, afterLists);
      },
    );
  }

  testWidgets(
    'Initial pending refresh shows loading rather than failure or empty cases',
    (tester) async {
      final pending = Completer<http.Response>();
      final repo = ApiVolunteerRepository(
        token: () async => 'test-token',
        baseUrl: 'http://localhost',
        client: MockClient((request) async {
          if (request.url.path == '/v1/volunteer') return json(profile());
          if (request.url.path.endsWith('/available')) return pending.future;
          return json([]);
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
          'en',
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.text('Couldn’t load right now. Tap to try again.'),
        findsNothing,
      );
      expect(repo.hasLoadedCases, isFalse);
      pending.complete(json([]));
      await tester.pumpAndSettle();
      expect(repo.hasLoadedCases, isTrue);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  test('Notification target can be fetched outside the cached lists', () async {
    var requested = false;
    final repo = ApiVolunteerRepository(
      token: () async => 'isolated-test-token',
      baseUrl: 'http://localhost',
      client: MockClient((request) async {
        if (request.url.path == '/v1/volunteer') return json(profile());
        if (request.url.path == '/v1/volunteer/cases/RD-real') {
          expect(
            request.headers['Authorization'],
            'Bearer isolated-test-token',
          );
          requested = true;
          return json({...caseData(), 'photo_available': false});
        }
        return json([]);
      }),
    );
    addTearDown(repo.dispose);
    await repo.loadProfile();
    expect(repo.cases, isEmpty);
    final item = await repo.loadCase('RD-real');
    expect(requested, isTrue);
    expect(item.id, 'RD-real');
  });

  testWidgets(
    'A foreground event queues an immediate second refresh when a list request is already in flight',
    (tester) async {
      final response = Completer<http.Response>();
      final events = StreamController<VolunteerNotificationEvent>();
      var availableRequests = 0;
      final repo = ApiVolunteerRepository(
        token: () async => 'token',
        baseUrl: 'http://localhost',
        client: MockClient((request) async {
          final path = request.url.path;
          if (path == '/v1/volunteer') return json(profile());
          if (path.endsWith('/state')) {
            return json({'id': 'RD-real', 'status': 'report_received'});
          }
          if (path.endsWith('/available')) {
            availableRequests++;
            if (availableRequests == 1) return response.future;
            return json([caseData()]);
          }
          if (path.endsWith('/photo')) return http.Response('', 404);
          return json([]);
        }),
      );
      addTearDown(repo.dispose);
      addTearDown(events.close);
      await repo.loadProfile();
      await tester.pumpWidget(
        harness(
          VolunteerWorkspace(
            account: repo.account!,
            repository: repo,
            notificationEvents: events.stream,
            onLogout: () async {},
          ),
          'en',
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(availableRequests, 1);
      events.add(
        const VolunteerNotificationEvent(
          id: 'RD-real-new',
          caseId: 'RD-real',
          kind: AlertKind.newCase,
        ),
      );
      await tester.pump();
      expect(find.text('New Case Alert'), findsOneWidget);
      response.complete(json([]));
      await tester.pumpAndSettle();
      expect(availableRequests, 2);
      expect(repo.cases.single.id, 'RD-real');
      expect(repo.error, isNull);
      events.add(
        const VolunteerNotificationEvent(
          id: 'RD-real-new',
          caseId: 'RD-real',
          kind: AlertKind.newCase,
        ),
      );
      await tester.pumpAndSettle();
      expect(availableRequests, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'A delayed pre-join refresh cannot undo a newer successful join',
    () async {
      final stale = Completer<http.Response>();
      var block = false;
      var joined = false;
      final repo = ApiVolunteerRepository(
        token: () async => 'token',
        baseUrl: 'http://localhost',
        client: MockClient((request) async {
          final path = request.url.path;
          if (path == '/v1/volunteer') return json(profile());
          if (path.endsWith('/start-search')) {
            joined = true;
            return json(caseData(joined: true, status: 'search_in_progress'));
          }
          if (path.endsWith('/available')) {
            if (block) return stale.future;
            return json(joined ? [] : [caseData()]);
          }
          if (path.endsWith('/mine')) {
            return json(
              joined
                  ? [caseData(joined: true, status: 'search_in_progress')]
                  : [],
            );
          }
          if (path.endsWith('/photo')) return http.Response('', 404);
          return json([]);
        }),
      );
      addTearDown(repo.dispose);
      await repo.refresh();
      final item = repo.cases.single;
      block = true;
      final old = repo.refresh();
      await pumpEventQueue();
      await repo.startSearch(repo.account!, item);
      expect(
        repo.myCases('server-uid').single.status,
        CaseStatus.searchInProgress,
      );
      block = false;
      stale.complete(json([caseData()]));
      await old;
      await pumpEventQueue();
      expect(repo.availableFor('server-uid'), isEmpty);
      expect(
        repo.myCases('server-uid').single.status,
        CaseStatus.searchInProgress,
      );
    },
  );

  test('Authoritative cancellation removes cached cases and retains correctly parsed history', () async {
    var cancelled = false;
    var failCases = false;
    final repo = ApiVolunteerRepository(
      token: () async => 'token',
      baseUrl: 'http://localhost',
      client: MockClient((request) async {
        final path = request.url.path;
        if (path == '/v1/volunteer') return json(profile());
        if (path.endsWith('/available')) {
          return failCases
              ? http.Response('', 503)
              : json(cancelled ? [] : [caseData()]);
        }
        if (path.endsWith('/notifications')) {
          return json(
            cancelled
                ? [
                    {
                      'id': 'RD-real-cancelled',
                      'case_id': 'RD-real',
                      'kind': 'cancelled',
                      'status': 'cancelled',
                      'created_at': '2026-09-21T10:00:00Z',
                      'read_at': null,
                    },
                  ]
                : [],
          );
        }
        if (path.endsWith('/photo')) return http.Response('', 404);
        return json([]);
      }),
    );
    addTearDown(repo.dispose);
    await repo.refresh();
    failCases = true;
    await expectLater(repo.refresh(), throwsStateError);
    expect(repo.cases.single.id, 'RD-real');
    failCases = false;
    cancelled = true;
    await repo.refresh();
    expect(repo.cases, isEmpty);
    expect(repo.alertsFor('server-uid').single.kind, AlertKind.cancelled);
    expect(repo.alertsFor('server-uid').single.status, isNull);
    expect(repo.error, isNull);
  });

  test('Notification failure preserves successfully loaded real-shaped cases and retries', () async {
    var failAlerts = true;
    final repo = ApiVolunteerRepository(
      token: () async => 'token',
      baseUrl: 'http://localhost',
      client: MockClient((request) async {
        final path = request.url.path;
        if (path == '/v1/volunteer') return json(profile());
        if (path.endsWith('/cases/available')) return json([caseData()]);
        if (path.endsWith('/notifications') && failAlerts) {
          return http.Response('{}', 503);
        }
        if (path.endsWith('/photo')) return http.Response('', 404);
        return json([]);
      }),
    );
    addTearDown(repo.dispose);
    await expectLater(repo.refresh(), throwsStateError);
    expect(repo.cases.single.id, 'RD-real');
    expect(repo.error, isNotNull);
    failAlerts = false;
    await repo.refresh();
    expect(repo.error, isNull);
    expect(repo.cases.single.id, 'RD-real');
  });

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
    await pumpEventQueue(); // private photos now enrich independently of lists
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
      await pumpEventQueue();
      active = false;
      await expectLater(repo.refresh(), throwsStateError);
      expect(lostReason, 'volunteer_inactive');
      expect(repo.account, isNull);
      expect(repo.profiles, isEmpty);
      expect(repo.foundReports, isEmpty);
      expect(repo.cases, isEmpty);
    },
  );

  test('Transient backend failure preserves last successful cases without sample data', () async {
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
    expect(repo.cases.single.id, 'RD-real');
    expect(repo.connected, isFalse);
    expect(repo.profiles, isEmpty);
    expect(repo.alertsFor('server-uid'), isEmpty);
  });

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
      expect(find.text('اسم'), findsWidgets);
      expect(repo.cases.single.id, 'RD-real');
      final navigation = tester.widget<GuardianNavigation>(
        find.byType(GuardianNavigation),
      );
      navigation.onSelected!(4);
      await tester.pumpAndSettle();
      expect(find.text('real@example.test'), findsOneWidget);
      navigation.onSelected!(3);
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
