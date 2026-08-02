import '../models/backend_transport_mode.dart';
import '../models/job_lifecycle_state.dart';

class MockJob {
  final String id;
  final String title;
  final String category;
  final String pay;
  final String area;
  final String distanceLabel;
  final String estimatedTime;
  final String description;
  final List<String> requirements;
  final List<String> safetyNotes;
  final String trustBadge;
  final bool isQuickJob;
  final bool isOutdoor;
  final String posterUsername;
  final JobLifecycleState lifecycleState;
  final bool firstCome;
  final int slotsAvailable;

  MockJob({
    required this.id,
    required this.title,
    required this.category,
    required this.pay,
    required this.area,
    required this.distanceLabel,
    required this.estimatedTime,
    required this.description,
    required this.requirements,
    required this.safetyNotes,
    required this.trustBadge,
    required this.isQuickJob,
    required this.isOutdoor,
    this.posterUsername = 'mort_team',
    this.lifecycleState = JobLifecycleState.posted,
    this.firstCome = false,
    this.slotsAvailable = 1,
  });

  double get distanceMiles {
    final match = RegExp(r'([0-9]+(?:\.[0-9]+)?)').firstMatch(distanceLabel);
    if (match == null) return 3.0;
    final value = double.tryParse(match.group(1)!);
    if (value == null) return 3.0;
    return value;
  }

  int travelSuitabilityScore(BackendTransportMode mode) {
    final distance = distanceMiles;
    var score = 0;

    switch (mode) {
      case BackendTransportMode.walking:
        if (distance <= 1.5) {
          score = 5;
        } else if (distance <= 2.5)
          score = 3;
        else
          score = 1;
        break;
      case BackendTransportMode.biking:
      case BackendTransportMode.scooter:
        if (distance <= 3.5) {
          score = 5;
        } else if (distance <= 6.0)
          score = 3;
        else
          score = 1;
        break;
      case BackendTransportMode.car:
        if (distance <= 10.0) {
          score = 5;
        } else if (distance <= 20.0)
          score = 4;
        else
          score = 2;
        break;
      case BackendTransportMode.publicTransit:
        if (distance <= 5.0) {
          score = 5;
        } else if (distance <= 12.0)
          score = 3;
        else
          score = 2;
        break;
    }

    if (isOutdoor && mode == BackendTransportMode.walking) {
      score += 1;
    }
    if (!isOutdoor && mode == BackendTransportMode.car) {
      score += 1;
    }
    return score.clamp(0, 6);
  }

  String travelFitLabel(BackendTransportMode mode) {
    final score = travelSuitabilityScore(mode);
    if (score >= 5) {
      return 'Great fit for ${mode.displayName.toLowerCase()}';
    }
    if (score >= 3) {
      return 'Good with ${mode.displayName.toLowerCase()}';
    }
    return 'Better fit for another mode';
  }
}
