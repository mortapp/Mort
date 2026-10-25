import 'dart:ui';

import 'package:flutter_mort/core/atmosphere/mort_atmosphere_composition.dart';
import 'package:flutter_mort/core/atmosphere/mort_atmosphere_tuning.dart';
import 'package:flutter_mort/core/atmosphere/mort_meteor_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production composition puts MORT between real meteor planes', () {
    expect(MortAtmosphereLayer.productionOrder, const [
      MortAtmosphereLayer.sky,
      MortAtmosphereLayer.farStars,
      MortAtmosphereLayer.aurora,
      MortAtmosphereLayer.farClouds,
      MortAtmosphereLayer.backgroundMeteors,
      MortAtmosphereLayer.middleClouds,
      MortAtmosphereLayer.focalBrand,
      MortAtmosphereLayer.foregroundMeteors,
      MortAtmosphereLayer.nearClouds,
      MortAtmosphereLayer.shimmer,
      MortAtmosphereLayer.vignette,
      MortAtmosphereLayer.realUi,
    ]);
  });

  test('starfall bursts are followed by at least four seconds of silence', () {
    final scheduler = MortMeteorScheduler(size: const Size(400, 800), seed: 29);
    final seen = <MortMeteor>{};
    var now = Duration.zero;
    for (var i = 0; i < 600; i++) {
      now += const Duration(milliseconds: 50);
      scheduler.tick(now, MortAtmosphereProfile.starfall);
      seen.addAll(scheduler.active);
    }
    final spawnTimes = seen.map((meteor) => meteor.spawnedAt).toList()..sort();
    expect(spawnTimes.length, greaterThanOrEqualTo(6));
    final gaps = <Duration>[
      for (var i = 1; i < spawnTimes.length; i++)
        spawnTimes[i] - spawnTimes[i - 1],
    ];
    expect(
      gaps.any((gap) => gap >= const Duration(seconds: 4)),
      isTrue,
      reason: 'A starfall burst must be followed by 4–8 seconds of silence.',
    );
  });

  test('starfall never exceeds the seven-meteor hard cap', () {
    final scheduler = MortMeteorScheduler(size: const Size(400, 800), seed: 31);
    var now = Duration.zero;
    for (var i = 0; i < 800; i++) {
      now += const Duration(milliseconds: 40);
      scheduler.tick(now, MortAtmosphereProfile.starfall);
      expect(
        scheduler.active.length,
        lessThanOrEqualTo(MortAtmosphereTuning.meteorStarfallSimultaneousCap),
      );
    }
  });
}
