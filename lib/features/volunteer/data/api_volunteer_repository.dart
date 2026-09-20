import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/volunteer_models.dart';
import 'volunteer_repository.dart';

/// Unsupported found/AI/verification operations retain fail-closed behavior.
class ApiVolunteerRepository extends VolunteerRepository {
  ApiVolunteerRepository({
    required this.token,
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
  final http.Client _client;
  final String _base;
  VolunteerAccount? account;
  List<VolunteerCase> _cases = [];
  List<RegisteredPerson> _profiles = [];
  List<FoundReport> _reports = [];
  List<VolunteerAlert> _alerts = [];
  Coordinates? proximityLocation;
  @override
  bool get isPreview => false;
  @override
  List<RegisteredPerson> get profiles => List.unmodifiable(_profiles);
  @override
  List<FoundReport> get foundReports => List.unmodifiable(_reports);
  @override
  List<VolunteerAlert> alertsFor(String uid) => uid != account?.uid
      ? []
      : _alerts.map((alert) {
          final coordinates = caseById(alert.caseId)?.information?.coordinates;
          final nearby =
              proximityLocation != null &&
              coordinates != null &&
              proximityLocation!.distanceTo(coordinates) <= 500;
          return VolunteerAlert(
            id: alert.id,
            readAt: alert.readAt,
            caseId: alert.caseId,
            at: alert.at,
            kind: nearby && alert.kind == AlertKind.newCase
                ? AlertKind.priority
                : alert.kind,
            status: alert.status,
          );
        }).toList();
  bool _disposed = false, _joining = false;
  Future<void>? _pendingRefresh;
  String? error;
  @override
  bool get connected => account != null && error == null;
  @override
  List<VolunteerCase> get cases => List.unmodifiable(_cases);

  Future<http.Response> _request(
    String method,
    String path, {
    Object? body,
  }) async {
    if (_base.isEmpty) throw StateError('backend-unavailable');
    final uri = Uri.parse('$_base/v1/volunteer$path');
    if (!kDebugMode && uri.scheme != 'https') {
      throw StateError('backend-unavailable');
    }
    final jwt = await token();
    if (jwt == null) throw StateError('unauthorized');
    final request = http.Request(method, uri)
      ..headers['Authorization'] = 'Bearer $jwt';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final response = await _client
        .send(request)
        .then(http.Response.fromStream)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode >= 400) {
      throw StateError(switch (response.statusCode) {
        401 => 'unauthorized',
        403 => 'volunteer-required',
        _ => 'backend-unavailable',
      });
    }
    return response;
  }

  Future<VolunteerAccount> loadProfile() async {
    final data =
        jsonDecode((await _request('GET', '')).body) as Map<String, dynamic>;
    final name = data['full_name'] as String;
    final result = VolunteerAccount(
      uid: data['uid'] as String,
      name: LocalizedData(name, name),
      volunteerId: data['volunteer_id'] as String,
      active: data['active'] as bool,
      email: data['email'] as String?,
      phone: data['phone'] as String?,
    );
    if (!_disposed) account = result;
    return result;
  }

  Future<void> refresh() {
    if (_disposed || _joining) return Future.value();
    return _pendingRefresh ??= _refresh().whenComplete(
      () => _pendingRefresh = null,
    );
  }

  Future<void> _refresh() async {
    try {
      final user = await loadProfile();
      final next = <String, VolunteerCase>{};
      final raw = <String, Map<String, dynamic>>{};
      if (user.active) {
        for (final path in ['/cases/available', '/cases/mine']) {
          final rows = jsonDecode((await _request('GET', path)).body) as List;
          for (final row in rows) {
            final data = row as Map<String, dynamic>;
            raw[data['id'] as String] = data;
          }
        }
        // Authenticated bytes only; no public Storage URLs or private paths.
        await Future.wait(
          raw.values.map((data) async {
            Uint8List? photo;
            try {
              photo = (await _request(
                'GET',
                '/cases/${Uri.encodeComponent(data['id'] as String)}/photo',
              )).bodyBytes;
            } catch (_) {
              /* A missing photo never substitutes a fixture image. */
            }
            final item = _parse(data, user.uid, photo: photo);
            next[item.id] = item;
          }),
        );
      }
      final reports = user.active
          ? (jsonDecode((await _request('GET', '/found-reports')).body) as List)
                .map((row) => _found(row as Map<String, dynamic>))
                .toList()
          : <FoundReport>[];
      final alerts = user.active
          ? (jsonDecode((await _request('GET', '/notifications')).body) as List)
                .map(
                  (row) => VolunteerAlert(
                    id: row['id'] as String,
                    caseId: row['case_id'] as String,
                    kind: row['kind'] == 'status_update'
                        ? AlertKind.statusUpdate
                        : AlertKind.newCase,
                    status: _status(row['status'] as String?),
                    at: DateTime.parse(row['created_at'] as String),
                    readAt: row['read_at'] == null
                        ? null
                        : DateTime.parse(row['read_at'] as String),
                  ),
                )
                .toList()
          : <VolunteerAlert>[];
      if (!_disposed) {
        _reports = reports;
        _alerts = alerts..sort((a, b) => b.at.compareTo(a.at));
        if (!user.active) _profiles = [];
        _cases = next.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        error = null;
      }
    } catch (e) {
      if (!_disposed) {
        _cases = [];
        _reports = [];
        _alerts = [];
        _profiles = [];
        error = 'backend-unavailable';
      }
      rethrow;
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  VolunteerCase _parse(
    Map<String, dynamic> data,
    String uid, {
    Uint8List? photo,
  }) {
    LocalizedData? text(dynamic value) => value is String && value.isNotEmpty
        ? LocalizedData(value, value)
        : null;
    final report = data['guided_report'] as Map<String, dynamic>?;
    final status = const [
      'report_received',
      'search_in_progress',
      'match_confirmed',
      'awaiting_guardian_verification',
      'reunited',
    ].indexOf(data['status'] as String);
    if (status < 0) throw const FormatException('Unknown case status');
    return VolunteerCase(
      id: data['id'] as String,
      person: RegisteredPerson(
        photoBytes: photo,
        id: (data['profile_id'] ?? data['individual_id']) as String,
        name: text(data['individual_name'])!,
        age: data['age'] as int,
        gender: switch (data['gender']) {
          'male' => Gender.male,
          'female' => Gender.female,
          _ => null,
        },
        guardian: const GuardianContact(
          id: '',
          name: LocalizedData('', ''),
          relationship: LocalizedData('', ''),
        ),
      ),
      createdAt: DateTime.parse(data['created_at'] as String),
      updatedAt: DateTime.parse(data['updated_at'] as String),
      status: CaseStatus.values[status],
      joinedBy: data['joined'] == true ? {uid} : {},
      confirmedBy: data['confirmed_by_me'] == true ? uid : null,
      information: report == null
          ? null
          : CaseInformation(
              lastSeen: text(report['last_seen_description']),
              clothing: text(report['clothing']),
              distinctive: text(report['distinctive_description']),
              additional: text(report['additional_information']),
              coordinates:
                  report['same_location'] == true &&
                      report['latitude'] is num &&
                      report['longitude'] is num
                  ? Coordinates(
                      (report['latitude'] as num).toDouble(),
                      (report['longitude'] as num).toDouble(),
                    )
                  : null,
            ),
    );
  }

  @override
  Future<void> startSearch(VolunteerAccount account, VolunteerCase item) async {
    // Do not let an older in-flight list response undo a successful join locally.
    await _pendingRefresh;
    if (_disposed) throw StateError('backend-unavailable');
    _joining = true;
    try {
      final data = jsonDecode(
        (await _request(
          'POST',
          '/cases/${Uri.encodeComponent(item.id)}/start-search',
        )).body,
      ) as Map<String, dynamic>;
      final updated = _parse(data, this.account!.uid);
      // Update the object already displayed in Case Details immediately.
      item.status = updated.status;
      item.joinedBy
        ..clear()
        ..addAll(updated.joinedBy);
      item.updatedAt = updated.updatedAt;
      final index = _cases.indexWhere((value) => value.id == item.id);
      if (index >= 0) _cases[index] = item;
      if (!_disposed) notifyListeners();
    } finally {
      _joining = false;
    }
  }

  CaseStatus? _status(String? value) {
    if (value == null) return null;
    return CaseStatus.values[const [
      'report_received',
      'search_in_progress',
      'match_confirmed',
      'awaiting_guardian_verification',
      'reunited',
    ].indexOf(value)];
  }

  LocalizedData _text(dynamic value) =>
      LocalizedData(value as String? ?? '', value ?? '');
  RegisteredPerson _person(Map<String, dynamic> data, {Uint8List? photo}) {
    final guardian = data['guardian'] as Map<String, dynamic>?;
    final info = data['guided_report'] as Map<String, dynamic>?;
    LocalizedData? optional(dynamic v) =>
        v is String && v.isNotEmpty ? _text(v) : null;
    return RegisteredPerson(
      id: data['id'] as String,
      name: _text(data['full_name']),
      age: data['age'] as int,
      gender: data['gender'] == 'male'
          ? Gender.male
          : data['gender'] == 'female'
          ? Gender.female
          : null,
      photoBytes: photo,
      information: info == null
          ? null
          : CaseInformation(
              lastSeen: optional(info['last_seen_description']),
              clothing: optional(info['clothing']),
              distinctive: optional(info['distinctive_description']),
              additional: optional(info['additional_information']),
            ),
      guardian: GuardianContact(
        id: '',
        name: _text(guardian?['full_name']),
        relationship: _text(data['relationship']),
        phone: guardian?['phone'] as String?,
      ),
    );
  }

  FoundReport _found(Map<String, dynamic> data, {Uint8List? photo}) {
    final result = FoundReport(
      id: data['id'] as String,
      volunteerUid: account!.uid,
      photo: '',
      photoBytes: photo,
      caseId: data['case_id'] as String?,
      createdAt: DateTime.parse(data['created_at'] as String),
    );
    result.status = _status(data['status'] as String?);
    if (data['person'] != null) {
      result.matchedPerson = _person(data['person'] as Map<String, dynamic>);
    }
    final proof = data['verification'] as Map<String, dynamic>?;
    if (proof != null) {
      result.verification = VerificationReceipt(
        caseId: data['case_id'] as String,
        guardianId: proof['guardian_id'] as String,
        volunteerUid: proof['volunteer_uid'] as String,
        method: proof['method'] == 'case_identifier'
            ? VerificationMethod.caseIdentifier
            : VerificationMethod.qr,
        at: DateTime.parse(proof['verified_at'] as String),
      );
    }
    result.handedOverBy = data['handed_over_by'] as String?;
    if (data['handed_over_at'] != null) {
      result.handedOverAt = DateTime.parse(data['handed_over_at'] as String);
    }
    return result;
  }

  void _updateReport(FoundReport target, Map<String, dynamic> data) {
    final value = _found(data, photo: target.photoBytes);
    target.caseId = value.caseId;
    target.status = value.status;
    if (data['person'] != null) {
      Uint8List? photo = target.matchedPerson?.photoBytes;
      for (final person in _profiles) {
        if (person.id == value.matchedPerson!.id) photo ??= person.photoBytes;
      }
      target.matchedPerson = _person(
        data['person'] as Map<String, dynamic>,
        photo: photo,
      );
    }
    target.verification = value.verification;
    target.handedOverBy = value.handedOverBy;
    target.handedOverAt = value.handedOverAt;
  }

  Future<FoundReport> loadReport(String id) async {
    final data = jsonDecode(
      (await _request('GET', '/found-reports/${Uri.encodeComponent(id)}')).body,
    ) as Map<String, dynamic>;
    final photo = (await _request(
      'GET',
      '/found-reports/${Uri.encodeComponent(id)}/photo',
    )).bodyBytes;
    final result = _found(data, photo: photo);
    if (data['person'] != null) {
      Uint8List? registered;
      try {
        registered = (await _request(
          'GET',
          '/found-reports/${Uri.encodeComponent(id)}/registered-photo',
        )).bodyBytes;
      } catch (_) {
        /* Registration may have been removed after reunification. */
      }
      result.matchedPerson = _person(
        data['person'] as Map<String, dynamic>,
        photo: registered,
      );
    }
    return result;
  }

  Future<void> loadProfiles() async {
    final rows = jsonDecode((await _request('GET', '/profiles')).body) as List;
    final result = <RegisteredPerson>[];
    for (final row in rows) {
      Uint8List? photo;
      try {
        photo = (await _request(
          'GET',
          '/profiles/${row['id']}/photo',
        )).bodyBytes;
      } catch (_) {
        /* No sample fallback. */
      }
      result.add(_person(row as Map<String, dynamic>, photo: photo));
    }
    if (!_disposed) {
      _profiles = result;
      notifyListeners();
    }
  }

  Future<void> markRead(VolunteerAlert alert) async {
    if (alert.id != null) {
      await _request(
        'PUT',
        '/notifications/${Uri.encodeComponent(alert.id!)}/read',
      );
    }
    await refresh();
  }

  Future<VolunteerCase> loadCase(String id) async {
    final row = jsonDecode(
      (await _request('GET', '/cases/${Uri.encodeComponent(id)}')).body,
    ) as Map<String, dynamic>;
    Uint8List? photo;
    try {
      photo = (await _request(
        'GET',
        '/cases/${Uri.encodeComponent(id)}/photo',
      )).bodyBytes;
    } catch (_) {}
    return _parse(row, account!.uid, photo: photo);
  }

  @override
  Future<FoundReport> submitFound(
    VolunteerAccount account, {
    Uint8List? photo,
    String? requestId,
  }) async {
    if (photo == null || requestId == null) {
      throw StateError('capture-required');
    }
    final data = jsonDecode(
      (await _request(
        'POST',
        '/found-reports',
        body: {'photo_base64': base64Encode(photo), 'request_id': requestId},
      )).body,
    ) as Map<String, dynamic>;
    final result = _found(data, photo: photo);
    _reports = [result, ..._reports.where((r) => r.id != result.id)];
    if (!_disposed) notifyListeners();
    return result;
  }

  @override
  Future<List<MatchCandidate>> findMatches(FoundReport report) async {
    final data = jsonDecode(
      (await _request('GET', '/found-reports/${report.id}/candidates')).body,
    ) as Map<String, dynamic>;
    if (data['state'] == 'unavailable') throw StateError('ai-unavailable');
    throw StateError('unsupported-model-contract');
  }

  Future<void> _reportAction(
    FoundReport report,
    String action, {
    Object? body,
  }) async {
    await _pendingRefresh;
    _joining = true;
    try {
      final data = jsonDecode(
        (await _request(
          'POST',
          '/found-reports/${report.id}/$action',
          body: body,
        )).body,
      ) as Map<String, dynamic>;
      _updateReport(report, data);
    } finally {
      _joining = false;
    }

    await refresh();
  }

  @override
  Future<void> confirmMatch(
    VolunteerAccount account,
    FoundReport report,
    RegisteredPerson person,
  ) async {
    await _reportAction(
      report,
      'confirm-match',
      body: {'profile_id': person.id},
    );
  }

  @override
  Future<void> beginVerification(
    VolunteerAccount account,
    FoundReport report,
  ) => _reportAction(report, 'begin-verification');
  @override
  Future<bool> verify(
    VolunteerAccount account,
    FoundReport report,
    VerificationMethod method,
    String value, {
    bool authenticatedAccountShown = false,
  }) async {
    if (method == VerificationMethod.caseIdentifier &&
        !authenticatedAccountShown) {
      throw StateError('guardian-account-required');
    }
    final action = method == VerificationMethod.qr
        ? 'verify'
        : 'verify-identifier';
    final data = jsonDecode(
      (await _request(
        'POST',
        '/found-reports/${report.id}/$action',
        body: method == VerificationMethod.qr
            ? {'payload': value}
            : {'case_id': value},
      )).body,
    ) as Map<String, dynamic>;
    _updateReport(report, data['report'] as Map<String, dynamic>);
    if (!_disposed) notifyListeners();
    return data['verified'] == true;
  }

  @override
  Future<void> handover(VolunteerAccount account, FoundReport report) =>
      _reportAction(report, 'handover');
  @override
  void dispose() {
    _disposed = true;
    _client.close();
    _cases = [];
    super.dispose();
  }
}
