import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../../firebase_options.dart';
import 'guardian_repository.dart';


@pragma('vm:entry-point')
Future<void> guardianBackgroundMessageHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class GuardianNotice {
  const GuardianNotice({
    required this.id,
    required this.caseId,
    required this.status,
    required this.kind,
    this.foundReportId,
  });
  final String id, caseId, status, kind;
  final String? foundReportId;

  static const selfInitiatedKinds = {'case_created'};
  static const selfInitiatedStatuses = {'cancelled', 'resolved'};
  bool get selfInitiated =>
      selfInitiatedKinds.contains(kind) ||
      selfInitiatedStatuses.contains(status);

  static GuardianNotice? fromData(Map<String, dynamic> data) {
    if (!GuardianPushRefresh.valid(data)) return null;
    final caseId = data['case_id'] as String? ?? '';
    final foundReportId = data['found_report_id'] as String?;
    final status = data['status'] as String;
    final supplied = data['notification_id'];
    return GuardianNotice(
      id: supplied is String && supplied.isNotEmpty
          ? supplied
          : '${foundReportId ?? caseId}-$status',
      caseId: caseId,
      foundReportId: foundReportId,
      status: status,
      kind: data['kind']?.toString() ?? 'status_update',
    );
  }
}

class GuardianPushRefresh extends ChangeNotifier with WidgetsBindingObserver {
  GuardianPushRefresh._();
  static final instance = GuardianPushRefresh._();
  String? caseId;
  final Set<String> _events = {};
  final Set<String> _ids = {};
  final Set<String> _ownActions = {};
  final StreamController<GuardianNotice> _notices =
      StreamController<GuardianNotice>.broadcast();
  Stream<GuardianNotice> get notices => _notices.stream;
  bool concerns(String id) => caseId == null || caseId == id;

  void markOwnAction(String caseId, String status) {
    _ownActions.add('$caseId|$status');
    if (_ownActions.length > 64) _ownActions.remove(_ownActions.first);
  }

  bool isOwnAction(GuardianNotice notice) =>
      notice.selfInitiated ||
      _ownActions.contains('${notice.caseId}|${notice.status}');

  void announce(Map<String, dynamic> data) {
    final notice = GuardianNotice.fromData(data);
    if (notice == null || isOwnAction(notice)) return;
    _notices.add(notice);
  }

  static bool valid(Map<String, dynamic> data) {
    if (data['found_report_id'] != null) {
      final id = data['found_report_id'];
      return data['role'] == 'guardian' &&
          data['kind'] == 'found_report' &&
          data['case_id'] == null &&
          id is String &&
          id.isNotEmpty &&
          !id.contains('/') &&
          const {'identity_confirmed', 'reunited'}.contains(data['status']);
    }
    final role = data['role'], id = data['case_id'], status = data['status'];
    return (role == null || role == 'guardian') &&
        id is String &&
        id.isNotEmpty &&
        !id.contains('/') &&
        const {
          'report_received',
          'search_in_progress',
          'match_confirmed',
          'awaiting_guardian_verification',
          'reunited',
          'resolved',
          'cancelled',
          'referred_to_authority',
        }.contains(status);
  }

  bool acceptPush(Map<String, dynamic> data) {
    if (!valid(data)) return false;
    final key =
        '${data['found_report_id'] ?? data['case_id']}|${data['status']}';
    final id = data['notification_id'];
    if (_events.contains(key) || (id is String && _ids.contains(id))) {
      return false;
    }
    _events.add(key);
    if (_events.length > 256) _events.remove(_events.first);
    if (id is String && id.isNotEmpty) {
      _ids.add(id);
      if (_ids.length > 256) _ids.remove(_ids.first);
    }
    caseId = data['case_id'] as String?;
    notifyListeners();
    return true;
  }

  void reset() {
    caseId = null;
    _events.clear();
    _ids.clear();
    _ownActions.clear();
  }

  void ping() {
    caseId = null;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ping();
  }
}

class GuardianPushRouter {
  GuardianPushRouter._();
  static String? _pendingCaseId;
  static String? _pendingFoundReportId;

  static String? consumePendingFoundReportId() {
    final id = _pendingFoundReportId;
    _pendingFoundReportId = null;
    return id;
  }

  static String? consumePendingCaseId() {
    final id = _pendingCaseId;
    _pendingCaseId = null;
    return id;
  }

  static void _setPending(RemoteMessage? message) {
    if (message == null || !GuardianPushRefresh.valid(message.data)) return;
    _pendingFoundReportId = message.data['found_report_id'] as String?;
    _pendingCaseId = null;
    final caseId = message.data['case_id'];
    if (caseId is String && caseId.isNotEmpty) _pendingCaseId = caseId;
  }
}

class GuardianPushService {
  GuardianPushService._();
  static bool _initialized = false;
  static String? _lastKnownToken;
  static String? _pendingToken;
  static String? _lastSyncedLocale;
  static StreamSubscription<User?>? _authSub;
  static int _generation = 0;
  static bool _observing = false;
  static void _receive(RemoteMessage message) {
    if (!GuardianPushRefresh.instance.acceptPush(message.data)) return;
    final id = message.data['notification_id'] ?? message.messageId;
    if (kDebugMode) {
      debugPrint(
        'Radd Guardian FCM $id T6/T7 ${DateTime.now().toUtc().toIso8601String()}',
      );
    }
    GuardianPushRefresh.instance.announce(message.data);
  }

  static StreamSubscription<String>? _tokenRefreshSub;
  static StreamSubscription<RemoteMessage>? _onMessageSub;
  static StreamSubscription<RemoteMessage>? _onMessageOpenedSub;

  static Future<void> initialize(
    GuardianRepository guardian,
    String locale,
  ) async {
    if (_initialized) return;
    _initialized = true;
    final generation = ++_generation;
    try {
      await _cancelSubscriptions();
      WidgetsBinding.instance.addObserver(GuardianPushRefresh.instance);
      _observing = true;
      final messaging = FirebaseMessaging.instance;
      _onMessageSub = FirebaseMessaging.onMessage.listen(_receive);
      _onMessageOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen((
        message,
      ) {
        if (!GuardianPushRefresh.valid(message.data)) return;
        GuardianPushRouter._setPending(message);
        GuardianPushRefresh.instance.ping();
      });
      GuardianPushRouter._setPending(await messaging.getInitialMessage());
      if (generation != _generation) return;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      _authSub = FirebaseAuth.instance.idTokenChanges().listen((user) {
        if (generation != _generation) return;
        if (user == null || user.uid != uid) {
          unawaited(handleLogout(guardian));
        } else if ((_lastKnownToken ?? _pendingToken) != null) {
          unawaited(
            _upload(
              guardian,
              _pendingToken ?? _lastKnownToken!,
              _lastSyncedLocale ?? locale,
            ),
          );
        }
      });
      final settings = await messaging.requestPermission();
      if (generation != _generation ||
          settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }
      final token = await messaging.getToken();
      if (generation != _generation) return;
      if (token != null) unawaited(_upload(guardian, token, locale));
      _tokenRefreshSub = messaging.onTokenRefresh.listen(
        (refreshed) =>
            _upload(guardian, refreshed, _lastSyncedLocale ?? locale),
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Radd Guardian FCM setup failed (${error.runtimeType})');
      }
    }
  }

  static Future<void> syncLocale(
    GuardianRepository guardian,
    String locale,
  ) async {
    final token = _lastKnownToken;
    if (token == null || _lastSyncedLocale == locale) return;
    await _upload(guardian, token, locale);
  }

  static Future<void> _upload(
    GuardianRepository guardian,
    String token,
    String locale,
  ) async {
    final generation = _generation;
    _pendingToken = token;
    try {
      await guardian.registerFcmToken(token, locale);
      if (generation != _generation) {
        await guardian.unregisterFcmToken(token);
        return;
      }
      _lastKnownToken = token;
      _lastSyncedLocale = locale;
      if (_pendingToken == token) _pendingToken = null;
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'Radd Guardian FCM registration failed (${error.runtimeType})',
        );
      }
    }
  }

  static Future<void> handleLogout(GuardianRepository guardian) async {
    ++_generation;
    GuardianPushRefresh.instance.reset();
    GuardianPushRouter.consumePendingFoundReportId();
    GuardianPushRouter.consumePendingCaseId();
    if (_observing) {
      WidgetsBinding.instance.removeObserver(GuardianPushRefresh.instance);
      _observing = false;
    }
    final token = _pendingToken ?? _lastKnownToken;
    await _cancelSubscriptions();
    _initialized = false;
    _lastKnownToken = null;
    _pendingToken = null;
    _lastSyncedLocale = null;
    if (token == null) return;
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
    try {
      await guardian
          .unregisterFcmToken(token)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
    }
  }

  static Future<void> _cancelSubscriptions() async {
    await _authSub?.cancel();
    _authSub = null;
    await _tokenRefreshSub?.cancel();
    await _onMessageSub?.cancel();
    await _onMessageOpenedSub?.cancel();
    _tokenRefreshSub = null;
    _onMessageSub = null;
    _onMessageOpenedSub = null;
  }

  @visibleForTesting
  static void resetForTesting() {
    if (_observing) {
      WidgetsBinding.instance.removeObserver(GuardianPushRefresh.instance);
      _observing = false;
    }
    ++_generation;
    GuardianPushRefresh.instance.reset();
    unawaited(_authSub?.cancel());
    _authSub = null;
    unawaited(_tokenRefreshSub?.cancel());
    unawaited(_onMessageSub?.cancel());
    unawaited(_onMessageOpenedSub?.cancel());
    _initialized = false;
    _lastKnownToken = null;
    _pendingToken = null;
    _lastSyncedLocale = null;
    _tokenRefreshSub = null;
    _onMessageSub = null;
    _onMessageOpenedSub = null;
  }

  @visibleForTesting
  static void debugSeedToken(String token, String locale) {
    _initialized = true;
    _lastKnownToken = token;
    _lastSyncedLocale = locale;
  }

  @visibleForTesting
  static String? get debugLastKnownToken => _lastKnownToken;
  @visibleForTesting
  static String? get debugLastSyncedLocale => _lastSyncedLocale;

  @visibleForTesting
  static void debugSeedTokenRefreshSubscription(
    StreamSubscription<String> subscription,
  ) {
    _tokenRefreshSub = subscription;
  }

  @visibleForTesting
  static bool get debugHasActiveTokenRefreshSubscription =>
      _tokenRefreshSub != null;

  @visibleForTesting
  static void debugReceive(RemoteMessage message) => _receive(message);
}
