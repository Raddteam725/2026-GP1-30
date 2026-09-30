import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/volunteer_models.dart';
import '../domain/volunteer_notification_event.dart';
import 'volunteer_repository.dart';

/// Backend workflow refusals (HTTP 409/422 `detail`) that the Volunteer
/// screens can explain, mapped to the StateError codes they throw. Anything
/// else stays a generic failure.
const knownWorkflowFailures = {
  'already_matched': 'already-matched',
  'resume_existing_report': 'resume-existing-report',
  'profile_unavailable': 'profile-unavailable',
  'identification_ended': 'identification-ended',
  'identification_unavailable': 'identification-unavailable',
  'match_already_confirmed': 'match-already-confirmed',
  'match_required': 'match-required',
  'guardian_verification_required': 'guardian-verification-required',
  'invalid_transition': 'invalid-transition',
  'case_not_joinable': 'case-not-joinable',
  'capture_required': 'capture-required',
};

/// Unsupported found/AI/verification operations retain fail-closed behavior.
class ApiVolunteerRepository extends VolunteerRepository {
  ApiVolunteerRepository({
    required this.token,
    this.onAccessLost,
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
  double? _proximityRadiusMeters;
  @override
  double get proximityRadiusMeters =>
      _proximityRadiusMeters ?? super.proximityRadiusMeters;
  final Future<void> Function(String reason)? onAccessLost;
  bool _accessLost = false;
  Future<void> Function()? closeSession;
  void clearEventData() {
    ++_dataVersion;
    for (final report in _reports) {
      report.photoBytes = null;
    }
    _cases = [];
    _profiles = [];
    _reports = [];
    _alerts = [];
    caseStates.clear();
    proximityLocation = null;
    hasLoadedCases = false;
    hasLoadedNotifications = false;
  }

  void clearProtectedData() {
    _accessLost = true;
    ++_dataVersion;
    for (final report in _reports) {
      report.photoBytes = null;
    }
    hasLoadedCases = false;
    hasLoadedNotifications = false;
    _cases = [];
    _profiles = [];
    _reports = [];
    _alerts = [];
    caseStates.clear();
    account = null;
  }

  final http.Client _client;
  final String _base;
  VolunteerAccount? account;
  bool consentCurrent = false;
  String? requiredTermsVersion, requiredPrivacyVersion;

  Future<void> acceptConsent(String terms, String privacy) async {
    await _request(
      'POST',
      '/consent',
      body: {
        'accepted': true,
        'terms_version': terms,
        'privacy_version': privacy,
      },
    );
    await loadProfile();
  }

  List<VolunteerCase> _cases = [];
  List<RegisteredPerson> _profiles = [];
  List<FoundReport> _reports = [];
  List<VolunteerAlert> _alerts = [];
  final Map<String, String> caseStates = {};
  Coordinates? proximityLocation;
  @override
  bool get isPreview => false;
  @override
  List<RegisteredPerson> get profiles => List.unmodifiable(_profiles);
  @override
  List<FoundReport> get foundReports => List.unmodifiable(_reports);
  @override
  List<VolunteerAlert> alertsFor(String uid) =>
      uid == account?.uid ? List.unmodifiable(_alerts) : [];

  Future<void> registerDevice(
    String token,
    String locale,
    Coordinates? location,
  ) async {
    await _request(
      'PUT',
      '/fcm-registrations',
      body: {
        'token': token,
        'locale': locale,
        'latitude': location?.latitude,
        'longitude': location?.longitude,
      },
    );
  }

  Future<void> unregisterDevice(String token) async {
    await _request(
      'POST',
      '/fcm-registrations/unregister',
      body: {'token': token},
    );
  }

  bool _disposed = false, _joining = false;
  Future<void>? _pendingRefresh;
  Future<void>? _eventRefresh;
  int _dataVersion = 0, _requestSequence = 0;
  String? error;
  bool hasLoadedCases = false, hasLoadedNotifications = false;
  @override
  bool get connected => account != null && error == null;
  @override
  List<VolunteerCase> get cases => List.unmodifiable(_cases);

  Future<http.Response> _request(
    String method,
    String path, {
    Object? body,
  }) async {
    if (_accessLost && path != '/fcm-registrations/unregister') {
      throw StateError('unauthorized');
    }
    if (_base.isEmpty) throw StateError('backend-unavailable');
    final eventRequest =
        path.isNotEmpty &&
        path != '/consent' &&
        path != '/fcm-registrations/unregister';
    final requestEventId = account?.eventId;
    if (eventRequest && (!consentCurrent || account?.eventAuthorized != true)) {
      throw StateError('event-access-required');
    }
    final uri = Uri.parse('$_base/v1/volunteer$path');
    if (kDebugMode && _requestSequence == 0) {
      debugPrint(
        'Radd Volunteer backend ${uri.scheme}://${uri.host}:${uri.port}',
      );
    }
    if (!kDebugMode && uri.scheme != 'https') {
      throw StateError('backend-unavailable');
    }
    final timer = Stopwatch()..start();
    if (kDebugMode && method != 'GET') {
      debugPrint(
        'Radd Volunteer action T0 ${DateTime.now().toUtc().toIso8601String()}',
      );
    }
    final jwt = await token().timeout(const Duration(seconds: 30));
    final tokenMs = timer.elapsedMilliseconds;
    if (jwt == null) {
      clearProtectedData();
      if (onAccessLost != null) await onAccessLost!('unauthorized');
      throw StateError('unauthorized');
    }
    final request = http.Request(method, uri)
      ..headers['Authorization'] = 'Bearer $jwt';
    final requestId =
        '${DateTime.now().millisecondsSinceEpoch}-${++_requestSequence}';
    if (kDebugMode) request.headers['X-Radd-Request-ID'] = requestId;
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    late http.Response response;
    // Route templates only: no UID, JWT, FCM token, report body or contact data.
    final route = path.replaceAllMapped(
      RegExp(
        r'/(cases|found-reports|profiles|notifications)/(?!available(?:/|$)|mine(?:/|$)|manual(?:/|$))[^/]+',
      ),
      (match) => '/${match[1]}/{id}',
    );
    try {
      if (kDebugMode) debugPrint('Radd request $requestId sent');
      response = await _client
          .send(request)
          .then((stream) {
            if (kDebugMode) {
              debugPrint(
                'Radd request $requestId headers ${timer.elapsedMilliseconds}ms',
              );
            }
            return http.Response.fromStream(stream);
          })
          .timeout(const Duration(seconds: 30));
      if (kDebugMode) {
        debugPrint(
          'Radd request $requestId Volunteer $method $route HTTP ${response.statusCode}: token=${tokenMs}ms total=${timer.elapsedMilliseconds}ms',
        );
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'Radd request $requestId Volunteer $method $route ${error.runtimeType}: token=${tokenMs}ms total=${timer.elapsedMilliseconds}ms',
        );
      }
      rethrow;
    }
    if (kDebugMode &&
        path == '/found-reports/manual' &&
        response.statusCode == 405) {
      debugPrint(
        'Radd manual confirmation: server does not support POST /found-reports/manual; check running backend version.',
      );
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      String? detail;
      try {
        detail = (jsonDecode(response.body) as Map)['detail'] as String?;
      } catch (_) {}
      if (detail == 'volunteer_consent_required') {
        consentCurrent = false;
        clearEventData();
        notifyListeners();
        await loadProfile();
      }
      if (detail == 'event_access_required') {
        clearEventData();
        final old = account;
        if (old != null) {
          account = VolunteerAccount(
            uid: old.uid,
            name: old.name,
            volunteerId: old.volunteerId,
            active: old.active,
            email: old.email,
            phone: old.phone,
            eventId: old.eventId,
          );
        }
        notifyListeners();
      }
      if (response.statusCode == 401 ||
          detail == 'volunteer_inactive' ||
          detail == 'volunteer_required') {
        clearProtectedData();
        if (onAccessLost != null) await onAccessLost!(detail ?? 'unauthorized');
      }
    }
    if (_accessLost && path != '/fcm-registrations/unregister') {
      throw StateError('unauthorized');
    }
    if (response.statusCode == 503 &&
        response.body.contains('photo_deletion_pending')) {
      throw StateError('photo-deletion-pending');
    }
    if (response.statusCode >= 400) {
      // A known workflow refusal keeps its meaning so the screen can tell
      // the Volunteer what actually happened (never the backend text itself).
      String? detail;
      if (response.statusCode == 409 || response.statusCode == 422) {
        try {
          detail = (jsonDecode(response.body) as Map)['detail'] as String?;
        } catch (_) {}
      }
      throw StateError(
        knownWorkflowFailures[detail] ??
            switch (response.statusCode) {
              401 => 'unauthorized',
              403 => 'volunteer-required',
              404 => 'not-found',
              _ => 'backend-unavailable',
            },
      );
    }
    if (eventRequest &&
        (account?.eventAuthorized != true ||
            account?.eventId != requestEventId)) {
      throw StateError('event-access-required');
    }
    return response;
  }

  Future<VolunteerAccount> loadProfile() async {
    final data =
        jsonDecode((await _request('GET', '')).body) as Map<String, dynamic>;
    consentCurrent = data['consent_current'] == true;
    requiredTermsVersion = data['required_terms_version'] as String?;
    requiredPrivacyVersion = data['required_privacy_version'] as String?;
    if (!consentCurrent) clearEventData();
    final name = data['full_name'] as String;
    final radius = data['proximity_radius_meters'];
    if (radius is num && radius.isFinite && radius > 0) {
      _proximityRadiusMeters = radius.toDouble();
    }
    final result = VolunteerAccount(
      uid: data['uid'] as String,
      name: LocalizedData(name, name),
      volunteerId: data['volunteer_id'] as String,
      active: data['active'] as bool,
      email: data['email'] as String?,
      phone: data['phone'] as String?,
      assigned: data['assigned'] == true,
      eventId: data['event_id'] as String?,
    );
    if (!result.active) {
      clearProtectedData();
      if (onAccessLost != null) await onAccessLost!('volunteer_inactive');
      throw StateError('volunteer_inactive');
    }
    if (!_disposed && !_accessLost) {
      if (account != null &&
          (account!.eventId != result.eventId ||
              account!.assigned != result.assigned)) {
        clearEventData();
      }
      account = result;
      notifyListeners();
    }
    return result;
  }

  Future<void> refresh() {
    if (_disposed || _joining) return Future.value();
    if (_eventRefresh != null) return _eventRefresh!;
    return _pendingRefresh ??= _refresh().whenComplete(
      () => _pendingRefresh = null,
    );
  }

  // Events do not queue behind profile/report/photo refreshes. Advancing the
  // generation prevents an older full refresh from overwriting this response.
  Future<void> refreshEvent({String? caseId}) {
    if (_disposed || _accessLost) return Future.value();
    ++_dataVersion;
    final operation = _refresh(eventOnly: true, caseId: caseId);
    _eventRefresh = operation;
    return operation.whenComplete(() {
      if (identical(_eventRefresh, operation)) _eventRefresh = null;
    });
  }

  Future<void> _refresh({bool eventOnly = false, String? caseId}) async {
    var version = _dataVersion;
    bool current() => !_disposed && !_accessLost && version == _dataVersion;
    Object? failure;
    Future<void> attempt(Future<void> Function() action) async {
      try {
        await action();
      } catch (e) {
        failure ??= e;
      }
    }

    try {
      final user = eventOnly ? account! : await loadProfile();
      if (!eventOnly) version = _dataVersion;
      if (!consentCurrent || !user.eventAuthorized) return;
      if (!current()) return;
      // Independent resources publish independently. Photos and FCM registration
      // must never hold case lists or navigation behind their network round trips.
      await Future.wait([
        if (caseId != null)
          attempt(() async {
            late http.Response response;
            try {
              response = await _request(
                'GET',
                '/cases/${Uri.encodeComponent(caseId)}/state',
              );
            } on StateError catch (e) {
              // Expired history or an event outside the current authorization
              // scope cannot reveal case state. Lists/history still reconcile.
              if (e.message == 'not-found') return;
              rethrow;
            }
            final state = jsonDecode(response.body) as Map<String, dynamic>;
            if (!current()) return;
            caseStates[caseId] = state['status'] as String;
            notifyListeners();
          }),
        attempt(() async {
          final responses = await Future.wait([
            _request('GET', '/cases/available'),
            _request('GET', '/cases/mine'),
          ]);
          final next = <String, VolunteerCase>{};
          final withoutPhoto = <String>{};
          for (final response in responses) {
            for (final row in jsonDecode(response.body) as List) {
              final item = _parse(row as Map<String, dynamic>, user.uid);
              next[item.id] = item;
              if (row['photo_available'] == false) withoutPhoto.add(item.id);
            }
          }
          if (!current()) return;
          hasLoadedCases = true;
          _cases = next.values.toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          notifyListeners();
          unawaited(_loadCasePhotos(next, version, withoutPhoto: withoutPhoto));
        }),
        if (!eventOnly)
          attempt(() async {
            final response = await _request('GET', '/found-reports');
            final reports = (jsonDecode(response.body) as List)
                .map((row) => _found(row as Map<String, dynamic>))
                .toList();
            if (!current()) return;
            _reports = reports;
            notifyListeners();
          }),
        attempt(() async {
          final response = await _request('GET', '/notifications');
          final seen = <String>{};
          final alerts = (jsonDecode(response.body) as List)
              .where(
                (row) =>
                    VolunteerNotificationEvent.parseKind(
                      row['kind'],
                      row['status'],
                    ) !=
                    null,
              )
              .where(
                (row) => seen.add(
                  '${row['case_id']}|${VolunteerNotificationEvent.parseKind(row['kind'], row['status'])!.name}',
                ),
              )
              .map(
                (row) => VolunteerAlert(
                  id: row['id'] as String,
                  caseId: row['case_id'] as String,
                  kind: VolunteerNotificationEvent.parseKind(
                    row['kind'],
                    row['status'],
                  )!,
                  status: _status(row['status'] as String?),
                  at: DateTime.parse(row['created_at'] as String),
                  readAt: row['read_at'] == null
                      ? null
                      : DateTime.parse(row['read_at'] as String),
                ),
              )
              .toList();
          if (!current()) return;
          hasLoadedNotifications = true;
          _alerts = alerts..sort((a, b) => b.at.compareTo(a.at));
          notifyListeners();
        }),
      ]);
      if (failure != null) throw failure!;
      if (current()) error = null;
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('Radd refresh failed (${e.runtimeType})\n$stack');
      }
      if (current()) error = 'backend-unavailable';
      // Preserve last successful, current-session data on transient failure.
      // Authentication loss still clears every protected resource in _request.
      rethrow;
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _loadCasePhotos(
    Map<String, VolunteerCase> cases,
    int version, {
    Set<String> withoutPhoto = const {},
  }) async {
    await Future.wait(
      cases.values.where((item) => !withoutPhoto.contains(item.id)).map((
        item,
      ) async {
        try {
          final response = await _request(
            'GET',
            '/cases/${Uri.encodeComponent(item.id)}/photo',
          );
          if (_disposed ||
              _accessLost ||
              version != _dataVersion ||
              !identical(caseById(item.id), item)) {
            return;
          }
          final person = item.person;
          item.person = RegisteredPerson(
            id: person.id,
            name: person.name,
            age: person.age,
            gender: person.gender,
            guardian: person.guardian,
            information: person.information,
            photoBytes: response.bodyBytes,
          );
          notifyListeners();
        } catch (_) {
          // Missing/expired photos never block lists or substitute fixture images.
        }
      }),
    );
  }

  void _refreshAfterAction() {
    unawaited(() async {
      try {
        await _pendingRefresh;
      } catch (_) {}
      if (!_disposed && !_accessLost) {
        try {
          await refresh();
        } catch (_) {}
      }
    }());
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
    ++_dataVersion;
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
      _refreshAfterAction();
    }
  }

  CaseStatus? _status(String? value) {
    if (value == null) return null;
    final index = const [
      'report_received',
      'search_in_progress',
      'match_confirmed',
      'awaiting_guardian_verification',
      'reunited',
    ].indexOf(value);
    return index < 0 ? null : CaseStatus.values[index];
  }

  LocalizedData _text(dynamic value) =>
      LocalizedData(value as String? ?? '', value ?? '');
  @override
  List<RegisteredPerson> get reviewableProfiles => profiles;

  RegisteredPerson _person(Map<String, dynamic> data, {Uint8List? photo}) {
    final guardian = data['guardian'] as Map<String, dynamic>?;
    final info = data['guided_report'] as Map<String, dynamic>?;
    LocalizedData? optional(dynamic v) =>
        v is String && v.isNotEmpty ? _text(v) : null;
    return RegisteredPerson(
      id: data['id'] as String,
      name: _text(data['full_name']),
      confirmationAvailable: data['confirmation_available'] == true,
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
              coordinates:
                  info['same_location'] == true &&
                      info['latitude'] is num &&
                      info['longitude'] is num
                  ? Coordinates(
                      (info['latitude'] as num).toDouble(),
                      (info['longitude'] as num).toDouble(),
                    )
                  : null,
              lastSeen: optional(info['last_seen_description']),
              clothing: optional(info['clothing']),
              distinctive: optional(info['distinctive_description']),
              additional: optional(info['additional_information']),
            ),
      guardian: GuardianContact(
        id: '',
        name: _text(guardian?['full_name']),
        relationship: _text(data['relationship_other'] ?? data['relationship']),
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
    result.status = _status(
      data['status'] == 'identity_confirmed'
          ? 'match_confirmed'
          : data['status'] as String?,
    );
    result.foundStatus = FoundStatus.parse(
      (data['found_status'] ?? data['status']) as String?,
    );
    if (data['person'] != null) {
      result.matchedPerson = _person(data['person'] as Map<String, dynamic>);
    }
    final proof = data['verification'] as Map<String, dynamic>?;
    if (proof != null) {
      result.verification = VerificationReceipt(
        caseId: data['case_id'] as String? ?? data['id'] as String,
        guardianId: proof['guardian_id'] as String,
        volunteerUid: proof['volunteer_uid'] as String,
        method:
            ['case_identifier', 'found_identifier'].contains(proof['method'])
            ? VerificationMethod.caseIdentifier
            : VerificationMethod.qr,
        at: DateTime.parse(proof['verified_at'] as String),
      );
    }
    result.ended = data['ended'] == true;
    result.handedOverBy = data['handed_over_by'] as String?;
    if (data['handed_over_at'] != null) {
      result.handedOverAt = DateTime.parse(data['handed_over_at'] as String);
    }
    return result;
  }

  void _updateReport(FoundReport target, Map<String, dynamic> data) {
    final value = _found(data, photo: target.photoBytes);
    if (data['photo_available'] == false ||
        data['matched_profile_id'] != null) {
      target.photoBytes = null;
    }
    if (value.status == CaseStatus.reunited && data['person'] == null) {
      target.matchedPerson = null;
    }
    target.ended = value.ended;
    target.caseId = value.caseId;
    target.status = value.status;
    target.foundStatus = value.foundStatus;
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
    final item = caseById(value.caseId ?? '');
    if (item != null && value.status != null) {
      item.status = value.status!;
      if (value.status!.index >= CaseStatus.matchConfirmed.index) {
        item.confirmedBy = account?.uid;
      }
    }
    if (!_disposed && !_accessLost) notifyListeners();
  }

  Future<FoundReport> loadReport(String id) async {
    final data = jsonDecode(
      (await _request('GET', '/found-reports/${Uri.encodeComponent(id)}')).body,
    ) as Map<String, dynamic>;
    if (data['ended'] == true) throw StateError('identification-ended');
    final photo =
        data['photo_available'] == false || data['matched_profile_id'] != null
        ? null
        : (await _request(
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

  Future<void> endIdentification(FoundReport report) async {
    await _reportAction(report, 'end');
    report.photoBytes = null;
  }

  Future<RegisteredPerson> loadProfileDetails(
    RegisteredPerson person, {
    String? foundReportId,
  }) async {
    final path = Uri(
      path: '/profiles/${person.id}',
      queryParameters: foundReportId == null
          ? null
          : {'found_report_id': foundReportId},
    ).toString();
    final row =
        jsonDecode((await _request('GET', path)).body) as Map<String, dynamic>;
    return _person(row, photo: person.photoBytes);
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
    if (!_disposed && !_accessLost) {
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
    _refreshAfterAction();
  }

  Future<VolunteerCase> loadCase(String id) async {
    final row = jsonDecode(
      (await _request('GET', '/cases/${Uri.encodeComponent(id)}')).body,
    ) as Map<String, dynamic>;
    if (_disposed || _accessLost) throw StateError('unauthorized');
    final item = _parse(row, account!.uid);
    final version = ++_dataVersion;
    _cases = [item, ..._cases.where((value) => value.id != id)];
    notifyListeners();
    if (row['photo_available'] != false) {
      unawaited(_loadCasePhotos({id: item}, version));
    }
    _refreshAfterAction();
    return item;
  }

  Future<FoundReport> confirmManualIdentity(
    String profileId,
    String requestId,
  ) async {
    final data = jsonDecode(
      (await _request(
        'POST',
        '/found-reports/manual',
        body: {'profile_id': profileId, 'request_id': requestId},
      )).body,
    ) as Map<String, dynamic>;
    final result = _found(data);
    _reports = [result, ..._reports.where((r) => r.id != result.id)];
    if (!_disposed) notifyListeners();
    return result;
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
    if (data['state'] == 'no_reliable_candidate') return [];
    if (data['state'] == 'candidates' && data['candidates'] is List) {
      final results = <MatchCandidate>[];
      for (final row in data['candidates'] as List) {
        final score = row['similarity'];
        if (score is! num ||
            !score.isFinite ||
            score < 0 ||
            score > 1 ||
            row['person'] is! Map<String, dynamic>) {
          throw StateError('unsupported-model-contract');
        }
        results.add(
          MatchCandidate(
            _person(row['person'] as Map<String, dynamic>),
            similarity: score.toDouble(),
          ),
        );
      }
      results.sort((a, b) => b.similarity!.compareTo(a.similarity!));
      return results;
    }
    throw StateError('unsupported-model-contract');
  }

  Future<void> _reportAction(
    FoundReport report,
    String action, {
    Object? body,
  }) async {
    ++_dataVersion;
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
    } on StateError catch (error) {
      if (error.message == 'photo-deletion-pending') {
        report.photoBytes = null;
        if (action == 'end') report.ended = true;
        if (!_disposed) notifyListeners();
      }
      rethrow;
    } finally {
      _joining = false;
      _refreshAfterAction();
    }
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
  ) async {
    // This transition is authorized by the server for this report. Unrelated
    // list/photo refreshes must not prevent navigation after it succeeds.
    final data = jsonDecode(
      (await _request(
        'POST',
        '/found-reports/${report.id}/begin-verification',
      )).body,
    ) as Map<String, dynamic>;
    _updateReport(report, data);
    if (!_disposed) notifyListeners();
  }

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
            : {
                if (report.caseId == null)
                  'identifier': value
                else
                  'case_id': value,
              },
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
    caseStates.clear();
    _client.close();
    _cases = [];
    super.dispose();
  }
}
