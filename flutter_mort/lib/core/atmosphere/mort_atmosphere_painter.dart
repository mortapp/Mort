import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'mort_atmosphere_scene.dart';
import 'mort_atmosphere_tuning.dart';
import 'mort_atmosphere_composition.dart';
import 'mort_cloud_shader.dart';
import 'mort_meteor_scheduler.dart';
import 'mort_scene_clock.dart';
import 'mort_shimmer_scheduler.dart';

/// Renders one frame of the MORT midnight/cobalt atmosphere: sky, dither,
/// stars, clouds, aurora, and meteors, in that back-to-front order (with
/// ~40% of meteors deliberately rendered behind the cloud/wordmark layer
/// per the composition spec). Pure `paint()` -- no side effects, no
/// per-frame allocation of the scene itself (only small per-frame
/// transforms), safe to wrap in RepaintBoundary.
class MortAtmospherePainter extends CustomPainter {
  MortAtmospherePainter({
    required this.scene,
    this.elapsed,
    this.sceneClock,
    required this.profile,
    this.meteors = const [],
    this.meteorScheduler,
    required this.reducedMotion,
    this.shimmer,
    this.shimmerScheduler,
    this.cloudShader,
    this.lowComplexityShader = false,
    this.phase = MortAtmospherePaintPhase.full,
    this.atmosphereLift = MortAtmosphereTuning.atmosphereLift,
    this.cloudExposure = 1,
    this.dropC1Cloud = false,
  }) : assert(elapsed != null || sceneClock != null),
       super(repaint: sceneClock);

  final MortAtmosphereScene scene;
  final Duration? elapsed;
  final MortSceneClock? sceneClock;
  final MortAtmosphereProfile profile;
  final List<MortMeteor> meteors;
  final MortMeteorScheduler? meteorScheduler;
  final bool reducedMotion;
  final MortAtmosphereShimmer? shimmer;
  final MortAtmosphereShimmerScheduler? shimmerScheduler;
  final MortCloudShaderController? cloudShader;
  final bool lowComplexityShader;
  final MortAtmospherePaintPhase phase;
  final double atmosphereLift;
  final double cloudExposure;

  /// Low-end fallback step 2: drop the nearest, most expensive cloud
  /// layer (C1) while keeping sky/dither/stars intact.
  final bool dropC1Cloud;

  Duration get _elapsed => sceneClock?.elapsed ?? elapsed!;
  List<MortMeteor> get _activeMeteors => meteorScheduler?.active ?? meteors;
  MortAtmosphereShimmer? get _activeShimmer =>
      shimmerScheduler?.active ?? shimmer;
  double get _t => reducedMotion ? 0 : _elapsed.inMicroseconds / 1e6;

  @override
  void paint(Canvas canvas, Size size) {
    if (phase != MortAtmospherePaintPhase.foreground) {
      _paintSky(canvas, size);
      _paintCenterGlow(canvas, size);
      _paintDither(canvas);
      _paintStars(canvas);
      if (profile.auroraEnabled) _paintAurora(canvas, size);
      _paintClouds(canvas, size, start: 0, end: 1);
      if (!reducedMotion) _paintMeteors(canvas, behind: true);
      _paintClouds(canvas, size, start: 1, end: 3);
    }
    if (phase != MortAtmospherePaintPhase.background) {
      if (!reducedMotion) _paintMeteors(canvas, behind: false);
      _paintClouds(canvas, size, start: 3, end: 4);
      if (!reducedMotion && _activeShimmer != null) {
        _paintShimmer(canvas, size);
      }
      _paintVignette(canvas, size);
    }
  }

  void _paintSky(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          MortAtmosphereTuning.skyTop,
          MortAtmosphereTuning.skyUpperMid,
          MortAtmosphereTuning.skyLowerMid,
          MortAtmosphereTuning.skyBottom,
        ],
        stops: [0, 0.38, 0.72, 1],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  void _paintCenterGlow(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.42);
    final radius = size.longestSide * 0.62;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          MortAtmosphereTuning.centerGlowInnerColor(),
          MortAtmosphereTuning.centerGlowOuterColor(),
          Colors.transparent,
        ],
        stops: const [0, 0.55, 1],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  void _paintDither(Canvas canvas) {
    if (scene.ditherLightenPoints.isEmpty && scene.ditherDarkenPoints.isEmpty) {
      return;
    }
    final lightenPaint = Paint()
      ..color = Colors.white.withValues(
        alpha: MortAtmosphereTuning.ditherModulation,
      )
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    final darkenPaint = Paint()
      ..color = Colors.black.withValues(
        alpha: MortAtmosphereTuning.ditherModulation,
      )
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    canvas.drawRawPoints(
      ui.PointMode.points,
      scene.ditherLightenPoints,
      lightenPaint,
    );
    canvas.drawRawPoints(
      ui.PointMode.points,
      scene.ditherDarkenPoints,
      darkenPaint,
    );
  }

  void _paintStars(Canvas canvas) {
    final multiplier = profile.starOpacityMultiplier;
    for (final star in scene.stars) {
      final dx =
          (star.base.dx + star.driftPxPerSec * _t) % (scene.size.width + 40) -
          20;
      final position = Offset(dx, star.base.dy);
      var opacity = star.baseOpacity * multiplier;
      if (star.twinkles && !reducedMotion) {
        final wave = math.sin(_t * star.twinkleSpeed + star.twinklePhase);
        opacity *= 0.72 + 0.28 * ((wave + 1) / 2);
      }
      final paint = Paint()
        ..color = MortAtmosphereTuning.wordmarkPenCore.withValues(
          alpha: opacity.clamp(0.0, 1.0),
        );
      canvas.drawCircle(position, star.radius, paint);
      if (star.hasFlare && !reducedMotion) {
        final flareOpacity = (opacity * 0.5).clamp(0.0, 1.0);
        final flarePaint = Paint()
          ..color = Colors.white.withValues(alpha: flareOpacity)
          ..strokeWidth = 0.6;
        canvas.drawLine(
          position.translate(-star.radius * 3, 0),
          position.translate(star.radius * 3, 0),
          flarePaint,
        );
        canvas.drawLine(
          position.translate(0, -star.radius * 3),
          position.translate(0, star.radius * 3),
          flarePaint,
        );
      }
    }
  }

  void _paintClouds(
    Canvas canvas,
    Size size, {
    required int start,
    required int end,
  }) {
    final multiplier = profile.cloudOpacityMultiplier * cloudExposure;
    final shader = cloudShader;
    if (shader?.isReady == true) {
      for (var index = start; index < end; index++) {
        if (dropC1Cloud && index == 0) continue;
        shader!.paintLayer(
          canvas,
          size,
          layerIndex: index,
          spec: MortAtmosphereTuning.cloudLayers[index],
          elapsed: reducedMotion ? Duration.zero : _elapsed,
          opacityMultiplier: multiplier,
          lift: atmosphereLift,
          lowComplexity: lowComplexityShader,
        );
      }
      return;
    }
    for (var i = start; i < end; i++) {
      if (dropC1Cloud && i == 0) continue;
      final layer = scene.clouds[i];
      final direction = layer.spec.driftRight ? 1 : -1;
      final dx = direction * layer.spec.driftPxPerSec * _t;
      final hueShift = layer.spec.hueShiftDegrees;
      final baseColor = HSLColor.fromColor(
        const Color(0xFF0D1118), // graphite-black mass, buried night interior
      ).withHue((222 + hueShift) % 360).toColor();
      for (final mass in layer.masses) {
        final wrappedDx =
            ((dx % (size.width * 1.4)) + size.width * 1.4) %
                (size.width * 1.4) -
            size.width * 0.2;
        final translated = mass.path.shift(Offset(wrappedDx, 0));
        final paint = Paint()
          ..color = baseColor.withValues(
            alpha: (layer.spec.peakAlpha * multiplier).clamp(0.0, 1.0),
          )
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, layer.spec.softness)
          ..style = PaintingStyle.fill;
        canvas.drawPath(translated, paint);

        // Rim light: a soft stroke along the upper portion of the mass
        // only (faint moonlight catching the top edge, not a blue outline
        // around the whole shape).
        final bounds = translated.getBounds();
        canvas.save();
        canvas.clipRect(
          Rect.fromLTRB(
            bounds.left,
            bounds.top,
            bounds.right,
            bounds.top + bounds.height * 0.42,
          ),
        );
        final rimPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
          ..shader = LinearGradient(
            colors: [
              MortAtmosphereTuning.cloudRimLightStart(),
              MortAtmosphereTuning.cloudRimLightEnd(),
            ],
          ).createShader(bounds);
        canvas.drawPath(translated, rimPaint);
        canvas.restore();
      }
    }
  }

  void _paintAurora(Canvas canvas, Size size) {
    if (reducedMotion) return;
    for (var band = 0; band < 2; band++) {
      final driftSpeed = band == 0
          ? MortAtmosphereTuning.auroraDriftPxPerSecA
          : MortAtmosphereTuning.auroraDriftPxPerSecB;
      final breathe = math.sin(
        (_t / MortAtmosphereTuning.auroraBreatheDuration.inSeconds) *
                math.pi *
                2 +
            band,
      );
      final dy =
          size.height * (0.22 + band * 0.18) +
          breathe * MortAtmosphereTuning.auroraVerticalBreathePx;
      final dx = driftSpeed * _t;
      final opacity =
          MortAtmosphereTuning.auroraMinOpacity +
          (MortAtmosphereTuning.auroraMaxOpacity -
                  MortAtmosphereTuning.auroraMinOpacity) *
              ((breathe + 1) / 2);
      final rect = Rect.fromLTWH(
        -size.width * 0.3 + (dx % size.width),
        dy,
        size.width * 1.6,
        size.height * 0.14,
      );
      final paint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            const Color(0xFFD6DAE0).withValues(alpha: opacity), // silver sweep
            Colors.transparent,
          ],
        ).createShader(rect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);
      canvas.drawRect(rect, paint);
    }
  }

  void _paintShimmer(Canvas canvas, Size size) {
    final s = _activeShimmer;
    if (s == null) return;
    final t = s.progressAt(_elapsed);
    if (t < 0 || t > 1) return;

    // Rises and falls smoothly across the sweep instead of snapping in/out.
    final opacity =
        math.sin(t * math.pi) * MortAtmosphereTuning.shimmerPeakOpacity;
    if (opacity <= 0) return;

    final travel =
        size.width + size.height * 0.6 + MortAtmosphereTuning.shimmerWidth * 2;
    final dx = -MortAtmosphereTuning.shimmerWidth + t * travel;
    final angle = MortAtmosphereTuning.shimmerAngleDegrees * math.pi / 180;
    final rect = Rect.fromLTWH(
      -MortAtmosphereTuning.shimmerWidth,
      -size.height * 0.5,
      MortAtmosphereTuning.shimmerWidth,
      size.height * 2,
    );

    canvas.save();
    canvas.translate(dx, size.height * 0.5);
    canvas.rotate(angle);
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: opacity),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
    canvas.restore();
  }

  void _paintMeteors(Canvas canvas, {required bool behind}) {
    for (final meteor in _activeMeteors) {
      if (meteor.behindForeground != behind) continue;
      final t = meteor.progressAt(_elapsed);
      if (t < 0 || t > 1) continue;
      final opacity = meteor.opacityAt(t);
      if (opacity <= 0) continue;

      final travel = meteor.length * t * 1.3;
      final direction = Offset(
        math.cos(meteor.angleRadians),
        math.sin(meteor.angleRadians),
      );
      final head = meteor.start + direction * travel;
      final tail = head - direction * meteor.length;

      final trailPaint = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth =
            MortAtmosphereTuning.meteorTrailMinWidth +
            (MortAtmosphereTuning.meteorTrailMaxWidth -
                    MortAtmosphereTuning.meteorTrailMinWidth) *
                0.6
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0x000C2140), // transparent midnight depth
            Color(0x330C2140).withValues(alpha: 0.20 * opacity),
            Color(0x9ACDD5DE).withValues(alpha: 0.60 * opacity), // silver
            Color(0xFFF2F5F8).withValues(alpha: opacity), // ice
          ],
          stops: const [0, 0.5, 0.85, 1],
        ).createShader(Rect.fromPoints(tail, head));
      canvas.drawLine(tail, head, trailPaint);

      final headPaint = Paint()
        ..color = MortAtmosphereTuning.meteorHeadColor.withValues(
          alpha: opacity,
        );
      canvas.drawCircle(
        head,
        MortAtmosphereTuning.meteorHeadMinRadius +
            (MortAtmosphereTuning.meteorHeadMaxRadius -
                    MortAtmosphereTuning.meteorHeadMinRadius) *
                0.5,
        headPaint,
      );
    }
  }

  void _paintVignette(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.1,
        colors: [
          Colors.transparent,
          MortAtmosphereTuning.vignetteMid(),
          MortAtmosphereTuning.vignetteEdge(),
        ],
        stops: const [0.5, 0.8, 1],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant MortAtmospherePainter oldDelegate) {
    return oldDelegate.elapsed != elapsed ||
        !identical(oldDelegate.sceneClock, sceneClock) ||
        oldDelegate.profile != profile ||
        oldDelegate.reducedMotion != reducedMotion ||
        oldDelegate.dropC1Cloud != dropC1Cloud ||
        oldDelegate.shimmer != shimmer ||
        !identical(oldDelegate.cloudShader, cloudShader) ||
        oldDelegate.lowComplexityShader != lowComplexityShader ||
        oldDelegate.phase != phase ||
        oldDelegate.atmosphereLift != atmosphereLift ||
        oldDelegate.cloudExposure != cloudExposure ||
        !identical(oldDelegate.shimmerScheduler, shimmerScheduler) ||
        !identical(oldDelegate.meteorScheduler, meteorScheduler) ||
        !identical(oldDelegate.meteors, meteors);
  }
}
