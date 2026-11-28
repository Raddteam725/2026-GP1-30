import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:radd/features/guardian/data/guardian_api.dart';
import 'package:radd/features/guardian/data/guardian_push_service.dart';
import 'package:radd/features/guardian/data/guardian_repository.dart';

class _Server {
  final requests = <String>[];
  final held = <String, Completer<http.Response>>{};
  final hold = <String>{};
  final failOnce = <String>{};
  var people = <Map<String, dynamic>>[
    {
      'id': 'p1',
      'full_name': 'Person One',
      'age': 7,
      'gender': 'female',
      'relationship': 'child',
      'photo_expired': false,
    },
  ];
  int photoVersion = 1;
  int status = 200;

  int count(String request) => requests.where((r) => r == request).length;

  static http.Response json(Object value) => http.Response(
    jsonEncode(value),
    200,
    headers: {'content-type': 'application/json'},
  );

  late final client = MockClient((request) async {
    final path = request.url.path.replaceFirst('/v1', '');
    final key = '${request.method} $path';
    requests.add(key);
    if (hold.contains(key)) {
      final completer = Completer<http.Response>();
      held[key] = completer;
      return completer.future;
    }
    if (status != 200) return http.Response('{}', status);
    if (failOnce.remove(key)) return http.Response('{}', 500);
    if (path == '/cases') return json([]);
    if (path == '/notifications') return json([]);
    if (path == '/individuals') return json(people);
    if (path.endsWith('/photo')) {
      return http.Response.bytes([photoVersion], 200);
    }
    if (path.startsWith('/individuals/') && request.method == 'PUT') {
      photoVersion++;
      return json(people.first);
    }
    if (path.startsWith('/individuals/') && request.method == 'DELETE') {
      return http.Response('', 204);
    }
    if (path == '/guardian/verification') {
      return json({
        'payload': 'radd:guardian-verification:v1:test:${requests.length}',
        'expires_at': DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 5))
            .toIso8601String(),
      });
    }
    return json({});
  });
}

void main() {
  late _Server server;
  late GuardianApi api;
  String? uid = 'guardian-a';

  setUp(() {
    server = _Server();
    uid = 'guardian-a';
    api = GuardianApi(
      token: () async => 'jwt',
      account: () => uid,
      baseUrl: 'http://test',
      client: server.client,
    );
    GuardianPushService.resetForTesting();
  });

  const input = IndividualInput(
    fullName: 'Person One',
    age: 7,
    gender: 'female',
    relationship: 'child',
  );

  test(
    'Concurrent identical reads share one request; later reads refetch',
    () async {
      await Future.wait([api.cases(), api.cases(), api.cases()]);
      expect(server.count('GET /cases'), 1);
      await api.cases();
      expect(server.count('GET /cases'), 2);
    },
  );

  test(
    'A read started after a mutation never reuses pre-mutation data',
    () async {
      server.hold.add('GET /notifications');
      final stale = api.notifications();
      await pumpEventQueue();
      server.hold.clear();
      await api.readAllNotifications();
      await api.notifications();
      expect(server.count('GET /notifications'), 2);
      server.held.values.single.complete(_Server.json([]));
      await stale;
    },
  );

  test(
    'A photo is downloaded once and served from memory afterwards',
    () async {
      final first = await api.photo('p1');
      final second = await api.photo('p1');
      expect(server.count('GET /individuals/p1/photo'), 1);
      expect(identical(first, second), isTrue);
    },
  );

  test('Replacing a photo invalidates the cached photograph', () async {
    expect(await api.photo('p1'), [1]);
    await api.saveIndividual(input, id: 'p1', photo: Uint8List.fromList([9]));
    expect(await api.photo('p1'), [2]);
    expect(server.count('GET /individuals/p1/photo'), 2);
  });

  test('Deleting an individual invalidates its photograph', () async {
    await api.photo('p1');
    await api.deleteIndividual('p1');
    await api.photo('p1');
    expect(server.count('GET /individuals/p1/photo'), 2);
  });

  test('An expired or removed registration evicts its photograph', () async {
    await api.photo('p1');
    server.people = [
      {...server.people.single, 'photo_expired': true},
    ];
    await api.individuals();
    await api.photo('p1');
    expect(server.count('GET /individuals/p1/photo'), 2);

    server.people = [];
    await api.individuals();
    await api.photo('p1');
    expect(server.count('GET /individuals/p1/photo'), 3);
  });

  test(
    'A late photo response cannot repopulate an invalidated cache',
    () async {
      server.hold.add('GET /individuals/p1/photo');
      final late = api.photo('p1');
      await pumpEventQueue();
      await api.deleteIndividual('p1');
      server.held.values.single.complete(http.Response.bytes([1], 200));
      await late;
      server.hold.clear();
      await api.photo('p1');
      expect(server.count('GET /individuals/p1/photo'), 2);
    },
  );

  test('A failed photo download is not cached, so retry works', () async {
    server.failOnce.add('GET /individuals/p1/photo');
    await expectLater(api.photo('p1'), throwsA(isA<AppFailure>()));
    expect(await api.photo('p1'), [1]);
    expect(server.count('GET /individuals/p1/photo'), 2);
  });

  test('Switching accounts never serves the previous account photos', () async {
    await api.photo('p1');
    uid = 'guardian-b';
    await api.photo('p1');
    expect(server.count('GET /individuals/p1/photo'), 2);
  });

  test('Logout clears the session cache', () async {
    await api.photo('p1');
    await GuardianPushService.handleLogout(api);
    await api.photo('p1');
    expect(server.count('GET /individuals/p1/photo'), 2);
  });

  test('Lost authorization clears the session cache', () async {
    await api.photo('p1');
    server.status = 401;
    await expectLater(api.cases(), throwsA(isA<AppFailure>()));
    server.status = 200;
    await api.photo('p1');
    expect(server.count('GET /individuals/p1/photo'), 2);
  });

  test('The photo cache is bounded', () async {
    for (var i = 0; i <= GuardianApi.photoCacheLimit; i++) {
      await api.photo('id-$i');
    }
    await api.photo('id-0');
    expect(server.count('GET /individuals/id-0/photo'), 2);
    await api.photo('id-${GuardianApi.photoCacheLimit}');
    expect(
      server.count('GET /individuals/id-${GuardianApi.photoCacheLimit}/photo'),
      1,
    );
  });

  test('Verification credentials are never shared or cached', () async {
    final codes = await Future.wait([
      api.accountVerification(),
      api.accountVerification(),
    ]);
    expect(server.count('POST /guardian/verification'), 2);
    expect(codes.first.payload, isNot(codes.last.payload));
  });
}
