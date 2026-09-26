import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/volunteer_models.dart';
import '../domain/volunteer_notification_event.dart';
import 'api_volunteer_repository.dart';
import 'volunteer_session_binding.dart';

/// Uses the existing Firebase app and registration collection. Payloads are
/// navigation hints only; opening a case always rechecks backend permission.
class VolunteerPushService {
  VolunteerPushService(
    this.repo, {
    required this.onOpen,
    required this.onNotification,
  });
  final ApiVolunteerRepository repo;
  final void Function(VolunteerNotificationEvent event) onOpen;
  final void Function(VolunteerNotificationEvent event) onNotification;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  String? _token;
  bool _closed = false;
  String _locale = 'en';
  Coordinates? _location;
  Future<void> initialize(String locale) async {
    _locale = locale;
    repo.closeSession = close;
    try {
      final messaging = FirebaseMessaging.instance;
      // ID-token renewal is distinct from FCM-token rotation. Rebind the
      // existing installation through the authenticated API on either event.
      _subscriptions.add(
        bindVolunteerSession(
          FirebaseAuth.instance.idTokenChanges().map((user) => user?.uid),
          uid: repo.account!.uid,
          renew: () => sync(_locale, _location),
          end: close,
        ),
      );
      // Subscribe before any permission/token/backend round trip. Catch-up
      // dispatch during registration can otherwise arrive before the listener.
      _subscriptions.add(
        FirebaseMessaging.onMessage.listen((message) {
          final event = VolunteerNotificationEvent.fromData(message.data);
          if (!_closed && event != null) {
            if (kDebugMode) {
              debugPrint(
                'Radd FCM ${event.id} received ${DateTime.now().toUtc().toIso8601String()}',
              );
            }
            onNotification(event);
          }
        }),
      );
      _subscriptions.add(FirebaseMessaging.onMessageOpenedApp.listen(_open));
      _open(await messaging.getInitialMessage());
      if (_closed) return;
      final permission = await messaging.requestPermission();
      if (_closed ||
          permission.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }
      _token = await messaging.getToken();
      if (_closed) return;
      unawaited(sync(locale, _location));
      if (_closed) return;
      _subscriptions.add(
        messaging.onTokenRefresh.listen((token) async {
          final previous = _token;
          _token = token;
          if (previous != null && previous != token) {
            try {
              await repo.unregisterDevice(previous);
            } catch (_) {}
          }
          await sync(_locale, _location);
        }),
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Radd FCM initialization failed (${error.runtimeType})');
      }
    }
  }

  void _open(RemoteMessage? message) {
    final event = message == null
        ? null
        : VolunteerNotificationEvent.fromData(message.data);
    if (!_closed && event != null) onOpen(event);
  }

  Future<void>? _syncing;
  bool _syncAgain = false;

  Future<void> sync(String locale, Coordinates? location) {
    _locale = locale;
    _location = location;
    if (_closed || _token == null) return Future.value();
    _syncAgain = true;
    return _syncing ??= _syncLatest().whenComplete(() {
      _syncing = null;
      if (_syncAgain && !_closed) unawaited(sync(_locale, _location));
    });
  }

  Future<void> _syncLatest() async {
    // Location updates can arrive faster than a Firestore/FCM round trip.
    // Coalesce them instead of flooding the shared API with parallel dispatches.
    _syncAgain = false;
    final token = _token!;
    try {
      await repo.registerDevice(token, _locale, _location);
      // A registration already in flight must not survive a concurrent logout.
      // Do not await _syncing from close(): authorization loss can call close
      // from inside this very request.
      if (_closed) await repo.unregisterDevice(token);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Radd FCM registration failed (${error.runtimeType})');
      }
    }
  }

  Future<void>? _closing;
  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    if (_closed) return;
    _closed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    final token = _token;
    _token = null;
    if (token != null) {
      try {
        await repo.unregisterDevice(token).timeout(const Duration(seconds: 5));
      } catch (_) {}
      // Removing the installation token also prevents delivery after offline logout.
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {}
    }
  }
}
