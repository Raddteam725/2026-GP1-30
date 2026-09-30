import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:radd/features/volunteer/data/api_volunteer_repository.dart';
import 'package:radd/features/volunteer/domain/volunteer_models.dart';

void main() {
  test('Guardian identifier endpoint preserves its method through Volunteer receipt', () async {
    var calls = 0;
    final repo = ApiVolunteerRepository(
      token: () async => 'token',
      baseUrl: 'http://localhost',
      client: MockClient((request) async {
        calls++;
        Object body;
        if (request.url.path == '/v1/volunteer') {
          body = {
            'uid': 'volunteer',
            'full_name': 'Volunteer',
            'volunteer_id': 'V-1',
            'consent_current': true,
            'assigned': true,
            'event_id': 'test-event',
            'active': true,
          };
        } else {
          expect(
            request.url.path,
            '/v1/volunteer/found-reports/FR-real/verify-identifier',
          );
          expect(jsonDecode(request.body), {'case_id': '482913'});
          body = {
            'verified': true,
            'report': {
              'id': 'FR-real',
              'created_at': '2026-09-20T08:00:00Z',
              'case_id': 'RD-real',
              'status': 'awaiting_guardian_verification',
              'verification': {
                'method': 'case_identifier',
                'case_id': 'RD-real',
                'guardian_id': 'guardian',
                'volunteer_uid': 'volunteer',
                'verified_at': '2026-09-20T09:00:00Z',
              },
            },
          };
        }
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(repo.dispose);
    final account = await repo.loadProfile();
    final report = FoundReport(
      id: 'FR-real',
      caseId: 'RD-real',
      volunteerUid: account.uid,
      photo: '',
    );
    await expectLater(
      repo.verify(account, report, VerificationMethod.caseIdentifier, '482913'),
      throwsStateError,
    );
    expect(calls, 1);
    expect(
      await repo.verify(
        account,
        report,
        VerificationMethod.caseIdentifier,
        '482913',
        authenticatedAccountShown: true,
      ),
      isTrue,
    );
    expect(report.verification!.method, VerificationMethod.caseIdentifier);
    expect(report.status, CaseStatus.awaitingGuardianVerification);
  });
}
