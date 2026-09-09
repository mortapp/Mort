import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/mort_colors.dart';

/// The canonical low-density, deterministic space atmosphere for MORT.
///
/// Decorative geometry is generated once per painter from [seed], painted in
/// one layer, and never animated. That keeps reduced-motion behavior static by
/// construction and avoids a widget or ticker per star.
class MortSpaceBackground extends StatefulWidget {
  const MortSpaceBackground({
    super.key,
    required this.child,
    this.seed = 20260908,
  });

  final Widget child;
  final int seed;

  @override
  State<MortSpaceBackground> createState() => _MortSpaceBackgroundState();
}

class _MortSpaceBackgroundState extends State<MortSpaceBackground> {
  late MortSpacePainter _painter;

  @override
  void initState() {
    super.initState();
    _painter = MortSpacePainter(seed: widget.seed);
  }

  @override
  void didUpdateWidget(covariant MortSpaceBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seed != widget.seed) {
      _painter = MortSpacePainter(seed: widget.seed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: RepaintBoundary(child: CustomPaint(painter: _painter)),
        ),
        Material(type: MaterialType.transparency, child: widget.child),
      ],
    );
  }
}

@visibleForTesting
class MortSpacePainter extends CustomPainter {
  MortSpacePainter({required this.seed})
    : _stars = _buildStars(seed),
      _constellations = _buildConstellations(seed);

  final int seed;
  final List<_MortStar> _stars;
  final List<List<Offset>> _constellations;

  static const _background = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [MortColors.bg, MortColors.black, MortColors.softBlack],
    stops: [0, 0.7, 1],
  );

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(bounds, Paint()..shader = _background.createShader(bounds));

    final constellationPaint = Paint()
      ..color = MortColors.silverDark.withValues(alpha: 0.1)
      ..strokeWidth = 0.65
      ..style = PaintingStyle.stroke;
    for (final constellation in _constellations) {
      final path = Path();
      for (var index = 0; index < constellation.length; index++) {
        final point = _scale(constellation[index], size);
        if (index == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(path, constellationPaint);
    }

    final starPaint = Paint()..style = PaintingStyle.fill;
    for (final star in _stars) {
      starPaint.color =
          (star.coolBlue ? MortColors.lightBlue : MortColors.white).withValues(
            alpha: star.opacity,
          );
      canvas.drawCircle(_scale(star.position, size), star.radius, starPaint);
    }
  }

  @override
  bool shouldRepaint(covariant MortSpacePainter oldDelegate) =>
      oldDelegate.seed != seed;

  @override
  bool shouldRebuildSemantics(covariant MortSpacePainter oldDelegate) => false;

  static Offset _scale(Offset normalized, Size size) =>
      Offset(normalized.dx * size.width, normalized.dy * size.height);

  static List<_MortStar> _buildStars(int seed) {
    final random = math.Random(seed);
    return List<_MortStar>.unmodifiable(
      List.generate(44, (index) {
        return _MortStar(
          position: Offset(random.nextDouble(), random.nextDouble()),
          radius: 0.45 + random.nextDouble() * 0.75,
          opacity: 0.16 + random.nextDouble() * 0.34,
          coolBlue: index % 19 == 0,
        );
      }),
    );
  }

  static List<List<Offset>> _buildConstellations(int seed) {
    final random = math.Random(seed ^ 0x4d4f5254);
    return List<List<Offset>>.unmodifiable(
      List.generate(2, (_) {
        final origin = Offset(
          0.12 + random.nextDouble() * 0.66,
          0.12 + random.nextDouble() * 0.66,
        );
        return List<Offset>.unmodifiable(
          List.generate(3, (index) {
            final x = (origin.dx + index * 0.045 + random.nextDouble() * 0.025)
                .clamp(0.04, 0.96);
            final y = (origin.dy + random.nextDouble() * 0.07 - 0.035).clamp(
              0.04,
              0.96,
            );
            return Offset(x, y);
          }),
        );
      }),
    );
  }
}

class _MortStar {
  const _MortStar({
    required this.position,
    required this.radius,
    required this.opacity,
    required this.coolBlue,
  });

  final Offset position;
  final double radius;
  final double opacity;
  final bool coolBlue;
}
