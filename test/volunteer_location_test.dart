import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:radd/features/volunteer/data/volunteer_location.dart';

class LocationPlatform extends GeolocatorPlatform {
  LocationPermission permission = LocationPermission.denied;
  LocationPermission response = LocationPermission.denied;
  bool enabled = true;
  int requests = 0, settings = 0, streams = 0;
  final positions = StreamController<Position>.broadcast();
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return permission = response;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<bool> openAppSettings() async {
    settings++;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    settings++;
    return true;
  }

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    streams++;
    return positions.stream;
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late GeolocatorPlatform previous;
  late LocationPlatform platform;
  setUp(() {
    previous = GeolocatorPlatform.instance;
    platform = LocationPlatform();
    GeolocatorPlatform.instance = platform;
    SharedPreferences.setMockInitialValues({});
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
  tearDown(() async {
    GeolocatorPlatform.instance = previous;
    await platform.positions.close();
  });
  test(
    'First use asks once; denial never repeatedly prompts on re-entry',
    () async {
      final first = VolunteerLocation();
      await first.initialize();
      expect(platform.requests, 1);
      expect(first.unavailable, isTrue);
      first.dispose();
      final second = VolunteerLocation();
      await second.initialize();
      expect(platform.requests, 1);
      await second.request();
      expect(platform.requests, 2); // explicit retry only
      second.dispose();
    },
  );
  test('Previously granted permission starts foreground location without a popup and stops in background', () async {
    platform.permission = LocationPermission.whileInUse;
    final location = VolunteerLocation();
    await location.initialize();
    expect(platform.requests, 0);
    expect(platform.streams, 1);
    platform.positions.add(
      Position(
        latitude: 24.7,
        longitude: 46.7,
        timestamp: DateTime.now(),
        accuracy: 10,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      ),
    );
    await pumpEventQueue();
    expect(location.coordinates!.latitude, 24.7);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(location.coordinates, isNull);
    location.dispose();
  });
  test(
    'Permanent denial leads to Settings without another OS permission request',
    () async {
      platform.permission = LocationPermission.deniedForever;
      final location = VolunteerLocation();
      await location.initialize();
      expect(location.permanentlyDenied, isTrue);
      expect(platform.requests, 0);
      await location.openSettings();
      expect(platform.settings, 1);
      platform.permission = LocationPermission.whileInUse;
      location.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();
      expect(location.permanentlyDenied, isFalse);
      expect(platform.streams, 1);
      location.dispose();
    },
  );
  test('Disabled location services and approximate fixes do not grant priority eligibility', () async {
    platform.enabled = false;
    final location = VolunteerLocation();
    await location.initialize();
    expect(location.servicesDisabled, isTrue);
    expect(location.coordinates, isNull);
    await location.openSettings();
    expect(platform.settings, 1);
    platform.enabled = true;
    platform.permission = LocationPermission.whileInUse;
    await location.request();
    platform.positions.add(
      Position(
        latitude: 24.7,
        longitude: 46.7,
        timestamp: DateTime.now(),
        accuracy: 1000,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      ),
    );
    await pumpEventQueue();
    expect(location.coordinates, isNull);
    location.dispose();
  });
}
