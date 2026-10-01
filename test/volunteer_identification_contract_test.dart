import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:radd/features/volunteer/data/api_volunteer_repository.dart';
import 'package:radd/features/volunteer/domain/volunteer_models.dart';

void main() {
  test('Identification boundary preserves unavailable, empty and real candidate states', () async {
    var response = <String, dynamic>{'state': 'unavailable', 'candidates': []};
    final repo = ApiVolunteerRepository(
      token: () async => 'test-token',
      baseUrl: 'http://test',
      client: MockClient(
        (request) async => http.Response(
          jsonEncode(
            request.url.path == '/v1/volunteer'
                ? {
                    'uid': 'test',
                    'full_name': 'Test',
                    'volunteer_id': 'V-TEST',
                    'active': true,
                    'consent_current': true,
                    'assigned': true,
                    'event_id': 'event',
                  }
                : response,
          ),
          200,
        ),
      ),
    );
    addTearDown(repo.dispose);
    await repo.loadProfile();
    final report = FoundReport(
      id: 'test-report',
      volunteerUid: 'test',
      photo: '',
    );
    await expectLater(repo.findMatches(report), throwsStateError);
    response = {'state': 'no_reliable_candidate', 'candidates': []};
    expect(await repo.findMatches(report), isEmpty);
    Map<String, dynamic> candidate(String id, double score) => {
      'person': {
        'id': id,
        'full_name': 'Fixture $id',
        'age': 7,
        'gender': 'female',
      },
      'similarity': score,
    };
    response = {
      'state': 'candidates',
      'candidates': [candidate('lower', .7), candidate('higher', .9)],
    };
    final candidates = await repo.findMatches(report);
    expect(candidates.map((c) => c.person.id), ['higher', 'lower']);
    expect(report.matchedPerson, isNull);
    response = {
      'state': 'candidates',
      'candidates': [candidate('invalid', 3)],
    };
    await expectLater(repo.findMatches(report), throwsStateError);
  });

  test('Authoritative registrations survive a stale closed case in the local cache', () async {
    final repo = ApiVolunteerRepository(
      token: () async => 'test-token',
      baseUrl: 'http://test',
      client: MockClient((request) async {
        final path = request.url.path;
        Object response = [];
        if (path == '/v1/volunteer') {
          response = {
            'uid': 'test',
            'full_name': 'Test',
            'volunteer_id': 'V-TEST',
            'active': true,
            'consent_current': true,
            'assigned': true,
            'event_id': 'event',
          };
        }
        if (path.endsWith('/cases/mine')) {
          response = [
            {
              'id': 'old-case',
              'individual_id': 'person',
              'individual_name': 'Person',
              'age': 7,
              'status': 'reunited',
              'joined': true,
              'confirmed_by_me': true,
              'created_at': '2026-09-01T08:00:00Z',
              'updated_at': '2026-09-01T09:00:00Z',
            },
          ];
        }
        if (path.endsWith('/profiles')) {
          response = [
            {
              'id': 'person',
              'full_name': 'Person',
              'age': 7,
              'gender': 'female',
            },
          ];
        }
        if (path.endsWith('/photo')) return http.Response('', 404);
        if (path.endsWith('/profiles/person')) {
          response = {
            'id': 'person',
            'full_name': 'Person',
            'age': 7,
            'gender': 'female',
            'confirmation_available': false,
          };
        }
        return http.Response(jsonEncode(response), 200);
      }),
    );
    addTearDown(repo.dispose);
    await repo.refresh();
    await repo.loadProfiles();
    expect(repo.cases.single.status, CaseStatus.reunited);
    expect(repo.reviewableProfiles.single.id, 'person');
    final person = await repo.loadProfileDetails(
      repo.profiles.single,
      foundReportId: 'test-report',
    );
    expect(person.confirmationAvailable, isFalse);
    expect(person.guardian.phone, isNull);
  });
}
