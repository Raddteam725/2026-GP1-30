import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:radd/features/volunteer/data/api_volunteer_repository.dart';
import 'package:radd/features/volunteer/domain/volunteer_models.dart';

void main() {
  test('Standalone report parses confirmation, identifier proof and minimal handover without case ID', () async {
    final reportData = <String, dynamic>{
      'id': 'FR-test',
      'event_id': 'test-event',
      'created_at': '2026-09-28T08:00:00Z',
      'status': 'identification_in_progress',
      'case_id': null,
      'photo_available': true,
    };
    final person = <String, dynamic>{
      'id': 'person',
      'full_name': 'Test Person',
      'age': 7,
      'gender': 'female',
    };
    final repo = ApiVolunteerRepository(
      token: () async => 'test',
      baseUrl: 'http://test',
      client: MockClient((request) async {
        final path = request.url.path;
        Object response = [];
        if (path == '/v1/volunteer') {
          response = {
            'uid': 'test',
            'full_name': 'Volunteer',
            'volunteer_id': 'TEST',
            'active': true,
            'consent_current': true,
            'assigned': true,
            'event_id': 'test-event',
          };
        }
        if (path.endsWith('/profiles')) response = [person];
        if (request.method == 'POST' && path.endsWith('/found-reports')) {
          response = reportData;
        }
        if (path.endsWith('/confirm-match')) {
          reportData.addAll({
            'status': 'identity_confirmed',
            'matched_profile_id': 'person',
            'photo_available': false,
            'person': {
              ...person,
              'guardian': {'full_name': 'Guardian', 'phone': '0500000000'},
            },
          });
          response = reportData;
        }
        if (path.endsWith('/begin-verification')) {
          reportData['status'] = 'awaiting_guardian_verification';
          response = reportData;
        }
        if (path.endsWith('/verify-identifier')) {
          expect(jsonDecode(request.body), {'identifier': 'FR-test'});
          reportData['verification'] = {
            'context_id': 'FR-test',
            'context_type': 'found_report',
            'method': 'found_identifier',
            'guardian_id': 'guardian',
            'volunteer_uid': 'test',
            'verified_at': '2026-09-28T08:05:00Z',
          };
          response = {'verified': true, 'report': reportData};
        }
        if (path.endsWith('/handover')) {
          response = {
            'id': 'FR-test',
            'created_at': '2026-09-28T08:00:00Z',
            'status': 'reunited',
            'handed_over_at': '2026-09-28T08:10:00Z',
            'handed_over_by': 'test',
            'photo_available': false,
          };
        }
        return http.Response(jsonEncode(response), 200);
      }),
    );
    addTearDown(repo.dispose);
    await repo.loadProfile();
    final account = repo.account!;
    final report = await repo.submitFound(
      account,
      photo: Uint8List.fromList([1]),
      requestId: 'test-request',
    );
    expect(report.foundStatus, FoundStatus.identifying);
    await repo.loadProfiles();
    await repo.confirmMatch(account, report, repo.profiles.single);
    expect(report.caseId, isNull);
    expect(report.photoBytes, isNull);
    expect(report.foundStatus, FoundStatus.identified);
    expect(report.matchedPerson!.guardian.phone, '0500000000');
    await repo.beginVerification(account, report);
    expect(report.foundStatus, FoundStatus.verifying);
    expect(
      await repo.verify(
        account,
        report,
        VerificationMethod.caseIdentifier,
        'FR-test',
        authenticatedAccountShown: true,
      ),
      isTrue,
    );
    expect(report.verification!.caseId, 'FR-test');
    await repo.handover(account, report);
    expect(report.status, CaseStatus.reunited);
    expect(report.matchedPerson, isNull);
    expect(report.verification, isNull);
    expect(report.handedOverBy, 'test');
  });
}
