import 'dart:math' as math;

import 'mort_atmosphere_tuning.dart';

/// One rare atmospheric shimmer sweep -- a single soft diagonal light pass
/// across the whole sky. Distinct from [MortUiShimmer], which is a
/// per-widget decorative highlight on a short period; this is a sky event
/// on a long, randomized interval.
class MortAtmosphereShimmer {
  MortAtmosphereShimmer({required this.startedAt});

  final Duration startedAt;

  /// 0..1 across the sweep's lifetime; <0 before start, >1 once finished.
  double progressAt(Duration now) {
    final elapsed = now - startedAt;
    if (elapsed.isNegative) return -1;
    return elapsed.inMicroseconds /
        MortAtmosphereTuning.shimmerDuration.inMicroseconds;
  }
}

/// Schedules the rare atmospheric shimmer on a randomized interval within
/// [MortAtmosphereTuning.shimmerMinInterval]..[MortAtmosphereTuning.shimmerMaxInterval],
/// never more than one sweep active at a time.
class MortAtmosphereShimmerScheduler {
  MortAtmosphereShimmerScheduler({int seed = 21}) : _random = math.Random(seed);

  final math.Random _random;
  MortAtmosphereShimmer? _active;
  Duration _nextAt = Duration.zero;
  bool _seeded = false;

  MortAtmosphereShimmer? get active => _active;

  void tick(Duration now, {required bool enabled}) {
    if (_active != null && _active!.progressAt(now) > 1) {
      _active = null;
    }
    if (!enabled) return;
    if (!_seeded) {
      _scheduleNext(now);
      _seeded = true;
      return;
    }
    if (_active == null && now >= _nextAt) {
      _active = MortAtmosphereShimmer(startedAt: now);
      _scheduleNext(now);
    }
  }

  void _scheduleNext(Duration now) {
    final minMs = MortAtmosphereTuning.shimmerMinInterval.inMilliseconds;
    final maxMs = MortAtmosphereTuning.shimmerMaxInterval.inMilliseconds;
    final span = math.max(1, maxMs - minMs);
    _nextAt = now + Duration(milliseconds: minMs + _random.nextInt(span));
  }
}
