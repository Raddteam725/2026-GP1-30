import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../shared/saudi_phone.dart';
import 'guardian_repository.dart';

const _detailFailures = {
  'email_verification_required': 'emailVerification',
  'event_unavailable': 'eventUnavailable',
  'multiple_active_events': 'eventUnavailable',
  'active_case': 'activeCase',
  'case_closed': 'caseClosed',
  'report_already_submitted': 'reportAlreadySubmitted',
  'photo_expired': 'photoExpired',
  'registration_unavailable': 'photoExpired',
  'registration_configuration_required': 'eventUnavailable',
  'invalid_registration_period': 'retentionInvalid',
  'retention_deadline_passed': 'retentionPassed',
  'account_inactive': 'accountInactive',
};

class GuardianApi implements GuardianRepository {
  GuardianApi({
    required this.token,
    this.account,
    http.Client? client,
    String? baseUrl,
  }) : _client = client ?? http.Client(),
      _base =
          baseUrl ??
          const String.fromEnvironment(
            'RADD_API_URL',
            defaultValue: kDebugMode ? 'http://10.0.2.2:8000' : '',
          );
  final Future<String?> Function() token;
  final String? Function()? account;
  final http.Client _client;
  final String _base;
  int _sequence = 0;

  static const photoCacheLimit = 48;
  final _photos = <String, Future<Uint8List>>{};
  final _reads = <String, Future<dynamic>>{};
  String? _cacheOwner;

  void clearSessionCache() {
    _photos.clear();
    _reads.clear();
  }

  void _bindAccount() {
    final current = account?.call();
    if (current == _cacheOwner) return;
    _cacheOwner = current;
    clearSessionCache();
  }

  Future<T> _shared<T>(String key, Future<T> Function() load) {
    _bindAccount();
    final pending = _reads[key];
    if (pending != null) return pending as Future<T>;
    final future = load();
    _reads[key] = future;
    unawaited(
      future.then<void>((_) {}, onError: (Object _) {}).whenComplete(() {
        if (identical(_reads[key], future)) _reads.remove(key);
      }),
    );
    return future;
  }

  Future<T> _mutation<T>(Future<T> Function() action) async {
    _bindAccount();
    _reads.clear();
    try {
      return await action();
    } finally {
      _reads.clear();
    }
  }

  void _retainPhotos(List<Individual> people) {
    final usable = {
      for (final person in people)
        if (!person.photoExpired) person.id,
    };
    _photos.removeWhere((id, _) => !usable.contains(id));
  }
  Future<http.Response> _request(
    String method,
    String path, {
    Object? body,
  }) async {
    if (_base.isEmpty) throw const AppFailure('service');
    final requestId = '${DateTime.now().millisecondsSinceEpoch}-${++_sequence}';
    if (kDebugMode && method == 'POST') {
      debugPrint(
        'Radd Guardian $requestId T0 $method ${path.replaceAll(RegExp(r"/cases/[^/]+"), "/cases/{id}")} ${DateTime.now().toUtc().toIso8601String()}',
      );
    }
    final uri = Uri.parse('$_base/v1$path');
    if (kDebugMode && _sequence == 1) {
      debugPrint(
        'Radd Guardian backend ${uri.scheme}://${uri.host}:${uri.port}',
      );
    }
    if (!kDebugMode && uri.scheme != 'https') throw const AppFailure('service');
    var stage = 'token';
    int? status;
    try {
      return await (() async {
        final jwt = await token();
        if (jwt == null) throw const AppFailure('unauthorized');
        stage = 'http';
        final request = http.Request(method, uri)
          ..headers.addAll({
            'Authorization': 'Bearer $jwt',
            'Content-Type': 'application/json',
            if (kDebugMode) 'X-Radd-Request-ID': requestId,
          });
        if (body != null) request.body = jsonEncode(body);
        final response = await http.Response.fromStream(
          await _client.send(request),
        );
        status = response.statusCode;
        if (response.statusCode >= 400) {
          if (response.statusCode == 401 || response.statusCode == 403) {
            clearSessionCache();
          }
          Object? decoded;
          try {
            decoded = jsonDecode(_text(response));
          } on FormatException {
            // Fall through to the generic status-code mapping below.
          }
          final detail = decoded is Map ? decoded['detail'] : null;
          final known = _detailFailures[detail];
          if (known != null) throw AppFailure(known);
          throw AppFailure(switch (response.statusCode) {
            401 => 'unauthorized',
            403 => 'role',
            404 => 'notFound',
            409 => 'conflict',
            422 => 'validation',
            _ => 'service',
          });
        }
        return response;
      })().timeout(const Duration(seconds: 30));
    } catch (error) {
      if (kDebugMode && path == '/session') {
        debugPrint(
          'Radd session GET /v1/session failed: stage=$stage '
          'status=${status ?? "none"} type=${error.runtimeType}',
        );
      }
      if (error is TimeoutException || error is http.ClientException) {
        throw const AppFailure('network');
      }
      rethrow;
    }
  }

  static String _text(http.Response r) => utf8.decode(r.bodyBytes);
  Map<String, dynamic> _json(http.Response r) =>
      jsonDecode(_text(r)) as Map<String, dynamic>;
  List<dynamic> _list(http.Response r) => jsonDecode(_text(r)) as List;
  @override
  Future<String> accountRole() async =>
      _json(await _request('GET', '/session'))['role'] as String;
  @override
  Future<GuardianProfile> profile() => _shared(
    'profile',
    () async =>
        GuardianProfile.fromJson(_json(await _request('GET', '/guardian'))),
  );
  @override
  Future<GuardianProfile> createProfile(String name, String phone) =>
      _mutation(
        () async => GuardianProfile.fromJson(
          _json(
            await _request(
              'PUT',
              '/guardian',
              body: {
                'full_name': name.trim(),
                'phone': normalizeSaudiPhone(phone) ?? phone.trim(),
                'age_confirmed': true,
                'privacy_accepted': true,
              },
            ),
          ),
        ),
      );
  @override
  Future<GuardianProfile> updateProfile(String name, String phone) =>
      _mutation(
        () async => GuardianProfile.fromJson(
          _json(
            await _request(
              'PATCH',
              '/guardian',
              body: {
                'full_name': name.trim(),
                'phone': normalizeSaudiPhone(phone) ?? phone.trim(),
              },
            ),
          ),
        ),
      );
  @override
  Future<ActiveEvent> activeEvent() => _shared(
    'event',
    () async => ActiveEvent.fromJson(_json(await _request('GET', '/event'))),
  );
  @override
  Future<List<RegistrationPeriod>> registrationPeriods() async {
    final data = jsonDecode(
      (await _request('GET', '/registration-periods')).body,
    ) as Map<String, dynamic>;
    return (data['options'] as List)
        .map(
          (p) =>
              RegistrationPeriod(p['id'] as String, p['duration_hours'] as int),
        )
        .toList();
  }

  @override
  Future<List<Individual>> individuals() => _shared('individuals', () async {
    final people = _list(await _request('GET', '/individuals'))
        .map((e) => Individual.fromJson(e as Map<String, dynamic>))
        .toList();
    _retainPhotos(people);
    return people;
  });
  String _path(String id) => '/individuals/${Uri.encodeComponent(id)}';
  @override
  Future<Individual> individual(String id) async {
    final person = Individual.fromJson(_json(await _request('GET', _path(id))));
    if (person.photoExpired) _photos.remove(id);
    return person;
  }

  @override
  Future<Individual> saveIndividual(
    IndividualInput input, {
    String? id,
    Uint8List? photo,
  }) => _mutation(() async {
    try {
      return Individual.fromJson(
        _json(
          await _request(
            id == null ? 'POST' : 'PUT',
            id == null ? '/individuals' : _path(id),
            body: {
              ...input.toJson(),
              if (photo != null) 'photo_base64': base64Encode(photo),
            },
          ),
        ),
      );
    } finally {
      if (id != null) _photos.remove(id);
    }
  });
  @override
  Future<void> deleteIndividual(String id) => _mutation(() async {
    try {
      await _request('DELETE', _path(id));
    } finally {
      _photos.remove(id);
    }
  });

  @override
  Future<RetentionOptions> retentionOptions(String id) async =>
      RetentionOptions.fromJson(
        _json(await _request('GET', '${_path(id)}/retention-options')),
      );

  @override
  Future<Uint8List> photo(String id) {
    _bindAccount();
    final cached = _photos.remove(id);
    if (cached != null) {
      _photos[id] = cached;
      return cached;
    }
    final future = _request(
      'GET',
      '${_path(id)}/photo',
    ).then((response) => response.bodyBytes);
    _photos[id] = future;
    while (_photos.length > photoCacheLimit) {
      _photos.remove(_photos.keys.first);
    }
    unawaited(
      future.then<void>(
        (_) {},
        onError: (Object _) {
          if (identical(_photos[id], future)) _photos.remove(id);
        },
      ),
    );
    return future;
  }

  @override
  Future<List<MissingCase>> cases() => _shared(
    'cases',
    () async => _list(await _request('GET', '/cases'))
        .map((e) => MissingCase.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
  @override
  Future<MissingCase> missingCase(String id) async => MissingCase.fromJson(
    _json(await _request('GET', '/cases/${Uri.encodeComponent(id)}')),
  );
  @override
  Future<MissingCase> reportMissing(String individualId) => _mutation(
    () async => MissingCase.fromJson(
      _json(
        await _request(
          'POST',
          '/cases',
          body: {'individual_id': individualId},
        ),
      ),
    ),
  );
  @override
  Future<MissingCase> saveGuidedReport(
    String id,
    Map<String, dynamic> report,
  ) => _mutation(
    () async => MissingCase.fromJson(
      _json(
        await _request(
          'PUT',
          '/cases/${Uri.encodeComponent(id)}/guided-report',
          body: report,
        ),
      ),
    ),
  );
  @override
  Future<List<GuardianNotification>> notifications() => _shared(
    'notifications',
    () async => _list(await _request('GET', '/notifications'))
        .map((e) => GuardianNotification.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
  @override
  Future<void> readNotification(String id) => _mutation(() async {
    await _request('PUT', '/notifications/${Uri.encodeComponent(id)}/read');
  });

  @override
  Future<void> readAllNotifications() => _mutation(() async {
    await _request('PUT', '/notifications/read-all');
  });

  @override
  Future<List<GuardianFoundReport>> activeFoundReports() => _shared(
    'found-reports',
    () async => _list(await _request('GET', '/guardian/found-reports'))
        .map(
          (value) =>
              GuardianFoundReport.fromJson(value as Map<String, dynamic>),
        )
        .toList(),
  );

  @override
  Future<GuardianVerification> accountVerification() async =>
      GuardianVerification.fromJson(
        _json(await _request('POST', '/guardian/verification')),
      );
  @override
  Future<void> registerFcmToken(String token, String locale) async {
    await _request(
      'PUT',
      '/guardian/fcm-registrations',
      body: {'token': token, 'locale': locale},
    );
  }

  @override
  Future<void> unregisterFcmToken(String token) async {
    await _request(
      'POST',
      '/guardian/fcm-registrations/unregister',
      body: {'token': token},
    );
  }
}
