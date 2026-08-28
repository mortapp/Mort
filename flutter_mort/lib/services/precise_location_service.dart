import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// The outcome of one on-demand request for a fresh, precise device
/// location. MORT never polls location continuously -- this is only called
/// at genuine trigger points (opening/refreshing nearby jobs, changing the
/// search area, checking transportation feasibility, or other already-
/// justified location-dependent functionality).
enum PreciseLocationStatus {
  /// A fresh, precise fix was obtained. [PreciseLocationResult.position] is
  /// safe to use for on-device distance/matching calculations.
  granted,

  /// Location permission is granted but Android/iOS only offered
  /// approximate accuracy (the user picked "Approximate" in the system
  /// permission dialog, or reduced precision is otherwise in effect).
  approximateOnly,

  /// Permission was denied (but can still be re-requested).
  denied,

  /// Permission was permanently denied; only the system Settings app can
  /// change it now.
  permanentlyDenied,

  /// Location services (GPS/network location) are off at the OS level.
  servicesDisabled,

  /// A fix could not be obtained within the allotted time.
  timeout,

  /// A fix was returned but its timestamp is older than is acceptable for
  /// "fresh, on-demand" use -- defensive handling in case a platform ever
  /// returns a cached/last-known fix from this call path.
  stale,

  /// An unexpected platform error occurred.
  error,
}

class PreciseLocationResult {
  const PreciseLocationResult._(this.status, {this.position, this.message});

  const PreciseLocationResult.granted(Position position)
    : this._(PreciseLocationStatus.granted, position: position);
  const PreciseLocationResult.approximateOnly()
    : this._(PreciseLocationStatus.approximateOnly);
  const PreciseLocationResult.denied() : this._(PreciseLocationStatus.denied);
  const PreciseLocationResult.permanentlyDenied()
    : this._(PreciseLocationStatus.permanentlyDenied);
  const PreciseLocationResult.servicesDisabled()
    : this._(PreciseLocationStatus.servicesDisabled);
  const PreciseLocationResult.timeout() : this._(PreciseLocationStatus.timeout);
  const PreciseLocationResult.stale() : this._(PreciseLocationStatus.stale);
  const PreciseLocationResult.error(String message)
    : this._(PreciseLocationStatus.error, message: message);

  final PreciseLocationStatus status;
  final Position? position;
  final String? message;

  bool get isUsable => status == PreciseLocationStatus.granted;
}

/// Fetches a single fresh, precise location fix on demand. Never starts a
/// continuous stream/subscription -- callers request a fix at the moment
/// they genuinely need one and the result is not cached across calls, so
/// there is nothing here that polls GPS "merely because the app is open."
class PreciseLocationService {
  const PreciseLocationService();

  static const Duration defaultTimeout = Duration(seconds: 12);
  static const Duration maxAcceptableAge = Duration(minutes: 2);

  Future<PreciseLocationResult> requestFreshPreciseLocation({
    Duration timeout = defaultTimeout,
  }) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const PreciseLocationResult.servicesDisabled();
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return const PreciseLocationResult.permanentlyDenied();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      return const PreciseLocationResult.denied();
    }

    try {
      final accuracy = await Geolocator.getLocationAccuracy();
      if (accuracy == LocationAccuracyStatus.reduced) {
        return const PreciseLocationResult.approximateOnly();
      }
    } on Exception {
      // Some platforms/older OS versions don't support this check; fall
      // through and let getCurrentPosition itself be the source of truth.
    }

    final Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );
    } on TimeoutException {
      return const PreciseLocationResult.timeout();
    } on LocationServiceDisabledException {
      return const PreciseLocationResult.servicesDisabled();
    } on PermissionDeniedException {
      return const PreciseLocationResult.denied();
    } catch (error) {
      return PreciseLocationResult.error(error.toString());
    }

    final age = DateTime.now().toUtc().difference(position.timestamp.toUtc());
    if (age > maxAcceptableAge) {
      return const PreciseLocationResult.stale();
    }

    return PreciseLocationResult.granted(position);
  }

  Future<bool> openSettings() => Geolocator.openAppSettings();
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
