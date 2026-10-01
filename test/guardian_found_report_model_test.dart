import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:radd/features/guardian/data/guardian_api.dart';
import 'package:radd/features/guardian/data/guardian_repository.dart';

/// The Guardian-facing contract of GET /v1/guardian/found-reports: the value
/// the Guardian reads out is `verification_code`; the document id is carried
/// only as an internal handle and is never used as the verification value.
void main() {
  test(
    'Guardian API maps verification_code and individual_name, not the id',
    () async {
      final api = GuardianApi(
        token: () async => 'unit-test',
        baseUrl: 'http://test',
        client: MockClient((request) async {
          expect(request.url.path, '/v1/guardian/found-reports');
          return http.Response(
            jsonEncode([
              {
                'id': 'FR-2b6e7a21402fd4f5b06012df4afbfffb7b738545',
                'status': 'awaiting_guardian_verification',
                'individual_id': 'ind-1',
                'individual_name': 'Sara Test',
                'verification_code': '482913',
              },
              {
                'id': 'FR-legacy',
                'status': 'identity_confirmed',
                'individual_id': 'ind-2',
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final reports = await api.activeFoundReports();
      expect(reports, hasLength(2));
      expect(reports[0].verificationCode, '482913');
      expect(reports[0].verificationCode, isNot(contains('FR-')));
      expect(reports[0].individualName, 'Sara Test');
      expect(reports[0].awaitingVerification, isTrue);
      expect(reports[1].verificationCode, isNull);
      expect(reports[1].individualName, isNull);
      expect(reports[1].awaitingVerification, isTrue);
    },
  );

  test('Only identity_confirmed and awaiting stages show verification', () {
    for (final status in [
      'identification_in_progress',
      'reunited',
      'ended',
      '',
    ]) {
      expect(
        GuardianFoundReport(id: 'FR-x', status: status).awaitingVerification,
        isFalse,
        reason: status,
      );
    }
    for (final status in GuardianFoundReport.verificationStages) {
      expect(
        GuardianFoundReport(id: 'FR-x', status: status).awaitingVerification,
        isTrue,
      );
    }
  });
}
