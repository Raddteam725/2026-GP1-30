import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'guardian_repository.dart';

/// Maps a backend error `detail` string to the specific AppFailure code the
/// UI should render. Anything not listed here falls back to the generic
/// HTTP-status-based mapping in `_request`.
const _detailFailures = {
  'event_unavailable': 'eventUnavailable',
  'multiple_active_events': 'eventUnavailable',
  'active_case': 'activeCase',
  'case_closed': 'caseClosed',
  'report_already_submitted': 'reportAlreadySubmitted',
  'photo_expired': 'photoExpired',
};

class GuardianApi implements GuardianRepository {
  GuardianApi({required this.token, http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _base =
          baseUrl ??
          const String.fromEnvironment(
            'RADD_API_URL',
            defaultValue: kDebugMode ? 'http://10.0.2.2:8000' : '',
          );
  final Future<String?> Function() token;
  final http.Client _client;
  final String _base;
  Future<http.Response> _request(
    String method,
    String path, {
    Object? body,
  }) async {
    if (_base.isEmpty) throw const AppFailure('service');
    final uri = Uri.parse('$_base/v1$path');
    if (!kDebugMode && uri.scheme != 'https') throw const AppFailure('service');
    try {
      return await (() async {
        final jwt = await token();
        if (jwt == null) throw const AppFailure('unauthorized');
        final request = http.Request(method, uri)
          ..headers.addAll({
            'Authorization': 'Bearer $jwt',
            'Content-Type': 'application/json',
          });
        if (body != null) request.body = jsonEncode(body);
        final response = await http.Response.fromStream(
          await _client.send(request),
        );
        if (response.statusCode >= 400) {
          Object? decoded;
          try {
            decoded = jsonDecode(response.body);
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
    } on TimeoutException {
      throw const AppFailure('network');
    } on http.ClientException {
      throw const AppFailure('network');
    }
  }

  Map<String, dynamic> _json(http.Response r) =>
      jsonDecode(r.body) as Map<String, dynamic>;
  @override
  Future<String> accountRole() async =>
      _json(await _request('GET', '/session'))['role'] as String;
  @override
  Future<GuardianProfile> profile() async =>
      GuardianProfile.fromJson(_json(await _request('GET', '/guardian')));
  @override
  Future<GuardianProfile> createProfile(String name, String phone) async =>
      GuardianProfile.fromJson(
        _json(
          await _request(
            'PUT',
            '/guardian',
            body: {
              'full_name': name.trim(),
              'phone': phone.trim(),
              'age_confirmed': true,
              'privacy_accepted': true,
            },
          ),
        ),
      );
  @override
  Future<GuardianProfile> updateProfile(String name, String phone) async =>
      GuardianProfile.fromJson(
        _json(
          await _request(
            'PATCH',
            '/guardian',
            body: {'full_name': name.trim(), 'phone': phone.trim()},
          ),
        ),
      );
  @override
  Future<List<Individual>> individuals() async =>
      (jsonDecode((await _request('GET', '/individuals')).body) as List)
          .map((e) => Individual.fromJson(e as Map<String, dynamic>))
          .toList();
  String _path(String id) => '/individuals/${Uri.encodeComponent(id)}';
  @override
  Future<Individual> individual(String id) async =>
      Individual.fromJson(_json(await _request('GET', _path(id))));
  @override
  Future<Individual> saveIndividual(
    IndividualInput input, {
    String? id,
    Uint8List? photo,
  }) async => Individual.fromJson(
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
  @override
  Future<void> deleteIndividual(String id) async {
    await _request('DELETE', _path(id));
  }

  @override
  Future<Uint8List> photo(String id) async =>
      (await _request('GET', '${_path(id)}/photo')).bodyBytes;

  @override
  Future<List<MissingCase>> cases() async =>
      (jsonDecode((await _request('GET', '/cases')).body) as List)
          .map((e) => MissingCase.fromJson(e as Map<String, dynamic>))
          .toList();
  @override
  Future<MissingCase> missingCase(String id) async => MissingCase.fromJson(
    _json(await _request('GET', '/cases/${Uri.encodeComponent(id)}')),
  );
  @override
  Future<MissingCase> reportMissing(String individualId) async =>
      MissingCase.fromJson(
        _json(
          await _request(
            'POST',
            '/cases',
            body: {'individual_id': individualId},
          ),
        ),
      );
  @override
  Future<MissingCase> saveGuidedReport(
    String id,
    Map<String, dynamic> report,
  ) async => MissingCase.fromJson(
    _json(
      await _request(
        'PUT',
        '/cases/${Uri.encodeComponent(id)}/guided-report',
        body: report,
      ),
    ),
  );
  @override
  Future<List<GuardianNotification>> notifications() async =>
      (jsonDecode((await _request('GET', '/notifications')).body) as List)
          .map((e) => GuardianNotification.fromJson(e as Map<String, dynamic>))
          .toList();
  @override
  Future<void> readNotification(String id) async {
    await _request('PUT', '/notifications/${Uri.encodeComponent(id)}/read');
  }

  @override
  Future<GuardianVerification> accountVerification() async =>
      GuardianVerification.fromJson(
        _json(await _request('POST', '/guardian/verification')),
      );
  @override
  Future<MissingCase> cancelCase(String id) async => MissingCase.fromJson(
    _json(await _request('POST', '/cases/${Uri.encodeComponent(id)}/cancel')),
  );
  @override
  Future<MissingCase> resolveCase(String id) async => MissingCase.fromJson(
    _json(await _request('POST', '/cases/${Uri.encodeComponent(id)}/resolve')),
  );
  @override
  Future<void> registerFcmToken(String token, String locale) async {
    // The token itself is the whole point of this request; never logged
    // (this call goes through the same _request as everything else, which
    // logs nothing about request bodies).
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
