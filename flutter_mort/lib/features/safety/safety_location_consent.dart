import 'package:geolocator/geolocator.dart';
import 'safety_device_status.dart';

/// Called only after a teen explicitly selects location sharing. Declining
/// location permission does not undo their contact alert or job exit.
Future<bool> requestSafetyLocationConsent() async {
  try {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    final allowed =
        permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
    if (allowed) safetyMonitorRefresh.value++;
    return allowed;
  } catch (_) {
    return false;
  }
}
