import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../../firebase_options.dart';
import 'guardian_repository.dart';

/// FCM is an ADDITIONAL delivery channel for Guardian notifications -- the
/// existing Firestore notification records (fetched via the authenticated
/// REST API) remain the durable, authoritative in-app history. Nothing here
/// ever treats a push payload as authoritative case/status data: every
/// received message only triggers a refetch from the backend, or (for a
/// tapped notification) navigation to the right screen so the backend can be
/// asked directly.
///
/// This must keep working correctly with no FCM at all: permission denied,
/// no registration, offline, or Firebase Messaging failing outright are all
/// normal, unexceptional conditions here -- never surfaced to the Guardian as
/// an error, and never allowed to block anything else in the app.

/// Top-level, `@pragma('vm:entry-point')`-annotated per FlutterFire's current
/// requirement for `FirebaseMessaging.onBackgroundMessage` -- this runs in a
/// separate background isolate with no access to any state from the running
/// app, so it must re-initialize Firebase itself. Kept intentionally minimal:
/// the payload is data-only navigation/context information (see push.py on
/// the backend), so there is nothing to persist here -- the Guardian's next
/// authenticated screen visit already fetches current state fresh.
@pragma('vm:entry-point')
Future<void> guardianBackgroundMessageHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

/// A foreground workflow update worth a transient banner while the Guardian
/// is inside the app. Carries navigation context only (the existing push
/// payload fields); the Guardian screens fetch authoritative state
/// themselves, and the notification history stays the durable record.
class GuardianNotice {
  const GuardianNotice({
    required this.id,
    required this.caseId,
    required this.status,
    required this.kind,
  });
  final String id, caseId, status, kind;

  /// Outcomes only the Guardian can produce (cancel/resolve) and the
  /// Guardian's own report creation: the screen they are on already shows
  /// the result, so no transient banner repeats it. Everything else on the
  /// reunification path is driven by a Volunteer or an Admin.
  static const selfInitiatedKinds = {'case_created'};
  static const selfInitiatedStatuses = {'cancelled', 'resolved'};
  bool get selfInitiated =>
      selfInitiatedKinds.contains(kind) ||
      selfInitiatedStatuses.contains(status);

  static GuardianNotice? fromData(Map<String, dynamic> data) {
    if (!GuardianPushRefresh.valid(data)) return null;
    final caseId = data['case_id'] as String, status = data['status'] as String;
    final supplied = data['notification_id'];
    return GuardianNotice(
      id: supplied is String && supplied.isNotEmpty
          ? supplied
          : '$caseId-$status',
      caseId: caseId,
      status: status,
      kind: data['kind']?.toString() ?? 'status_update',
    );
  }
}

/// Notifies any listening, currently-open screen that server state may have
/// changed, without this module needing to know which screens exist or how
/// they fetch data. A screen reacts by re-running its OWN existing reload --
/// this never carries data itself, only a "something changed, go check" tick.
///
/// [notices] is the separate, foreground-only stream behind the transient
/// Guardian banner: fed exclusively by a real received push (see
/// GuardianPushService._receive) after this class's own duplicate
/// suppression accepted it -- never by screen rebuilds, tab changes, history
/// loads or app resume, so old events are never replayed as banners.
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

  /// Records a status the Guardian just produced themselves on a case they
  /// are looking at (report created, cancelled, resolved): the matching push
  /// still refreshes screens and stays in history, but raises no banner.
  void markOwnAction(String caseId, String status) {
    _ownActions.add('$caseId|$status');
    if (_ownActions.length > 64) _ownActions.remove(_ownActions.first);
  }

  bool isOwnAction(GuardianNotice notice) =>
      notice.selfInitiated ||
      _ownActions.contains('${notice.caseId}|${notice.status}');

  /// Publishes an accepted foreground push as a transient notice. Only
  /// [GuardianPushService._receive] (a real push) calls this.
  void announce(Map<String, dynamic> data) {
    final notice = GuardianNotice.fromData(data);
    if (notice == null || isOwnAction(notice)) return;
    _notices.add(notice);
  }

  static bool valid(Map<String, dynamic> data) {
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
    final key = '${data['case_id']}|${data['status']}';
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
    caseId = data['case_id'] as String;
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

/// Holds a case id from a notification the Guardian tapped (from the
/// background or from terminated) until normal authenticated navigation is
/// ready to act on it. A case id arriving this way is navigation context
/// ONLY -- opening that screen still goes through the authenticated backend
/// and its existing Guardian-ownership checks, exactly like opening it from
/// the Cases list would.
class GuardianPushRouter {
  GuardianPushRouter._();
  static String? _pendingCaseId;

  /// Called once, when normal authenticated application state is available
  /// (see GuardianGate) -- returns and clears the pending case id, if any.
  static String? consumePendingCaseId() {
    final id = _pendingCaseId;
    _pendingCaseId = null;
    return id;
  }

  static void _setPending(RemoteMessage? message) {
    if (message == null || !GuardianPushRefresh.valid(message.data)) return;
    final caseId = message.data['case_id'];
    if (caseId is String && caseId.isNotEmpty) _pendingCaseId = caseId;
  }
}

class GuardianPushService {
  GuardianPushService._();
  static bool _initialized = false;
  // The installation's own current registration, cached here once uploaded
  // successfully -- lets syncLocale()/handleLogout() act on it without a
  // further FirebaseMessaging platform call (and makes both testable without
  // one). Cleared on logout so a later Guardian's session starts clean.
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
    // Screens have been told to refetch (acceptPush); additionally surface
    // this newly received update as a transient in-app banner. Duplicates
    // never reach here, so a banner is shown at most once per event.
    GuardianPushRefresh.instance.announce(message.data);
  }

  // FirebaseMessaging.instance is a device-level singleton that is never
  // itself torn down or reinitialized across a Guardian logging out and a
  // (possibly different) Guardian logging in within the same app process --
  // only THIS class's own state changes at those points. So every listener
  // initialize() attaches to it must be tracked here and explicitly
  // cancelled at the right moment (logout, and defensively before a fresh
  // initialize() attaches new ones) -- otherwise each login/logout cycle
  // would stack another listener onto the same underlying stream, each one
  // still firing (and still doing registration work) forever after.
  static StreamSubscription<String>? _tokenRefreshSub;
  static StreamSubscription<RemoteMessage>? _onMessageSub;
  static StreamSubscription<RemoteMessage>? _onMessageOpenedSub;

  /// Idempotent: safe to call every time the Guardian becomes authenticated
  /// (e.g. on every GuardianGate build) -- only does its one-time setup once
  /// per app process (until [handleLogout] resets it). Never throws: every
  /// step that can fail (permission denial, no Firebase Messaging support, a
  /// registration upload failing) is caught and simply skipped, leaving the
  /// rest of the app unaffected.
  ///
  /// [locale] is Radd's own current in-app language ('en'/'ar' -- e.g.
  /// `Localizations.localeOf(context).languageCode`, NOT the device's system
  /// locale). This is only the INITIAL value; if the Guardian changes
  /// language afterwards while this same session/process continues, call
  /// [syncLocale] (see GuardianGate) -- it keeps the already-registered
  /// installation's push language current without a restart, logout, or
  /// token rotation.
  static Future<void> initialize(
    GuardianRepository guardian,
    String locale,
  ) async {
    if (_initialized) return;
    _initialized = true;
    final generation = ++_generation;
    try {
      // Defensive: the _initialized guard above already prevents a second
      // concurrent initialize() from reaching here, and handleLogout()
      // already cancels these at sign-out -- but reinitializing on top of a
      // stray leftover subscription must never be possible, so clear any
      // before attaching fresh ones.
      await _cancelSubscriptions();
      WidgetsBinding.instance.addObserver(GuardianPushRefresh.instance);
      _observing = true;
      final messaging = FirebaseMessaging.instance;
      // Install listeners before permission, token retrieval or upload.
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
      // Any Firebase Messaging failure here (unsupported platform, transient
      // service failure, ...) must never affect the rest of the app.
    }
  }

  /// Keeps an already-registered installation's push language in sync with
  /// Radd's own current language, without a restart/logout/token rotation.
  /// Call this whenever the current locale might have changed since setup
  /// (GuardianGate does, on every rebuild after the first). A cheap no-op
  /// when nothing changed, when push was never set up (denied/unsupported),
  /// or when no token has been uploaded yet -- never throws.
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
      // Only recorded on success: a failed attempt (e.g. offline) leaves
      // these as they were, so the next opportunity -- another syncLocale
      // check, an onTokenRefresh, or the next app start -- retries with the
      // current locale instead of wrongly assuming it already matches.
      _lastKnownToken = token;
      _lastSyncedLocale = locale;
      if (_pendingToken == token) _pendingToken = null;
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'Radd Guardian FCM registration failed (${error.runtimeType})',
        );
      }
      // Never surfaced to the Guardian and never a reason to fail anything else.
    }
  }

  /// Call before signing out (see GuardianHomeScreen/SessionScreen) so this
  /// installation stops being able to receive the signing-out Guardian's
  /// pushes, and so a DIFFERENT Guardian signing in afterwards in the same
  /// app process gets set up fresh rather than being silently skipped by the
  /// one-time [initialize] guard above.
  ///
  /// Cancels every listener [initialize] attached (see _cancelSubscriptions)
  /// FIRST -- the previous session's onTokenRefresh (and onMessage/
  /// onMessageOpenedApp) listeners must never fire again after this, so a
  /// repeated Guardian A -> logout -> Guardian B -> logout -> Guardian C
  /// cycle never stacks up more than one active listener at a time. Local
  /// state is then cleared unconditionally before attempting the network
  /// call -- so a failure here (e.g. offline) can never block or corrupt the
  /// actual sign-out, and the next Guardian's initialize() is never blocked
  /// by it either. The network call itself is best-effort with a short
  /// bounded timeout specifically so an offline logout doesn't make the
  /// Guardian wait on it; the backend independently sweeps away any
  /// leftover registration for this same token the next time ANY guardian
  /// registers it (see service.register_fcm_token), so a missed cleanup here
  /// is not the only safeguard against a stale cross-account registration.
  static Future<void> handleLogout(GuardianRepository guardian) async {
    ++_generation;
    GuardianPushRefresh.instance.reset();
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
      // Offline, or any other failure: logout must proceed regardless. The
      // registration is stale, not dangerous by itself -- it is only ever
      // acted on again if a genuinely new event fires for the PREVIOUS
      // Guardian, and the server-side sweep above closes that gap the next
      // time this installation registers for anyone.
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
    // Not awaited (this stays synchronous for use in a plain `setUp`), but
    // still requested so a test-seeded subscription doesn't dangle.
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

  /// Test-only seam standing in for the subscription [initialize] would
  /// normally attach to FirebaseMessaging.instance.onTokenRefresh (real
  /// FirebaseMessaging is unavailable in plain flutter_test) -- lets tests
  /// verify the actual cancellation behavior of [handleLogout] and
  /// [initialize]'s defensive cancel-before-reattach against a real
  /// StreamSubscription, without touching Firebase.
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
