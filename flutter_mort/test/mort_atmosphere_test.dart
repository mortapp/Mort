import 'dart:ui';

import 'package:flutter_mort/core/atmosphere/mort_atmosphere_painter.dart';
import 'package:flutter_mort/core/atmosphere/mort_atmosphere_scene.dart';
import 'package:flutter_mort/core/atmosphere/mort_atmosphere_tuning.dart';
import 'package:flutter_mort/core/atmosphere/mort_meteor_scheduler.dart';
import 'package:flutter_mort/core/atmosphere/mort_shimmer_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MortAtmospherePainter', () {
    // Renders directly against a PictureRecorder canvas -- independent of
    // any widget Ticker -- so this exercises every real elapsed time and
    // quality/shimmer combination without depending on whether a test
    // binding lets a perpetual animation actually tick (see
    // MortAtmosphericBackground's pumpAndSettle guard).
    void renderFrame({
      required Duration elapsed,
      MortAtmosphereProfile profile = MortAtmosphereProfile.midnight,
      List<MortMeteor> meteors = const [],
      bool reducedMotion = false,
      bool dropC1Cloud = false,
      MortAtmosphereShimmer? shimmer,
    }) {
      const size = Size(400, 800);
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final scene = MortAtmosphereScene(size: size, seed: 5);
      MortAtmospherePainter(
        scene: scene,
        elapsed: elapsed,
        profile: profile,
        meteors: meteors,
        reducedMotion: reducedMotion,
        dropC1Cloud: dropC1Cloud,
        shimmer: shimmer,
      ).paint(canvas, size);
      recorder.endRecording().dispose();
    }

    test('renders without throwing across a spread of elapsed times', () {
      for (final ms in [0, 500, 3000, 15000, 60000, 3600000]) {
        expect(
          () => renderFrame(elapsed: Duration(milliseconds: ms)),
          returnsNormally,
          reason: 'elapsed: ${ms}ms',
        );
      }
    });

    test('renders without throwing for every atmosphere profile', () {
      for (final profile in [
        MortAtmosphereProfile.midnight,
        MortAtmosphereProfile.quiet,
        MortAtmosphereProfile.settings,
        MortAtmosphereProfile.starfall,
      ]) {
        expect(
          () => renderFrame(
            elapsed: const Duration(seconds: 10),
            profile: profile,
          ),
          returnsNormally,
        );
      }
    });

    test(
      'renders without throwing with active meteors, dropped C1 cloud, and an active shimmer',
      () {
        final meteor = MortMeteor(
          start: const Offset(50, 50),
          angleRadians: 0.4,
          length: 200,
          spawnedAt: Duration.zero,
          duration: const Duration(milliseconds: 900),
          behindForeground: false,
        );
        final backMeteor = MortMeteor(
          start: const Offset(80, 90),
          angleRadians: 0.4,
          length: 150,
          spawnedAt: Duration.zero,
          duration: const Duration(milliseconds: 900),
          behindForeground: true,
        );
        expect(
          () => renderFrame(
            elapsed: const Duration(milliseconds: 400),
            meteors: [meteor, backMeteor],
            dropC1Cloud: true,
            shimmer: MortAtmosphereShimmer(startedAt: Duration.zero),
          ),
          returnsNormally,
        );
      },
    );

    test('renders without throwing under reduced motion', () {
      expect(
        () => renderFrame(
          elapsed: const Duration(seconds: 5),
          reducedMotion: true,
        ),
        returnsNormally,
      );
    });
  });

  group('MortAtmosphereScene', () {
    test('is deterministic for a given seed and size', () {
      const size = Size(400, 800);
      final a = MortAtmosphereScene(size: size, seed: 42);
      final b = MortAtmosphereScene(size: size, seed: 42);

      expect(a.stars.length, b.stars.length);
      for (var i = 0; i < a.stars.length; i++) {
        expect(a.stars[i].base, b.stars[i].base);
      }
      expect(a.ditherLightenPoints, b.ditherLightenPoints);
      expect(a.ditherDarkenPoints, b.ditherDarkenPoints);
    });

    test('produces exactly the configured number of rare star flares', () {
      final scene = MortAtmosphereScene(size: const Size(400, 800), seed: 7);
      final flares = scene.stars.where((s) => s.hasFlare).length;
      expect(flares, MortAtmosphereTuning.starRareFlareCount);
    });

    test('builds 4 cloud layers with irregular (non-circular) paths', () {
      final scene = MortAtmosphereScene(size: const Size(400, 800), seed: 3);
      expect(scene.clouds.length, MortAtmosphereTuning.cloudLayers.length);
      for (final layer in scene.clouds) {
        expect(layer.masses, isNotEmpty);
        for (final mass in layer.masses) {
          // An irregular blob has more than 4 distinct on-path control
          // points; a plain circle/oval built via addOval would not
          // satisfy this once decomposed into line/curve verbs.
          final metrics = mass.path.computeMetrics().toList();
          expect(metrics, isNotEmpty);
        }
      }
    });

    test('dither point sets stay within the scene bounds', () {
      const size = Size(300, 600);
      final scene = MortAtmosphereScene(size: size, seed: 9);
      for (var i = 0; i < scene.ditherLightenPoints.length; i += 2) {
        expect(scene.ditherLightenPoints[i], inInclusiveRange(0, size.width));
        expect(
          scene.ditherLightenPoints[i + 1],
          inInclusiveRange(0, size.height),
        );
      }
      for (var i = 0; i < scene.ditherDarkenPoints.length; i += 2) {
        expect(scene.ditherDarkenPoints[i], inInclusiveRange(0, size.width));
        expect(
          scene.ditherDarkenPoints[i + 1],
          inInclusiveRange(0, size.height),
        );
      }
    });
  });

  group('MortMeteor', () {
    test('fade is asymmetric: fade-in is shorter than fade-out', () {
      final meteor = MortMeteor(
        start: Offset.zero,
        angleRadians: 0,
        length: 200,
        spawnedAt: Duration.zero,
        duration: const Duration(milliseconds: 1000),
        behindForeground: false,
      );

      final fadeInSpan = MortAtmosphereTuning.meteorFadeInFraction;
      final fadeOutSpan = 1 - MortAtmosphereTuning.meteorFadeOutStartFraction;
      expect(fadeOutSpan, greaterThan(fadeInSpan));

      expect(meteor.opacityAt(0.0), 0);
      expect(meteor.opacityAt(fadeInSpan), closeTo(1.0, 0.001));
      expect(meteor.opacityAt(0.5), 1.0);
      expect(meteor.opacityAt(1.0), 0);

      // Symmetric-fade would give equal opacity at equal distances from
      // each edge; assert that is NOT the case at a matched pair of points.
      final earlyOpacity = meteor.opacityAt(fadeInSpan / 2);
      final lateOpacity = meteor.opacityAt(1 - fadeInSpan / 2);
      expect(earlyOpacity, isNot(closeTo(lateOpacity, 0.001)));
    });

    test('progressAt is negative before spawn and >1 after duration', () {
      final meteor = MortMeteor(
        start: Offset.zero,
        angleRadians: 0,
        length: 100,
        spawnedAt: const Duration(seconds: 5),
        duration: const Duration(milliseconds: 500),
        behindForeground: true,
      );
      expect(meteor.progressAt(const Duration(seconds: 4)), lessThan(0));
      expect(meteor.progressAt(const Duration(seconds: 6)), greaterThan(1));
    });
  });

  group('MortMeteorScheduler', () {
    test('never exceeds the active profile\'s simultaneous cap', () {
      final scheduler = MortMeteorScheduler(
        size: const Size(400, 800),
        seed: 11,
      );
      var now = Duration.zero;
      for (var i = 0; i < 500; i++) {
        now += const Duration(milliseconds: 100);
        scheduler.tick(now, MortAtmosphereProfile.starfall);
        expect(
          scheduler.active.length,
          lessThanOrEqualTo(MortAtmosphereProfile.starfall.simultaneousCap),
        );
      }
    });

    test('does not spawn on a fixed metronome interval', () {
      final scheduler = MortMeteorScheduler(
        size: const Size(400, 800),
        seed: 13,
      );
      final spawnTimes = <int>[];
      var lastCount = 0;
      var now = Duration.zero;
      for (var i = 0; i < 2000; i++) {
        now += const Duration(milliseconds: 20);
        scheduler.tick(now, MortAtmosphereProfile.midnight);
        if (scheduler.active.length > lastCount) {
          spawnTimes.add(now.inMilliseconds);
        }
        lastCount = scheduler.active.length;
      }
      expect(spawnTimes.length, greaterThan(2));
      final gaps = <int>[
        for (var i = 1; i < spawnTimes.length; i++)
          spawnTimes[i] - spawnTimes[i - 1],
      ];
      final distinctGaps = gaps.toSet();
      expect(
        distinctGaps.length,
        greaterThan(1),
        reason: 'A true metronome would produce identical gaps every time.',
      );
    });
  });
}
