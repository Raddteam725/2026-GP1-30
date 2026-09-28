import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:radd/features/volunteer/data/api_volunteer_repository.dart';
import 'package:radd/features/volunteer/domain/volunteer_models.dart';

void main() {
  test('Real API workflow persists report, resumes, confirms manual match, verifies QR and hands over', () async {
    final requests = <http.Request>[];
    var submitted = false;
    String? status;
    var verified = false;
    const timestamp = '2026-09-14T08:00:00Z';
    final person = <String, dynamic>{
      'id': 'profile-key',
      'full_name': 'Registered Person',
      'age': 8,
      'gender': 'female',
      'relationship': 'daughter',
    };
    Map<String, dynamic> report() => {
      'id': 'FR-real',
      'created_at': timestamp,
      'ai_status': 'unavailable',
      'case_id': status == null ? null : 'RD-real',
      'status': status,
      'matched_profile_id': status == null ? null : person['id'],
      if (status != null)
        'person': {
          ...person,
          'guardian': {'full_name': 'Real Guardian', 'phone': '+966500000003'},
        },
      'verification': verified
          ? {
              'method': 'qr',
              'guardian_id': 'guardian',
              'case_id': 'RD-real',
              'volunteer_uid': 'volunteer',
              'verified_at': timestamp,
            }
          : null,
      'handed_over_by': status == 'reunited' ? 'volunteer' : null,
      'handed_over_at': status == 'reunited' ? timestamp : null,
    };
    http.Response json(Object value) => http.Response(
      jsonEncode(value),
      200,
      headers: {'content-type': 'application/json'},
    );
    Future<http.Response> handler(http.Request request) async {
      requests.add(request);
      expect(request.headers['Authorization'], 'Bearer firebase-token');
      final path = request.url.path;
      if (path == '/v1/volunteer') {
        return json({
          'uid': 'volunteer',
          'full_name': 'Real Volunteer',
          'volunteer_id': 'V-1',
          'consent_current': true,
          'assigned': true,
          'event_id': 'test-event',
          'active': true,
        });
      }
      if (path.endsWith('/photo') || path.endsWith('/registered-photo')) {
        return http.Response.bytes([1, 2, 3], 200);
      }
      if (path.endsWith('/cases/available') || path.endsWith('/cases/mine')) {
        return json([]);
      }
      if (path.endsWith('/notifications')) {
        return json([
          {
            'id': 'notification-1',
            'case_id': 'RD-real',
            'created_at': timestamp,
            'kind': 'status_update',
            'status': 'match_confirmed',
            'read_at': null,
          },
        ]);
      }
      if (path.endsWith('/profiles')) return json([person]);
      if (path.endsWith('/profiles/profile-key')) {
        return json({
          ...person,
          if (request.url.queryParameters['found_report_id'] == 'FR-real')
            'guardian': {
              'full_name': 'Real Guardian',
              'phone': '+966500000003',
            },
        });
      }
      if (path.endsWith('/found-reports')) {
        if (request.method == 'POST') {
          final body = jsonDecode(request.body) as Map;
          expect(body.keys, unorderedEquals(['request_id', 'photo_base64']));
          expect(base64Decode(body['photo_base64'] as String), [1, 2, 3]);
          submitted = true;
          return json(report());
        }
        return json(submitted ? [report()] : []);
      }
      if (path.endsWith('/candidates')) {
        return json({'state': 'unavailable', 'candidates': []});
      }
      if (path.endsWith('/confirm-match')) {
        expect(jsonDecode(request.body), {'profile_id': 'profile-key'});
        status = 'match_confirmed';
        return json(report());
      }
      if (path.endsWith('/begin-verification')) {
        status = 'awaiting_guardian_verification';
        return json(report());
      }
      if (path.endsWith('/verify')) {
        verified = jsonDecode(request.body)['payload'] == 'guardian-issued-qr';
        return json({'verified': verified, 'report': report()});
      }
      if (path.endsWith('/handover')) {
        expect(verified, isTrue);
        status = 'reunited';
        return json(report());
      }
      if (path.endsWith('/FR-real')) return json(report());
      throw StateError('Unexpected route $path');
    }

    ApiVolunteerRepository repository() => ApiVolunteerRepository(
      token: () async => 'firebase-token',
      baseUrl: 'http://localhost:8000',
      client: MockClient(handler),
    );
    var repo = repository();
    await repo.refresh();
    final found = await repo.submitFound(
      repo.account!,
      photo: Uint8List.fromList([1, 2, 3]),
      requestId: 'request-000000000001',
    );
    expect(found.id, 'FR-real');
    await expectLater(repo.findMatches(found), throwsStateError);
    await repo.loadProfiles();
    expect(repo.profiles.single.guardian.phone, isNull);
    expect(repo.profiles.single.photoBytes, [1, 2, 3]);
    final browsing = await repo.loadProfileDetails(repo.profiles.single);
    expect(browsing.guardian.phone, isNull);
    final contextual = await repo.loadProfileDetails(
      repo.profiles.single,
      foundReportId: found.id,
    );
    expect(contextual.guardian.phone, '+966500000003');
    await repo.confirmMatch(repo.account!, found, repo.profiles.single);
    expect(found.status, CaseStatus.matchConfirmed);
    expect(found.matchedPerson!.guardian.phone, '+966500000003');
    expect(found.matchedPerson!.photoBytes, [1, 2, 3]);
    repo.dispose(); // Restart: only the server-side report carries progress.
    repo = repository();
    await repo.refresh();
    expect(repo.foundReports.single.caseId, 'RD-real');
    final resumed = await repo.loadReport('FR-real');
    expect(resumed.matchedPerson!.guardian.name.en, 'Real Guardian');
    await repo.beginVerification(repo.account!, resumed);
    expect(
      await repo.verify(
        repo.account!,
        resumed,
        VerificationMethod.qr,
        'bad-qr',
      ),
      isFalse,
    );
    expect(resumed.verification, isNull);
    expect(
      await repo.verify(
        repo.account!,
        resumed,
        VerificationMethod.qr,
        'guardian-issued-qr',
      ),
      isTrue,
    );
    await repo.handover(repo.account!, resumed);
    expect(resumed.status, CaseStatus.reunited);
    expect(resumed.handedOverBy, 'volunteer');
    expect(resumed.handedOverAt, DateTime.parse(timestamp));
    expect(repo.alertsFor('someone-else'), isEmpty);
    expect(repo.alertsFor('volunteer').single.caseId, 'RD-real');
    expect(
      requests
          .where((r) => r.method == 'POST')
          .every((r) => !r.body.contains('volunteer_uid')),
      isTrue,
    );
    repo.dispose();
  });
}
