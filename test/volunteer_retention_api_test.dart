import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:radd/features/volunteer/data/api_volunteer_repository.dart';
import 'package:radd/features/volunteer/domain/volunteer_models.dart';

http.Response json(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: {'content-type': 'application/json'},
);
const account = {
  'uid': 'v',
  'full_name': 'Volunteer',
  'volunteer_id': 'V-1',
  'active': true,
};

void main() {
  test(
    'Begin verification succeeds independently of failed list refresh',
    () async {
      final repo = ApiVolunteerRepository(
        token: () async => 'token',
        baseUrl: 'http://localhost',
        client: MockClient((request) async {
          if (request.url.path == '/v1/volunteer') return json(account);
          if (request.url.path.endsWith('/begin-verification')) {
            return json({
              'id': 'FR-1',
              'created_at': '2026-09-20T08:00:00Z',
              'case_id': 'RD-1',
              'status': 'awaiting_guardian_verification',
              'photo_available': false,
            });
          }
          return http.Response('{"detail":"service_unavailable"}', 503);
        }),
      );
      addTearDown(repo.dispose);
      final user = await repo.loadProfile();
      await expectLater(repo.refresh(), throwsStateError);
      final report = FoundReport(id: 'FR-1', volunteerUid: 'v', photo: '');
      await repo.beginVerification(user, report);
      expect(report.status, CaseStatus.awaitingGuardianVerification);
      expect(report.verification, isNull);
      // A successful transition does not hide an unrelated data error.
      expect(repo.error, isNotNull);
    },
  );

  test('Ended attempt cannot reopen or fetch its deleted image', () async {
    final paths = <String>[];
    final repo = ApiVolunteerRepository(
      token: () async => 'token',
      baseUrl: 'http://localhost',
      client: MockClient((request) async {
        paths.add(request.url.path);
        return json({'id': 'FR-1', 'ended': true, 'photo_available': false});
      }),
    );
    addTearDown(repo.dispose);
    await expectLater(repo.loadReport('FR-1'), throwsStateError);
    expect(paths, ['/v1/volunteer/found-reports/FR-1']);
  });

  test(
    'Confirmed report restores without fetching deleted found photo',
    () async {
      final paths = <String>[];
      final repo = ApiVolunteerRepository(
        token: () async => 'token',
        baseUrl: 'http://localhost',
        client: MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path == '/v1/volunteer') return json(account);
          return json({
            'id': 'FR-1',
            'created_at': '2026-09-20T08:00:00Z',
            'matched_profile_id': 'registered',
            'photo_available': false,
            'status': 'match_confirmed',
          });
        }),
      );
      addTearDown(repo.dispose);
      await repo.loadProfile();
      final report = await repo.loadReport('FR-1');
      expect(report.photoBytes, isNull);
      expect(report.status, CaseStatus.matchConfirmed);
      expect(paths.any((path) => path.endsWith('/photo')), isFalse);
    },
  );

  test('End action targets found report and clears photos when deletion is pending', () async {
    var fail = true;
    final mutations = <String>[];
    final repo = ApiVolunteerRepository(
      token: () async => 'token',
      baseUrl: 'http://localhost',
      client: MockClient((request) async {
        if (request.method == 'POST') {
          mutations.add(request.url.path);
          if (fail) {
            return http.Response('{"detail":"photo_deletion_pending"}', 503);
          }
          return json({
            'id': 'FR-1',
            'created_at': '2026-09-20T08:00:00Z',
            'ended': true,
            'photo_available': false,
          });
        }
        if (request.url.path == '/v1/volunteer') return json(account);
        return json([]);
      }),
    );
    addTearDown(repo.dispose);
    await repo.loadProfile();
    final report = FoundReport(
      id: 'FR-1',
      volunteerUid: 'v',
      photo: '',
      photoBytes: Uint8List.fromList([1, 2, 3]),
    );
    await expectLater(repo.endIdentification(report), throwsStateError);
    fail = false;
    await repo.endIdentification(report);
    expect(report.photoBytes, isNull);
    expect(mutations, [
      '/v1/volunteer/found-reports/FR-1/end',
      '/v1/volunteer/found-reports/FR-1/end',
    ]);
  });

  test('Device location registration carries no client identity and can clear location', () async {
    final bodies = <Map<String, dynamic>>[];
    final repo = ApiVolunteerRepository(
      token: () async => 'token',
      baseUrl: 'http://localhost',
      client: MockClient((request) async {
        expect(request.url.path, '/v1/volunteer/fcm-registrations');
        expect(request.headers['Authorization'], 'Bearer token');
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return json({'registered': true});
      }),
    );
    addTearDown(repo.dispose);
    await repo.registerDevice('fcm', 'ar', const Coordinates(24, 46));
    await repo.registerDevice('fcm', 'ar', null);
    expect(bodies.first, {
      'token': 'fcm',
      'locale': 'ar',
      'latitude': 24.0,
      'longitude': 46.0,
    });
    expect(bodies.last['latitude'], isNull);
    expect(bodies.last['longitude'], isNull);
  });
}
