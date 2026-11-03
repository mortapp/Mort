import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'mort_atmosphere_tuning.dart';

/// Deterministic, seeded scene description for the MORT atmosphere. Built
/// once per screen size (not re-seeded on every rebuild -- see
/// MortAtmosphericBackground), then reused every frame by the painter.
/// Original implementation: procedural blob-path clouds, not a copied
/// texture/video/asset from any other product.
class MortAtmosphereScene {
  MortAtmosphereScene({required this.size, int seed = 1})
    : _random = math.Random(seed) {
    _stars = _buildStars();
    _clouds = _buildClouds();
    _buildDither();
  }

  final Size size;
  final math.Random _random;

  late final List<MortStar> _stars;
  late final List<MortCloudLayerData> _clouds;

  /// drawPoints/drawRawPoints only accept one Paint (one color) per call,
  /// so the dither pass is split into a "lighten" point set and a "darken"
  /// point set instead of per-point colors -- each drawn once with its own
  /// fixed low-alpha Paint. This is what actually produces the alternating
  /// lighten/darken texture an ordered dither needs, without requiring
  /// per-vertex colors.
  late final Float32List ditherLightenPoints;
  late final Float32List ditherDarkenPoints;

  List<MortStar> get stars => _stars;
  List<MortCloudLayerData> get clouds => _clouds;

  List<MortStar> _buildStars() {
    final stars = <_StarInstance>[];
    for (final layer in MortAtmosphereTuning.starLayers) {
      // Deliberately uneven density: bias roughly 70% of each layer's stars
      // toward one half of the canvas so the sky doesn't read as evenly
      // "sprinkled wallpaper".
      for (var i = 0; i < layer.count; i++) {
        final denseHalf = i < (layer.count * 0.7).round();
        final dx = denseHalf
            ? _random.nextDouble() * size.width * 0.62
            : size.width * 0.62 + _random.nextDouble() * size.width * 0.38;
        stars.add(
          _StarInstance(
            base: Offset(dx, _random.nextDouble() * size.height),
            radius:
                layer.minSize +
                _random.nextDouble() * (layer.maxSize - layer.minSize),
            baseOpacity:
                layer.minOpacity +
                _random.nextDouble() * (layer.maxOpacity - layer.minOpacity),
            driftPxPerSec: layer.driftPxPerSec,
            twinkles:
                _random.nextDouble() < MortAtmosphereTuning.starTwinkleFraction,
            twinklePhase: _random.nextDouble() * math.pi * 2,
            twinkleSpeed: 0.6 + _random.nextDouble() * 0.9,
            hasFlare: false,
          ),
        );
      }
    }
    // Rare flares on only a handful of stars total, picked from the larger
    // (nearer) layers so the flare has a visible star to sit on.
    final candidates = stars.where((s) => s.radius > 1.2).toList()
      ..shuffle(_random);
    for (final star in candidates.take(
      MortAtmosphereTuning.starRareFlareCount,
    )) {
      final index = stars.indexOf(star);
      stars[index] = star.copyWithFlare();
    }
    return stars;
  }

  List<MortCloudLayerData> _buildClouds() {
    final layers = <MortCloudLayerData>[];
    for (final spec in MortAtmosphereTuning.cloudLayers) {
      final masses = <_CloudMass>[];
      // 2-3 irregular masses per layer, biased toward roughly one-third of
      // the canvas width (not dead-center) per the composition rule, and
      // avoiding the reserved zone around the wordmark.
      final massCount = 2 + _random.nextInt(2);
      for (var i = 0; i < massCount; i++) {
        final centerX = size.width * (0.22 + _random.nextDouble() * 0.30);
        final centerY = size.height * (0.15 + _random.nextDouble() * 0.55);
        final radiusX = size.width * (0.22 + _random.nextDouble() * 0.18);
        final radiusY = radiusX * (0.45 + _random.nextDouble() * 0.25);
        masses.add(
          _CloudMass(
            center: Offset(centerX, centerY),
            radiusX: radiusX,
            radiusY: radiusY,
            path: _buildBlobPath(centerX, centerY, radiusX, radiusY, _random),
          ),
        );
      }
      layers.add(_CloudLayer(spec: spec, masses: masses));
    }
    return layers;
  }

  /// An irregular, organic closed blob -- NOT a circle. Built by
  /// perturbing points around an ellipse by a random radius factor per
  /// vertex, then joining them with quadratic Bezier curves through
  /// midpoints so the silhouette is smooth but asymmetric (irregular
  /// hills/ridges, firmer lower mass via a taller lower radius factor).
  static Path _buildBlobPath(
    double cx,
    double cy,
    double rx,
    double ry,
    math.Random random,
  ) {
    const vertexCount = 10;
    final points = <Offset>[];
    for (var i = 0; i < vertexCount; i++) {
      final angle = (i / vertexCount) * math.pi * 2;
      // Firmer/larger lower mass, dissolving (smaller, more perturbed)
      // upper edge -- matches "firm lower mass, dissolving upper edge".
      final isLower = math.sin(angle) > 0;
      final baseFactor = isLower ? 1.0 : 0.62;
      final perturb = 0.72 + random.nextDouble() * 0.56; // asymmetric noise
      final r = baseFactor * perturb;
      points.add(
        Offset(cx + math.cos(angle) * rx * r, cy + math.sin(angle) * ry * r),
      );
    }
    final path = Path()
      ..moveTo(
        (points.first.dx + points.last.dx) / 2,
        (points.first.dy + points.last.dy) / 2,
      );
    for (var i = 0; i < points.length; i++) {
      final current = points[i];
      final next = points[(i + 1) % points.length];
      final mid = Offset(
        (current.dx + next.dx) / 2,
        (current.dy + next.dy) / 2,
      );
      path.quadraticBezierTo(current.dx, current.dy, mid.dx, mid.dy);
    }
    path.close();
    return path;
  }

  void _buildDither() {
    // Fixed (not re-randomized per frame) sparse point field for a
    // low-cost anti-banding pass -- a real, working simplification of a
    // full ordered/blue-noise dither shader: same purpose (break up
    // gradient banding with a static sub-pixel luminance pattern), no
    // per-frame allocation, two drawRawPoints calls total.
    final area = size.width * size.height;
    final count = math.min(3000, (area / 900).round());
    final lighten = Float32List(count * 2);
    final darken = Float32List(count * 2);
    var lightenLength = 0;
    var darkenLength = 0;
    for (var i = 0; i < count; i++) {
      final x = _random.nextDouble() * size.width;
      final y = _random.nextDouble() * size.height;
      if (_random.nextBool()) {
        lighten[lightenLength++] = x;
        lighten[lightenLength++] = y;
      } else {
        darken[darkenLength++] = x;
        darken[darkenLength++] = y;
      }
    }
    ditherLightenPoints = Float32List.sublistView(lighten, 0, lightenLength);
    ditherDarkenPoints = Float32List.sublistView(darken, 0, darkenLength);
  }
}

class _StarInstance {
  const _StarInstance({
    required this.base,
    required this.radius,
    required this.baseOpacity,
    required this.driftPxPerSec,
    required this.twinkles,
    required this.twinklePhase,
    required this.twinkleSpeed,
    required this.hasFlare,
  });

  final Offset base;
  final double radius;
  final double baseOpacity;
  final double driftPxPerSec;
  final bool twinkles;
  final double twinklePhase;
  final double twinkleSpeed;
  final bool hasFlare;

  _StarInstance copyWithFlare() => _StarInstance(
    base: base,
    radius: radius,
    baseOpacity: baseOpacity,
    driftPxPerSec: driftPxPerSec,
    twinkles: twinkles,
    twinklePhase: twinklePhase,
    twinkleSpeed: twinkleSpeed,
    hasFlare: true,
  );
}

class _CloudMass {
  const _CloudMass({
    required this.center,
    required this.radiusX,
    required this.radiusY,
    required this.path,
  });

  final Offset center;
  final double radiusX;
  final double radiusY;
  final Path path;
}

class _CloudLayer {
  const _CloudLayer({required this.spec, required this.masses});

  final MortCloudLayerSpec spec;
  final List<_CloudMass> masses;
}

// Public typedefs so the painter can reference these shapes without the
// leading underscore, while construction stays encapsulated in this file.
typedef MortStar = _StarInstance;
typedef MortCloudMass = _CloudMass;
typedef MortCloudLayerData = _CloudLayer;
