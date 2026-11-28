import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:radd/features/volunteer/data/api_volunteer_repository.dart';

class _Backend {
  final requests = <String>[];
  var available = <Map<String, dynamic>>[];
  var mine = <Map<String, dynamic>>[];
  final pendingPhotos = <String, Completer<http.Response>>{};
  bool holdPhotos = false;
  Map<String, dynamic>? report;

  int count(String method, String path) =>
      requests.where((r) => r == '$method $path').length;
  int get photoRequests => requests.where((r) => r.endsWith('/photo')).length;
  int get total => requests.length;

  static Map<String, dynamic> caseRow(
    String id, {
    bool photoAvailable = true,
    String status = 'report_received',
  }) => {
    'id': id,
    'individual_id': 'person-$id',
    'individual_name': 'Person $id',
    'age': 7,
    'gender': 'female',
    'status': status,
    'joined': false,
    'confirmed_by_me': false,
    'photo_available': photoAvailable,
    'created_at': '2026-09-01T08:00:00Z',
    'updated_at': '2026-09-01T09:00:00Z',
  };

  static http.Response json(Object value) => http.Response(
    jsonEncode(value),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  late final client = MockClient((request) async {
    final path = request.url.path.replaceFirst('/v1/volunteer', '');
    requests.add('${request.method} $path');
    if (path.isEmpty) {
      return json({
        'uid': 'server-uid',
        'full_name': 'Volunteer',
        'volunteer_id': 'V-42',
        'consent_current': true,
        'assigned': true,
        'event_id': 'test-event',
        'active': true,
      });
    }
    if (path == '/cases/available') return json(available);
    if (path == '/cases/mine') return json(mine);
    if (path == '/found-reports') return json([]);
    if (path == '/notifications') return json([]);
    if (path == '/notifications/read-all') return http.Response('', 204);
    if (path.endsWith('/state')) return json({'status': 'search_in_progress'});
    if (path.startsWith('/cases/') && path.endsWith('/photo')) {
      if (holdPhotos) {
        final completer = Completer<http.Response>();
        pendingPhotos[path] = completer;
        return completer.future;
      }
      return http.Response.bytes([1, 2, 3], 200);
    }
    if (path == '/found-reports/FR-1') return json(report!);
    if (path.startsWith('/found-reports/FR-1/')) {
      return http.Response.bytes([4, 5, 6], 200);
    }
    return http.Response('', 404);
  });
}

void main() {
  late _Backend backend;
  late ApiVolunteerRepository repo;

  setUp(() {
    backend = _Backend();
    repo = ApiVolunteerRepository(
      token: () async => 'jwt',
      baseUrl: 'http://test',
      client: backend.client,
    );
  });
  tearDown(() => repo.dispose());

  Future<void> pollCycle() async {
    await repo.loadProfile();
    await repo.refresh(profileLoaded: true);
    await pumpEventQueue();
  }

  test('A poll cycle loads the profile once and unchanged case photos are '
      'not downloaded again', () async {
    backend.available = [_Backend.caseRow('RD-1'), _Backend.caseRow('RD-2')];
    await pollCycle();
    expect(backend.count('GET', ''), 1);
    expect(backend.photoRequests, 2);
    final first = repo.caseById('RD-1')!.person.photoBytes;
    expect(first, [1, 2, 3]);

    backend.requests.clear();
    await pollCycle();
    expect(backend.count('GET', ''), 1);
    expect(backend.photoRequests, 0);
    expect(backend.total, 5);
    expect(identical(repo.caseById('RD-1')!.person.photoBytes, first), isTrue);
  });

  test(
    'A photo that becomes unavailable is dropped and never re-applied',
    () async {
      backend.available = [_Backend.caseRow('RD-1')];
      await pollCycle();
      expect(repo.caseById('RD-1')!.person.photoBytes, isNotNull);

      backend.available = [_Backend.caseRow('RD-1', photoAvailable: false)];
      await pollCycle();
      expect(repo.caseById('RD-1')!.person.photoBytes, isNull);

      backend.available = [_Backend.caseRow('RD-1')];
      backend.requests.clear();
      await pollCycle();
      expect(backend.photoRequests, 1);
    },
  );

  test('A case that leaves the lists loses its cached photo', () async {
    backend.available = [_Backend.caseRow('RD-1')];
    await pollCycle();
    backend.available = [];
    await pollCycle();
    backend.available = [_Backend.caseRow('RD-1')];
    backend.requests.clear();
    await pollCycle();
    expect(backend.photoRequests, 1);
  });

  test('Overlapping refreshes download each photo once', () async {
    backend.available = [_Backend.caseRow('RD-1')];
    backend.holdPhotos = true;
    await pollCycle();
    await repo.refreshEvent();
    await pumpEventQueue();
    expect(backend.photoRequests, 1);
    backend.pendingPhotos.values.single.complete(
      http.Response.bytes([7, 8, 9], 200),
    );
    await pumpEventQueue();
    expect(repo.caseById('RD-1')!.person.photoBytes, [7, 8, 9]);
  });

  test('A photo arriving after event data was cleared is discarded', () async {
    backend.available = [_Backend.caseRow('RD-1')];
    backend.holdPhotos = true;
    await pollCycle();
    repo.clearEventData();
    backend.pendingPhotos.values.single.complete(
      http.Response.bytes([7, 8, 9], 200),
    );
    await pumpEventQueue();
    expect(repo.cases, isEmpty);

    backend.holdPhotos = false;
    backend.requests.clear();
    await pollCycle();
    expect(backend.photoRequests, 1);
    expect(repo.caseById('RD-1')!.person.photoBytes, [1, 2, 3]);
  });

  test('Revoked access clears photos and ignores late responses', () async {
    backend.available = [_Backend.caseRow('RD-1')];
    backend.holdPhotos = true;
    await pollCycle();
    repo.clearProtectedData();
    backend.pendingPhotos.values.single.complete(
      http.Response.bytes([7, 8, 9], 200),
    );
    await pumpEventQueue();
    expect(repo.cases, isEmpty);
    expect(repo.account, isNull);
  });

  test('Navigation list refreshes are skipped while fresh, join a running '
      'refresh, and run again once stale', () async {
    backend.available = [_Backend.caseRow('RD-1')];
    await pollCycle();
    backend.requests.clear();
    await repo.refreshLists();
    await repo.refreshLists();
    expect(backend.total, 0);

    await repo.refreshLists(freshness: Duration.zero);
    await pumpEventQueue();
    expect(backend.count('GET', '/cases/available'), 1);
    expect(backend.photoRequests, 0);

    backend.requests.clear();
    final poll = repo.refresh();
    final joined = repo.refreshLists(freshness: Duration.zero);
    await Future.wait([poll, joined]);
    expect(backend.count('GET', '/cases/available'), 1);
  });

  test('An FCM event refresh is never merged away by a running poll', () async {
    backend.available = [_Backend.caseRow('RD-1')];
    await pollCycle();
    backend.requests.clear();
    final poll = repo.refresh();
    final event = repo.refreshEvent(caseId: 'RD-1');
    await Future.wait([poll, event]);
    expect(backend.count('GET', '/cases/RD-1/state'), 1);
    expect(repo.caseStates['RD-1'], 'search_in_progress');
  });

  test('Marking notifications read refreshes only notifications', () async {
    backend.available = [_Backend.caseRow('RD-1')];
    await pollCycle();
    backend.requests.clear();
    await repo.markAllRead('server-uid');
    expect(backend.requests, [
      'PUT /notifications/read-all',
      'GET /notifications',
    ]);
  });

  test('Refreshing an open found report reuses its photographs', () async {
    backend.report = {
      'id': 'FR-1',
      'created_at': '2026-09-01T08:00:00Z',
      'found_status': 'identification_in_progress',
      'photo_available': true,
    };
    await repo.loadProfile();
    final first = await repo.loadReport('FR-1');
    expect(first.photoBytes, [4, 5, 6]);
    backend.requests.clear();
    final second = await repo.loadReport('FR-1', previous: first);
    expect(backend.requests, ['GET /found-reports/FR-1']);
    expect(identical(second.photoBytes, first.photoBytes), isTrue);

    backend.report = {...backend.report!, 'photo_available': false};
    final third = await repo.loadReport('FR-1', previous: second);
    expect(third.photoBytes, isNull);
  });
}
