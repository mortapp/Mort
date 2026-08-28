import 'package:flutter_mort/features/settings/native_permissions_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  test(
    'location accuracy labels never describe reduced accuracy as precise',
    () {
      expect(
        locationAccuracyLabel(LocationAccuracyStatus.precise),
        'precise accuracy',
      );
      expect(
        locationAccuracyLabel(LocationAccuracyStatus.reduced),
        'reduced accuracy',
      );
      expect(
        locationAccuracyLabel(LocationAccuracyStatus.unknown),
        'accuracy unavailable',
      );
      expect(locationAccuracyLabel(null), 'accuracy unavailable');
    },
  );
}
