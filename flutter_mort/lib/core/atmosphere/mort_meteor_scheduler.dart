import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'mort_atmosphere_tuning.dart';

/// A single meteor's flight, in scene-relative coordinates.
class MortMeteor {
  MortMeteor({
    required this.start,
    required this.angleRadians,
    required this.length,
    required this.spawnedAt,
    required this.duration,
    required this.behindForeground,
  });

  final Offset start;
  final double angleRadians;
  final double length;
  final Duration spawnedAt;
  final Duration duration;

  /// true for the ~40% of meteors that render behind clouds/wordmark, so
  /// MORT reads as embedded inside the atmosphere rather than floating
  /// on top of it.
  final bool behindForeground;

  /// 0..1 lifecycle progress; painter treats <0 or >1 as "not visible".
  double progressAt(Duration now) {
    final elapsed = now - spawnedAt;
    if (elapsed.isNegative) return -1;
    final t = elapsed.inMicroseconds / duration.inMicroseconds;
    return t;
  }

  /// Asymmetric fade: quick fade in, hold, slow fade out -- never a
  /// symmetric triangle fade.
  double opacityAt(double t) {
    if (t < 0 || t > 1) return 0;
    if (t < MortAtmosphereTuning.meteorFadeInFraction) {
      return t / MortAtmosphereTuning.meteorFadeInFraction;
    }
    if (t > MortAtmosphereTuning.meteorFadeOutStartFraction) {
      final fadeT =
          (t - MortAtmosphereTuning.meteorFadeOutStartFraction) /
          (1 - MortAtmosphereTuning.meteorFadeOutStartFraction);
      return (1 - fadeT).clamp(0.0, 1.0);
    }
    return 1;
  }
}

/// Schedules meteor spawns on a randomized-but-rhythmic cadence per the
/// active screen's [MortAtmosphereProfile] -- never a fixed-interval
/// metronome, and never more than the profile's simultaneous cap.
class MortMeteorScheduler {
  MortMeteorScheduler({required Size size, int seed = 7})
    : _size = size,
      _random = math.Random(seed);

  final Size _size;
  final math.Random _random;
  final List<MortMeteor> _active = <MortMeteor>[];
  Duration _nextSpawnAt = Duration.zero;
  Duration _silenceUntil = Duration.zero;
  bool _seeded = false;

  List<MortMeteor> get active => _active;

  void tick(Duration now, MortAtmosphereProfile profile) {
    _active.removeWhere((m) => m.progressAt(now) > 1.05);

    if (!_seeded) {
      _nextSpawnAt = profile.starfallBurst
          ? now + const Duration(milliseconds: 250)
          : _scheduledTime(now, profile);
      _seeded = true;
      return;
    }

    if (profile.starfallBurst) {
      if (now < _silenceUntil || now < _nextSpawnAt) return;
      _spawnStarfallBurst(now, profile);
      return;
    }

    if (now >= _nextSpawnAt && _active.length < profile.simultaneousCap) {
      _spawnCluster(now, profile);
      _nextSpawnAt = _scheduledTime(now, profile);
    }
  }

  Duration _scheduledTime(Duration now, MortAtmosphereProfile profile) {
    final minMs = profile.meteorMinInterval.inMilliseconds;
    final maxMs = profile.meteorMaxInterval.inMilliseconds;
    final span = math.max(1, maxMs - minMs);
    final delay = minMs + _random.nextInt(span);
    return now + Duration(milliseconds: delay);
  }

  void _spawnStarfallBurst(Duration now, MortAtmosphereProfile profile) {
    final available = profile.simultaneousCap - _active.length;
    final burstSize = math.min(available, 3 + _random.nextInt(4));
    var latestSpawn = now;
    for (var index = 0; index < burstSize; index++) {
      final delay = index == 0 ? 0 : 90 * index + _random.nextInt(130);
      final spawnAt = now + Duration(milliseconds: delay);
      latestSpawn = spawnAt > latestSpawn ? spawnAt : latestSpawn;
      _active.add(_buildMeteor(spawnAt));
    }
    final silence = Duration(milliseconds: 4000 + _random.nextInt(4001));
    _silenceUntil = latestSpawn + silence;
    _nextSpawnAt = _silenceUntil;
  }

  void _spawnCluster(Duration now, MortAtmosphereProfile profile) {
    final clusterRoll = _random.nextDouble();
    final clusterSize = clusterRoll < profile.meteorClusterChance
        ? 2 +
              _random.nextInt(2) // 2-3
        : 1;
    for (var i = 0; i < clusterSize; i++) {
      if (_active.length >= profile.simultaneousCap) break;
      final intraDelay = i == 0 ? 0 : 250 + _random.nextInt(350);
      _active.add(_buildMeteor(now + Duration(milliseconds: intraDelay)));
    }
  }

  MortMeteor _buildMeteor(Duration spawnedAt) {
    final angleDeg =
        MortAtmosphereTuning.meteorAngleDegrees +
        (_random.nextDouble() * 2 - 1) *
            MortAtmosphereTuning.meteorAngleJitterDegrees;
    final angleRad = angleDeg * math.pi / 180;
    final length =
        MortAtmosphereTuning.meteorMinLength +
        _random.nextDouble() *
            (MortAtmosphereTuning.meteorMaxLength -
                MortAtmosphereTuning.meteorMinLength);
    final durationMs =
        MortAtmosphereTuning.meteorMinDuration.inMilliseconds +
        _random.nextInt(
          MortAtmosphereTuning.meteorMaxDuration.inMilliseconds -
              MortAtmosphereTuning.meteorMinDuration.inMilliseconds,
        );
    final startX = _random.nextDouble() * _size.width;
    final startY = _random.nextDouble() * _size.height * 0.5;
    return MortMeteor(
      start: Offset(startX, startY),
      angleRadians: angleRad,
      length: length,
      spawnedAt: spawnedAt,
      duration: Duration(milliseconds: durationMs),
      behindForeground:
          _random.nextDouble() < MortAtmosphereTuning.meteorBackgroundFraction,
    );
  }
}
