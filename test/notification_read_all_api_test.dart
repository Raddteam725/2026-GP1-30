import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:radd/features/guardian/data/guardian_api.dart';
import 'package:radd/features/volunteer/data/api_volunteer_repository.dart';

void main() {
  test('Guardian marks all read with one authenticated bulk request', () async {
    final requests = <http.Request>[];
    final api = GuardianApi(
      token: () async => 'jwt',
      baseUrl: 'http://test',
      client: MockClient((request) async {
        requests.add(request);
        return http.Response('', 204);
      }),
    );
    await api.readAllNotifications();
    expect(requests, hasLength(1));
    expect(requests.single.method, 'PUT');
    expect(requests.single.url.path, '/v1/notifications/read-all');
    expect(requests.single.headers['Authorization'], 'Bearer jwt');
  });

  for (final fails in [false, true]) {
    test(
      'Volunteer bulk read preserves new arrivals and failures (fails=$fails)',
      () async {
        var read = false;
        var bulkCalls = 0;
        http.Response json(Object value) => http.Response(
          jsonEncode(value),
          200,
          headers: {'content-type': 'application/json'},
        );
        Map<String, Object?> alert(String id, bool isRead) => {
          'id': id,
          'case_id': 'RD-$id',
          'kind': 'new_case',
          'status': 'report_received',
          'created_at': '2026-10-20T10:00:00Z',
          'read_at': isRead ? '2026-10-20T11:00:00Z' : null,
        };
        final repo = ApiVolunteerRepository(
          token: () async => 'jwt',
          baseUrl: 'http://test',
          client: MockClient((request) async {
            if (request.url.path == '/v1/volunteer') {
              return json({
                'uid': 'one',
                'full_name': 'Volunteer',
                'volunteer_id': 'VOL-1',
                'active': true,
                'assigned': true,
                'event_id': 'test-event',
                'consent_current': true,
              });
            }
            if (request.url.path.endsWith('/read-all')) {
              bulkCalls++;
              if (fails) return http.Response('{}', 503);
              read = true;
              return http.Response('', 204);
            }
            if (request.url.path.endsWith('/notifications')) {
              return json([
                alert('existing', read),
                if (read) alert('new', false),
              ]);
            }
            return json([]);
          }),
        );
        addTearDown(repo.dispose);
        await repo.refresh();
        expect(repo.alertsFor('one').single.readAt, isNull);
        await expectLater(repo.markAllRead('other'), throwsStateError);
        expect(bulkCalls, 0);
        if (fails) {
          await expectLater(repo.markAllRead('one'), throwsStateError);
          expect(repo.alertsFor('one').single.readAt, isNull);
        } else {
          await repo.markAllRead('one');
          expect(
            repo.alertsFor('one').singleWhere((a) => a.id == 'existing').readAt,
            isNotNull,
          );
          expect(
            repo.alertsFor('one').singleWhere((a) => a.id == 'new').readAt,
            isNull,
          );
        }
        expect(bulkCalls, 1);
      },
    );
  }
}
