import 'dart:async';

import 'package:flutter_mort/services/precise_location_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakeGeolocatorPlatform extends GeolocatorPlatform
    with MockPlatformInterfaceMixin {
  bool servicesEnabled = true;
  LocationPermission checkPermissionResult = LocationPermission.whileInUse;
  LocationPermission requestPermissionResult = LocationPermission.whileInUse;
  LocationAccuracyStatus accuracyStatus = LocationAccuracyStatus.precise;
  Position? positionResult;
  Object? getCurrentPositionError;
  bool openAppSettingsCalled = false;
  bool openLocationSettingsCalled = false;

  @override
  Future<bool> isLocationServiceEnabled() async => servicesEnabled;

  @override
  Future<LocationPermission> checkPermission() async => checkPermissionResult;

  @override
  Future<LocationPermission> requestPermission() async =>
      requestPermissionResult;

  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() async => accuracyStatus;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    if (getCurrentPositionError != null) {
      // ignore: only_throw_errors
      throw getCurrentPositionError!;
    }
    return positionResult!;
  }

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCalled = true;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    openLocationSettingsCalled = true;
    return true;
  }
}

Position _freshPosition({DateTime? timestamp}) => Position(
  latitude: 39.7684,
  longitude: -86.1581,
  timestamp: timestamp ?? DateTime.now().toUtc(),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  late _FakeGeolocatorPlatform fake;
  late PreciseLocationService service;

  setUp(() {
    fake = _FakeGeolocatorPlatform();
    GeolocatorPlatform.instance = fake;
    service = const PreciseLocationService();
  });

  test('precise granted returns a usable, fresh position', () async {
    fake.positionResult = _freshPosition();
    final result = await service.requestFreshPreciseLocation();
    expect(result.status, PreciseLocationStatus.granted);
    expect(result.isUsable, isTrue);
    expect(result.position, isNotNull);
  });

  test('approximate-only accuracy is rejected, not silently used', () async {
    fake.accuracyStatus = LocationAccuracyStatus.reduced;
    fake.positionResult = _freshPosition();
    final result = await service.requestFreshPreciseLocation();
    expect(result.status, PreciseLocationStatus.approximateOnly);
    expect(result.isUsable, isFalse);
  });

  test('denied permission is reported, not treated as usable', () async {
    fake.checkPermissionResult = LocationPermission.denied;
    fake.requestPermissionResult = LocationPermission.denied;
    final result = await service.requestFreshPreciseLocation();
    expect(result.status, PreciseLocationStatus.denied);
  });

  test('permanently denied permission is distinguished from denied', () async {
    fake.checkPermissionResult = LocationPermission.deniedForever;
    final result = await service.requestFreshPreciseLocation();
    expect(result.status, PreciseLocationStatus.permanentlyDenied);
  });

  test(
    'location services disabled short-circuits before permission checks',
    () async {
      fake.servicesEnabled = false;
      final result = await service.requestFreshPreciseLocation();
      expect(result.status, PreciseLocationStatus.servicesDisabled);
    },
  );

  test('a timeout obtaining a fix is reported cleanly', () async {
    fake.getCurrentPositionError = TimeoutException('timed out');
    final result = await service.requestFreshPreciseLocation();
    expect(result.status, PreciseLocationStatus.timeout);
  });

  test('a stale returned position is rejected rather than used', () async {
    fake.positionResult = _freshPosition(
      timestamp: DateTime.now().toUtc().subtract(const Duration(minutes: 10)),
    );
    final result = await service.requestFreshPreciseLocation();
    expect(result.status, PreciseLocationStatus.stale);
  });

  test('an unexpected platform error is reported, not thrown', () async {
    fake.getCurrentPositionError = StateError('platform channel exploded');
    final result = await service.requestFreshPreciseLocation();
    expect(result.status, PreciseLocationStatus.error);
    expect(result.message, contains('platform channel exploded'));
  });

  test(
    'open settings and open location settings delegate to the platform',
    () async {
      await service.openSettings();
      await service.openLocationSettings();
      expect(fake.openAppSettingsCalled, isTrue);
      expect(fake.openLocationSettingsCalled, isTrue);
    },
  );
}
