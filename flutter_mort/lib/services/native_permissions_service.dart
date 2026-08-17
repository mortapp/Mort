import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class NativePermissionSnapshot {
  const NativePermissionSnapshot({
    required this.notifications,
    required this.camera,
    required this.photos,
    required this.location,
    required this.locationAccuracy,
    required this.locationServicesEnabled,
    required this.photoPickerNeedsBroadPermission,
  });

  final PermissionStatus notifications;
  final PermissionStatus camera;
  final PermissionStatus photos;
  final LocationPermission location;
  final LocationAccuracyStatus? locationAccuracy;
  final bool locationServicesEnabled;
  final bool photoPickerNeedsBroadPermission;
}

class GeneralSearchArea {
  const GeneralSearchArea({required this.city, required this.state});

  final String city;
  final String state;
}

class NativePermissionsService {
  const NativePermissionsService();

  Future<NativePermissionSnapshot> snapshot() async {
    final photoPermissionNeeded =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final notificationsFuture = Permission.notification.status;
    final cameraFuture = Permission.camera.status;
    final photosFuture = photoPermissionNeeded
        ? Permission.photos.status
        : Future.value(PermissionStatus.granted);
    final locationFuture = Geolocator.checkPermission();
    final servicesFuture = Geolocator.isLocationServiceEnabled();
    final location = await locationFuture;

    return NativePermissionSnapshot(
      notifications: await notificationsFuture,
      camera: await cameraFuture,
      photos: await photosFuture,
      location: location,
      locationAccuracy: await _readLocationAccuracy(location),
      locationServicesEnabled: await servicesFuture,
      photoPickerNeedsBroadPermission: photoPermissionNeeded,
    );
  }

  Future<PermissionStatus> requestCamera() => Permission.camera.request();

  Future<PermissionStatus> requestPhotos() {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.android) {
      return Future.value(PermissionStatus.granted);
    }
    return Permission.photos.request();
  }

  Future<LocationPermission> requestForegroundLocation() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  Future<GeneralSearchArea> resolveCurrentGeneralArea() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      throw StateError(
        'Use the manual city and state fields on this platform.',
      );
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError(
        'Location services are off. Use the manual city and state fields or enable location in device settings.',
      );
    }
    final permission = await requestForegroundLocation();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError(
        'Location permission was not granted. Manual city and state search remains available.',
      );
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 15),
      ),
    );
    final placemarks = await Geocoding().placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
    if (placemarks.isEmpty) {
      throw StateError(
        'The device could not resolve a general area. Enter city and state manually.',
      );
    }
    final place = placemarks.first;
    final city = (place.locality?.trim().isNotEmpty == true
        ? place.locality
        : place.subAdministrativeArea);
    final state = place.administrativeArea;
    if (city == null || city.trim().isEmpty || state == null || state.isEmpty) {
      throw StateError(
        'The device did not return a city and state. Enter the area manually.',
      );
    }
    return GeneralSearchArea(
      city: city.trim(),
      state: _stateCode(state.trim()),
    );
  }

  Future<bool> openSettings() => openAppSettings();

  Future<LocationAccuracyStatus?> _readLocationAccuracy(
    LocationPermission permission,
  ) async {
    if (kIsWeb ||
        permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    try {
      return await Geolocator.getLocationAccuracy();
    } on Exception {
      return null;
    }
  }
}

String _stateCode(String value) {
  final upper = value.toUpperCase();
  if (RegExp(r'^[A-Z]{2}$').hasMatch(upper)) return upper;
  return const {
        'ALABAMA': 'AL',
        'ALASKA': 'AK',
        'ARIZONA': 'AZ',
        'ARKANSAS': 'AR',
        'CALIFORNIA': 'CA',
        'COLORADO': 'CO',
        'CONNECTICUT': 'CT',
        'DELAWARE': 'DE',
        'DISTRICT OF COLUMBIA': 'DC',
        'FLORIDA': 'FL',
        'GEORGIA': 'GA',
        'HAWAII': 'HI',
        'IDAHO': 'ID',
        'ILLINOIS': 'IL',
        'INDIANA': 'IN',
        'IOWA': 'IA',
        'KANSAS': 'KS',
        'KENTUCKY': 'KY',
        'LOUISIANA': 'LA',
        'MAINE': 'ME',
        'MARYLAND': 'MD',
        'MASSACHUSETTS': 'MA',
        'MICHIGAN': 'MI',
        'MINNESOTA': 'MN',
        'MISSISSIPPI': 'MS',
        'MISSOURI': 'MO',
        'MONTANA': 'MT',
        'NEBRASKA': 'NE',
        'NEVADA': 'NV',
        'NEW HAMPSHIRE': 'NH',
        'NEW JERSEY': 'NJ',
        'NEW MEXICO': 'NM',
        'NEW YORK': 'NY',
        'NORTH CAROLINA': 'NC',
        'NORTH DAKOTA': 'ND',
        'OHIO': 'OH',
        'OKLAHOMA': 'OK',
        'OREGON': 'OR',
        'PENNSYLVANIA': 'PA',
        'RHODE ISLAND': 'RI',
        'SOUTH CAROLINA': 'SC',
        'SOUTH DAKOTA': 'SD',
        'TENNESSEE': 'TN',
        'TEXAS': 'TX',
        'UTAH': 'UT',
        'VERMONT': 'VT',
        'VIRGINIA': 'VA',
        'WASHINGTON': 'WA',
        'WEST VIRGINIA': 'WV',
        'WISCONSIN': 'WI',
        'WYOMING': 'WY',
      }[upper] ??
      upper;
}
