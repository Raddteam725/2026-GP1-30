import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:radd/features/guardian/data/guardian_api.dart';
import 'package:radd/features/guardian/data/guardian_repository.dart';

/// Arabic must survive the round trip to the backend unchanged. FastAPI
/// answers `application/json` WITHOUT a charset parameter; package:http then
/// decodes `Response.body` as Latin-1, which is exactly how "the assistant
/// does not accept Arabic" looked: the saved answer came back as mojibake.
void main() {
  const arabicName = 'سارة الأحمد';
  const arabicAnswer = 'عباءة سوداء وحقيبة زرقاء';
  const arabicDetail = 'ملغي';

  Map<String, dynamic> caseJson({String? clothing}) => {
    'id': 'RD-1',
    'individual_id': 'i1',
    'individual_name': arabicName,
    'age': 7,
    'event_id': 'e1',
    'status': 'report_received',
    'created_at': '2026-09-21T10:00:00Z',
    'updated_at': '2026-09-21T10:00:00Z',
    'stage_timestamps': {},
    'guided_report': clothing == null
        ? null
        : {'completed': false, 'clothing': clothing},
  };

  // A server that speaks UTF-8 but, like FastAPI, never says so.
  http.Response utf8Json(Object body) => http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    200,
    headers: {'content-type': 'application/json'},
  );

  test(
    'Arabic in responses is decoded as UTF-8 without a charset header',
    () async {
      final api = GuardianApi(
        token: () async => 'jwt',
        baseUrl: 'http://test',
        client: MockClient((request) async {
          if (request.url.path == '/v1/cases') return utf8Json([caseJson()]);
          if (request.url.path == '/v1/cases/RD-1') {
            return utf8Json(caseJson(clothing: arabicAnswer));
          }
          if (request.url.path == '/v1/notifications') {
            return utf8Json([
              {
                'id': 'n1',
                'case_id': 'RD-1',
                'status': 'cancelled',
                'read_at': null,
                'created_at': '2026-09-21T10:00:00Z',
              },
            ]);
          }
          return http.Response('not found', 404);
        }),
      );
      expect((await api.cases()).single.name, arabicName);
      final detail = await api.missingCase('RD-1');
      expect(detail.name, arabicName);
      expect(detail.report!['clothing'], arabicAnswer);
      expect((await api.notifications()).single.status, 'cancelled');
    },
  );

  test(
    'Arabic answers are sent to the backend as UTF-8 and read back intact',
    () async {
      Map<String, dynamic>? received;
      final api = GuardianApi(
        token: () async => 'jwt',
        baseUrl: 'http://test',
        client: MockClient((request) async {
          expect(request.method, 'PUT');
          expect(request.url.path, '/v1/cases/RD-1/guided-report');
          // What the server actually sees on the wire.
          received = jsonDecode(utf8.decode(request.bodyBytes));
          return utf8Json(caseJson(clothing: received!['clothing'] as String));
        }),
      );
      final saved = await api.saveGuidedReport('RD-1', {
        'completed': false,
        'clothing': arabicAnswer,
      });
      expect(received!['clothing'], arabicAnswer);
      expect(saved.report!['clothing'], arabicAnswer);
    },
  );

  test('Backend error details are decoded the same way', () async {
    final api = GuardianApi(
      token: () async => 'jwt',
      baseUrl: 'http://test',
      client: MockClient(
        (request) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({'detail': 'case_closed', 'note': arabicDetail}),
          ),
          409,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    await expectLater(
      api.cancelCase('RD-1'),
      throwsA(isA<AppFailure>().having((f) => f.code, 'code', 'caseClosed')),
    );
  });
}
