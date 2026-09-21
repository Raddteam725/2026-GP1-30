import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/volunteer_models.dart';

/// Foreground-only subscription. No background location permission or service.
class VolunteerLocation extends ChangeNotifier with WidgetsBindingObserver {
  VolunteerLocation() {
    WidgetsBinding.instance.addObserver(this);
  }
  StreamSubscription<Position>? _subscription;
  Coordinates? coordinates;
  bool unavailable = false, requesting = false;
  bool permanentlyDenied = false, servicesDisabled = false;
  Future<void> initialize() async {
    try {
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
      if (!asked) await prefs.setBool('volunteer_location_requested', true);
      if (!_disposed) await request(askPermission: !asked);
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
  Future<void> request({bool askPermission = true}) async {
    if (requesting || _disposed) return;
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
      if (_disposed) return;
      _allowed = true;
      unavailable = false;
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _start();
      }
    } catch (_) {
      if (!_disposed) {
        _allowed = false;
        unavailable = true;
        coordinates = null;
      }
    } finally {
      if (!_disposed) {
        requesting = false;
        notifyListeners();
      }
    }
  }

  void _start() {
    _subscription?.cancel();
    _subscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 25,
          ),
        ).listen(
          (p) {
            if (_disposed ||
                WidgetsBinding.instance.lifecycleState !=
                    AppLifecycleState.resumed) {
              return;
            }
            // Avoid presenting city-level approximate location as a 500 m priority signal.
            coordinates = p.accuracy <= 100
                ? Coordinates(p.latitude, p.longitude)
                : null;
            unavailable = coordinates == null;
            notifyListeners();
          },
          onError: (Object e) {
            if (!_disposed) {
              coordinates = null;
              unavailable = true;
              notifyListeners();
            }
          },
        );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _subscription?.cancel();
      _subscription = null;
      coordinates = null;
      if (!_disposed) notifyListeners();
    } else if (_allowed || permanentlyDenied || servicesDisabled) {
      request(askPermission: false);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
