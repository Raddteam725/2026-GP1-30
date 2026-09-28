import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/volunteer_models.dart';

/// Location permission/services are independent of the availability of a fix.
/// Background continuation must be explicitly authorized by event participation.
class VolunteerLocation extends ChangeNotifier with WidgetsBindingObserver {
  VolunteerLocation() {
    WidgetsBinding.instance.addObserver(this);
  }
  StreamSubscription<Position>? _subscription;
  StreamSubscription<ServiceStatus>? _services;
  ForegroundNotificationConfig? _backgroundNotification;
  bool _stopped = false;
  int _generation = 0;
  Future<void> _cancelling = Future.value();
  bool get accessGranted => _allowed && !servicesDisabled && !_stopped;
  bool get continuesInBackground => _backgroundNotification != null;
  Coordinates? _coordinates;
  DateTime? _estimateAt;
  Coordinates? get coordinates =>
      _estimateAt != null &&
          DateTime.now().difference(_estimateAt!) > const Duration(seconds: 60)
      ? null
      : _coordinates;
  set coordinates(Coordinates? value) {
    _coordinates = value;
    _estimateAt = value == null ? null : DateTime.now();
  }

  bool unavailable = false, requesting = false;
  bool permanentlyDenied = false, servicesDisabled = false;
  Future<void> initialize({bool askPermissionOnFirstUse = true}) async {
    if (_disposed || _stopped) return;
    try {
      _services ??= Geolocator.getServiceStatusStream().listen(
        (status) {
          if (_disposed || _stopped) return;
          if (status == ServiceStatus.disabled) {
            servicesDisabled = true;
            _allowed = false;
            unavailable = true;
            unawaited(_cancelPositions());
            notifyListeners();
          } else {
            unawaited(request(askPermission: false));
          }
        },
        onError: (Object error) {
          if (kDebugMode) {
            debugPrint('Radd location services stream: ${error.runtimeType}');
          }
        },
      );
      final permission = await Geolocator.checkPermission();
      if (_disposed) return;
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        await request(askPermission: false);
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      if (_disposed) return;
      final asked = prefs.getBool('volunteer_location_requested') ?? false;
      if (!asked && askPermissionOnFirstUse) {
        await prefs.setBool('volunteer_location_requested', true);
      }
      if (!_disposed) {
        await request(askPermission: !asked && askPermissionOnFirstUse);
      }
    } catch (_) {
      if (!_disposed) {
        unavailable = true;
        notifyListeners();
      }
    }
  }

  Future<void> openSettings() async {
    if (servicesDisabled) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }

  bool _allowed = false, _disposed = false;

  /// Call only after authoritative event-assignment authorization. No UI action
  /// or local account flag should grant this authorization. The workspace calls
  /// this only after the shared API confirms the current event assignment.
  Future<void> authorizeBackgroundParticipation({
    required String title,
    required String description,
    required String channelName,
  }) async {
    if (_disposed ||
        _stopped ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    _backgroundNotification = ForegroundNotificationConfig(
      notificationTitle: title,
      notificationText: description,
      notificationChannelName: channelName,
      notificationIcon: const AndroidResource(name: 'ic_volunteer_location'),
      setOngoing: true,
      enableWakeLock: true,
    );
    await _cancelPositions();
    await request(askPermission: false);
  }

  Future<void> _cancelPositions() async {
    ++_generation;
    coordinates = null;
    final previous = _subscription;
    _subscription = null;
    if (previous != null) _cancelling = previous.cancel();
    await _cancelling;
  }

  /// Stops before asynchronous logout/network cleanup; late fixes are ignored.
  Future<void> stop() async {
    _stopped = true;
    _allowed = false;
    _backgroundNotification = null;
    final cancellation = _cancelPositions();
    await _services?.cancel();
    _services = null;
    await cancellation;
    if (!_disposed) notifyListeners();
  }

  Future<void> request({bool askPermission = true}) async {
    if (requesting || _disposed || _stopped) return;
    requesting = true;
    notifyListeners();
    try {
      servicesDisabled = !await Geolocator.isLocationServiceEnabled();
      if (servicesDisabled) {
        throw StateError('location-disabled');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && askPermission) {
        permission = await Geolocator.requestPermission();
      }
      permanentlyDenied = permission == LocationPermission.deniedForever;
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        throw StateError('location-denied');
      }
      if (_disposed || _stopped) return;
      if (servicesDisabled) throw StateError('location-disabled');
      _allowed = true;
      unavailable = coordinates == null;
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        await _cancelling;
        if (!_disposed &&
            !_stopped &&
            !servicesDisabled &&
            WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed) {
          _start();
        }
      }
    } catch (_) {
      if (!_disposed) {
        _allowed = false;
        unavailable = true;
        coordinates = null;
        await _cancelPositions();
      }
    } finally {
      if (!_disposed) {
        requesting = false;
        notifyListeners();
      }
    }
  }

  void _start() {
    if (_subscription != null || _disposed || _stopped || !accessGranted) {
      return;
    }
    final generation = ++_generation;
    try {
      _subscription =
          Geolocator.getPositionStream(
            locationSettings: defaultTargetPlatform == TargetPlatform.android
                ? AndroidSettings(
                    accuracy: LocationAccuracy.high,
                    distanceFilter: continuesInBackground ? 0 : 25,
                    intervalDuration: const Duration(seconds: 20),
                    foregroundNotificationConfig: _backgroundNotification,
                  )
                : const LocationSettings(
                    accuracy: LocationAccuracy.high,
                    distanceFilter: 25,
                  ),
          ).listen(
            (p) {
              if (_disposed ||
                  _stopped ||
                  generation != _generation ||
                  (!continuesInBackground &&
                      WidgetsBinding.instance.lifecycleState !=
                          AppLifecycleState.resumed)) {
                return;
              }
              // Avoid presenting city-level approximate location as a 500 m priority signal.
              coordinates =
                  p.accuracy.isFinite &&
                      p.accuracy >= 0 &&
                      p.accuracy <= 100 &&
                      p.latitude.isFinite &&
                      p.longitude.isFinite &&
                      p.latitude.abs() <= 90 &&
                      p.longitude.abs() <= 180 &&
                      DateTime.now().difference(p.timestamp).abs() <=
                          const Duration(seconds: 60)
                  ? Coordinates(p.latitude, p.longitude)
                  : null;
              unavailable = coordinates == null;
              notifyListeners();
            },
            onError: (Object e) {
              if (!_disposed && !_stopped && generation == _generation) {
                if (kDebugMode) {
                  debugPrint('Radd location fix failed: ${e.runtimeType}');
                }
                coordinates = null;
                unavailable = true;
                notifyListeners();
                unawaited(_recoverFixFailure());
              }
            },
          );
    } catch (error) {
      if (kDebugMode) debugPrint('Radd position stream: ${error.runtimeType}');
      // Permission was checked independently. A plugin/GPS failure cannot
      // turn a valid permission into denial; recovery retries on the heartbeat.
      coordinates = null;
      unavailable = true;
    }
  }

  Future<void> _recoverFixFailure() async {
    await _cancelPositions();
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      final permission = await Geolocator.checkPermission();
      if (_disposed || _stopped) return;
      servicesDisabled = !enabled;
      permanentlyDenied = permission == LocationPermission.deniedForever;
      _allowed =
          enabled &&
          (permission == LocationPermission.whileInUse ||
              permission == LocationPermission.always);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Radd location access recheck: ${error.runtimeType}');
      }
    }
    if (!_disposed && !_stopped) notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed || _stopped) return;
    if (state != AppLifecycleState.resumed && !continuesInBackground) {
      unawaited(_cancelPositions());
      if (!_disposed) notifyListeners();
    } else if (state == AppLifecycleState.resumed) {
      request(askPermission: false);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stop());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
