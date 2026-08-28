import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/features/location/precise_location_gate.dart';
import 'package:flutter_mort/services/precise_location_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakeGeolocatorPlatform extends GeolocatorPlatform
    with MockPlatformInterfaceMixin {
  bool servicesEnabled = true;
  LocationPermission checkPermissionResult = LocationPermission.whileInUse;
  LocationAccuracyStatus accuracyStatus = LocationAccuracyStatus.precise;
  int getCurrentPositionCalls = 0;
  bool openAppSettingsCalled = false;
  bool openLocationSettingsCalled = false;

  @override
  Future<bool> isLocationServiceEnabled() async => servicesEnabled;

  @override
  Future<LocationPermission> checkPermission() async => checkPermissionResult;

  @override
  Future<LocationPermission> requestPermission() async => checkPermissionResult;

  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() async => accuracyStatus;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    getCurrentPositionCalls += 1;
    return Position(
      latitude: 39.7684,
      longitude: -86.1581,
      timestamp: DateTime.now().toUtc(),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
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

void main() {
  late _FakeGeolocatorPlatform fake;

  setUp(() {
    fake = _FakeGeolocatorPlatform();
    GeolocatorPlatform.instance = fake;
  });

  Widget harness() => MaterialApp(
    theme: MortTheme.dark(),
    home: Scaffold(
      body: PreciseLocationGate(
        service: const PreciseLocationService(),
        builder: (context, position) => Text('Granted at ${position.latitude}'),
      ),
    ),
  );

  testWidgets('renders the builder content once precise location is granted', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    expect(find.textContaining('Granted at'), findsOneWidget);
    expect(find.text('Precise location required'), findsNothing);
  });

  testWidgets(
    'shows the required card and offers Open settings for approximate-only',
    (tester) async {
      fake.accuracyStatus = LocationAccuracyStatus.reduced;
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      expect(find.text('Precise location required'), findsOneWidget);
      expect(find.text('Open settings'), findsOneWidget);
      expect(find.text('Open location settings'), findsNothing);

      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
      expect(fake.openAppSettingsCalled, isTrue);
    },
  );

  testWidgets(
    'shows Open location settings (not app settings) when services are disabled',
    (tester) async {
      fake.servicesEnabled = false;
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      expect(find.text('Turn on location services'), findsOneWidget);
      expect(find.text('Open location settings'), findsOneWidget);
      expect(find.text('Open settings'), findsNothing);

      await tester.tap(find.text('Open location settings'));
      await tester.pumpAndSettle();
      expect(fake.openLocationSettingsCalled, isTrue);
    },
  );

  testWidgets('Retry re-requests location and can recover from denial', (
    tester,
  ) async {
    fake.checkPermissionResult = LocationPermission.denied;
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Precise location required'), findsOneWidget);
    expect(fake.getCurrentPositionCalls, 0);

    fake.checkPermissionResult = LocationPermission.whileInUse;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Granted at'), findsOneWidget);
    expect(fake.getCurrentPositionCalls, 1);
  });
}
