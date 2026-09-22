import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/mort_colors.dart';

/// MORT Guide mascots — original MORT vector designs rendered with
/// [CustomPainter] in the approved black/graphite/silver identity with
/// restrained deep-steel blue atmosphere and tiny icy highlights.
///
/// The mascots never copy another product, use emoji, or fall back to
/// placeholder circles: every state is drawn as vector paths.
enum MortMascotId {
  pip(
    displayName: 'Pip',
    animal: 'penguin',
    tagline: 'Steady, calm, and practical. Pip keeps the guide grounded.',
  ),
  mochi(
    displayName: 'Mochi',
    animal: 'kitten',
    tagline: 'Curious and gentle. Mochi asks the questions teens forget.',
  ),
  scout(
    displayName: 'Scout',
    animal: 'dog',
    tagline: 'Watchful and dependable. Scout points to the safe path.',
  );

  const MortMascotId({
    required this.displayName,
    required this.animal,
    required this.tagline,
  });

  final String displayName;
  final String animal;
  final String tagline;

  /// Stable storage token; unknown tokens fail closed to null.
  static MortMascotId? tryParse(String? value) {
    for (final mascot in MortMascotId.values) {
      if (mascot.name == value) return mascot;
    }
    return null;
  }
}

/// Visual states every mascot supports.
enum MortMascotState {
  idle('resting'),
  listening('listening'),
  thinking('thinking'),
  success('celebrating'),
  safetySerious('serious about safety');

  const MortMascotState(this.label);

  final String label;
}

/// Derives the mascot state for the MORT Guide conversation surface.
///
/// Pure function so every branch is testable. Safety escalation always wins:
/// the mascot never celebrates or plays while a safety message is on screen.
MortMascotState guideMascotStateFor({
  required bool safetyEscalation,
  required bool sending,
  required bool justAnswered,
  required bool composing,
}) {
  if (safetyEscalation) return MortMascotState.safetySerious;
  if (sending) return MortMascotState.thinking;
  if (justAnswered) return MortMascotState.success;
  if (composing) return MortMascotState.listening;
  return MortMascotState.idle;
}

/// Lifecycle-safe animated mascot view.
///
/// Animation is driven by one [AnimationController] that repaints only the
/// [CustomPaint] layer (no per-frame `setState`). Reduced motion freezes the
/// controller and renders the static pose; the safety-serious pose is always
/// static so urgent guidance never wiggles.
class MortMascotView extends StatefulWidget {
  const MortMascotView({
    super.key,
    required this.mascot,
    this.state = MortMascotState.idle,
    this.size = 96,
    this.reducedMotion,
    this.semanticLabel,
  });

  final MortMascotId mascot;
  final MortMascotState state;
  final double size;

  /// Force reduced motion for tests/embedded use; null defers to
  /// [MediaQueryData.disableAnimations].
  final bool? reducedMotion;

  /// Overrides the default semantics description.
  final String? semanticLabel;

  @override
  State<MortMascotView> createState() => MortMascotViewState();
}

class MortMascotViewState extends State<MortMascotView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );

  bool _motionAllowed = true;

  @override
  void initState() {
    super.initState();
    // Only explicit widget-level decisions are safe here; reading MediaQuery
    // must wait for didChangeDependencies.
    if (widget.state == MortMascotState.safetySerious) {
      _motionAllowed = false;
    } else if (widget.reducedMotion != null) {
      _motionAllowed = !widget.reducedMotion!;
    }
    if (_motionAllowed) _controller.repeat();
  }

  @override
  void didUpdateWidget(MortMascotView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  bool get _systemReducedMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  void _syncMotion() {
    final allowed = !(widget.reducedMotion ?? _systemReducedMotion);
    final shouldAnimate =
        allowed && widget.state != MortMascotState.safetySerious;
    if (shouldAnimate == _motionAllowed) return;
    _motionAllowed = shouldAnimate;
    if (shouldAnimate) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  /// True while the idle loop is animating (used by reduced-motion tests).
  bool get isAnimating => _controller.isAnimating;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _semanticDescription =>
      widget.semanticLabel ??
      '${widget.mascot.displayName} the ${widget.mascot.animal}, '
          'MORT Guide mascot, ${widget.state.label}';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _semanticDescription,
      image: true,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            size: Size.square(widget.size),
            painter: MortMascotPainter(
              mascot: widget.mascot,
              state: widget.state,
              phase: _motionAllowed ? _controller.value * 8 : 0,
            ),
          ),
        ),
      ),
    );
  }
}

/// Vector painter for the original MORT Guide mascots.
class MortMascotPainter extends CustomPainter {
  MortMascotPainter({
    required this.mascot,
    required this.state,
    required this.phase,
  });

  final MortMascotId mascot;
  final MortMascotState state;
  final double phase;

  static const _bodyBlack = MortColors.ink2;
  static const _bodyGraphite = MortColors.graphite3;
  static const _bellyWhite = MortColors.softWhite;
  static const _silver = MortColors.silver;
  static const _silverBright = MortColors.silverBright;
  static const _steelBlue = MortColors.night3;
  static const _steelBlueDeep = MortColors.night4;
  static const _icy = Color(0xFFEAF4FA);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 100;
    canvas.save();
    canvas.scale(scale);
    final motion = state == MortMascotState.safetySerious ? 0.0 : phase;

    _paintAura(canvas, motion);

    final bob = _bob(motion);
    final tilt = _tilt(motion);
    canvas.translate(50, 52 + bob);
    if (tilt != 0) canvas.rotate(tilt);
    canvas.translate(-50, -52);

    switch (mascot) {
      case MortMascotId.pip:
        _paintPip(canvas, motion);
      case MortMascotId.mochi:
        _paintMochi(canvas, motion);
      case MortMascotId.scout:
        _paintScout(canvas, motion);
    }
    canvas.restore();
  }

  // ---------------------------------------------------------------- aura ---

  void _paintAura(Canvas canvas, double motion) {
    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          _steelBlue.withValues(
            alpha: state == MortMascotState.safetySerious ? 0.55 : 0.34,
          ),
          _steelBlueDeep.withValues(alpha: 0.10),
          Colors.transparent,
        ],
        stops: const [0.0, 0.62, 1.0],
      ).createShader(Rect.fromCircle(center: const Offset(50, 52), radius: 50));
    canvas.drawCircle(const Offset(50, 52), 50, auraPaint);

    if (state == MortMascotState.safetySerious) {
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = _silverBright.withValues(alpha: 0.85);
      canvas.drawCircle(const Offset(50, 52), 45.5, ring);
      canvas.drawCircle(
        const Offset(50, 52),
        42,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = _steelBlue,
      );
      return;
    }
    if (state == MortMascotState.listening) {
      // Expanding sound arcs: the guide is paying attention.
      for (var i = 0; i < 2; i++) {
        final t = ((motion * 0.7 + i * 0.5) % 1.0);
        final arc = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = _silver.withValues(alpha: (1 - t) * 0.7);
        canvas.drawCircle(const Offset(50, 52), 34 + t * 14, arc);
      }
    }
  }

  double _bob(double motion) {
    switch (state) {
      case MortMascotState.idle:
        return _sin(motion * 1.2) * 1.4;
      case MortMascotState.listening:
        return _sin(motion * 1.6) * 1.0;
      case MortMascotState.thinking:
        return _sin(motion * 0.9) * 0.8;
      case MortMascotState.success:
        return -((_sin(motion * 2.4) + 1) * 1.8);
      case MortMascotState.safetySerious:
        return 0;
    }
  }

  double _tilt(double motion) {
    switch (state) {
      case MortMascotState.listening:
        return -0.05 + _sin(motion * 1.6) * 0.015;
      case MortMascotState.thinking:
        return 0.035;
      case MortMascotState.success:
        return _sin(motion * 2.4 + 0.6) * 0.03;
      case MortMascotState.idle:
      case MortMascotState.safetySerious:
        return 0;
    }
  }

  double _sin(double x) => math.sin(x);

  // -------------------------------------------------------------- shared ---

  void _paintEyes(
    Canvas canvas, {
    required Offset left,
    required Offset right,
    required double radius,
    required double motion,
    required double pupilShift,
    required Color sclera,
  }) {
    if (state == MortMascotState.success) {
      final happy = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.42
        ..strokeCap = StrokeCap.round
        ..color = sclera;
      canvas.drawArc(
        Rect.fromCircle(center: left, radius: radius),
        math.pi,
        math.pi,
        false,
        happy,
      );
      canvas.drawArc(
        Rect.fromCircle(center: right, radius: radius),
        math.pi,
        math.pi,
        false,
        happy,
      );
      return;
    }

    var openness = 1.0;
    switch (state) {
      case MortMascotState.thinking:
        openness = 0.5;
      case MortMascotState.safetySerious:
        openness = 0.85;
      case MortMascotState.idle:
        final blink = (motion % 5.0);
        if (blink > 4.72 && blink < 4.94) openness = 0.12;
      case MortMascotState.listening:
      case MortMascotState.success:
        openness = 1.0;
    }

    final scleraPaint = Paint()..color = sclera;
    final pupilPaint = Paint()..color = MortColors.void_;
    final glintPaint = Paint()..color = _icy;

    for (final center in [left, right]) {
      final rect = Rect.fromCenter(
        center: center,
        width: radius * 2,
        height: radius * 2 * openness,
      );
      canvas.drawOval(rect, scleraPaint);
      if (openness > 0.3) {
        final pupilCenter = center.translate(
          radius * pupilShift,
          radius * 0.12 * openness,
        );
        canvas.drawCircle(pupilCenter, radius * 0.42 * openness, pupilPaint);
        canvas.drawCircle(
          pupilCenter.translate(-radius * 0.14, -radius * 0.16),
          radius * 0.14 * openness,
          glintPaint,
        );
      }
    }

    if (state == MortMascotState.safetySerious) {
      final brow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.3
        ..strokeCap = StrokeCap.round
        ..color = MortColors.silverMid;
      canvas.drawLine(
        left.translate(-radius * 0.6, -radius * 1.3),
        left.translate(radius * 0.6, -radius * 1.15),
        brow,
      );
      canvas.drawLine(
        right.translate(-radius * 0.6, -radius * 1.15),
        right.translate(radius * 0.6, -radius * 1.3),
        brow,
      );
    }
  }

  void _paintMouth(Canvas canvas, Offset center, double width) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 0.22
      ..strokeCap = StrokeCap.round
      ..color = MortColors.softWhite;
    switch (state) {
      case MortMascotState.idle:
        canvas.drawArc(
          Rect.fromCenter(center: center, width: width, height: width * 0.7),
          0.35,
          math.pi - 0.7,
          false,
          paint,
        );
      case MortMascotState.listening:
        canvas.drawCircle(
          center,
          width * 0.22,
          paint..style = PaintingStyle.fill,
        );
      case MortMascotState.thinking:
        canvas.drawLine(
          center.translate(-width * 0.3, 0),
          center.translate(width * 0.3, -width * 0.06),
          paint,
        );
      case MortMascotState.success:
        canvas.drawArc(
          Rect.fromCenter(center: center, width: width, height: width),
          0.15,
          math.pi - 0.3,
          false,
          paint,
        );
      case MortMascotState.safetySerious:
        canvas.drawLine(
          center.translate(-width * 0.3, 0),
          center.translate(width * 0.3, 0),
          paint,
        );
    }
  }

  void _paintSparkles(Canvas canvas, double motion) {
    if (state != MortMascotState.success) return;
    final paint = Paint()..color = _silverBright;
    for (var i = 0; i < 4; i++) {
      final t = ((motion * 0.55 + i * 0.25) % 1.0);
      final center = Offset(22 + i * 18.0, 30 - t * 14);
      final alpha = t < 0.15
          ? t / 0.15
          : (1 - (t - 0.15) / 0.85).clamp(0.0, 1.0);
      paint.color = _silverBright.withValues(alpha: alpha * 0.9);
      canvas.drawCircle(center, 1.3 + 0.8 * (1 - t), paint);
    }
  }

  void _paintThinkingDots(Canvas canvas, double motion) {
    if (state != MortMascotState.thinking) return;
    final paint = Paint()..color = _silver;
    for (var i = 0; i < 3; i++) {
      final angle = motion * 1.4 + i * (math.pi * 2 / 3);
      final center = Offset(
        50 + math.cos(angle) * 16,
        18 + math.sin(angle) * 3.4,
      );
      paint.color = _silver.withValues(
        alpha: 0.45 + 0.4 * (math.sin(angle) + 1) / 2,
      );
      canvas.drawCircle(center, 1.7, paint);
    }
  }

  void _paintIcyHighlight(Canvas canvas, OvalHighlight spot) {
    canvas.drawOval(
      Rect.fromCenter(
        center: spot.center,
        width: spot.width,
        height: spot.height,
      ),
      Paint()..color = _icy.withValues(alpha: 0.35),
    );
  }

  // ----------------------------------------------------------------- Pip ---

  void _paintPip(Canvas canvas, double motion) {
    final body = Paint()..color = _bodyBlack;

    // Feet first (behind body).
    final feet = Paint()..color = MortColors.silverMid;
    canvas.drawOval(const Rect.fromLTWH(34, 86, 14, 6), feet);
    canvas.drawOval(const Rect.fromLTWH(52, 86, 14, 6), feet);

    // Body.
    final bodyRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(20, 14, 60, 76),
      const Radius.elliptical(30, 38),
    );
    canvas.drawRRect(bodyRect, body);

    // Belly.
    final belly = Paint()..color = _bellyWhite;
    canvas.drawOval(const Rect.fromLTWH(30, 34, 40, 52), belly);

    // Wings (slightly animated when listening).
    final wingSwing = state == MortMascotState.listening
        ? _sin(motion * 2.0) * 2.4
        : state == MortMascotState.success
        ? -4.0
        : 0.0;
    final wing = Paint()..color = MortColors.graphite4;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(12, 38 + wingSwing, 12, 34),
        const Radius.elliptical(6, 16),
      ),
      wing,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(76, 38 + wingSwing, 12, 34),
        const Radius.elliptical(6, 16),
      ),
      wing,
    );

    // Beak.
    final beak = Paint()..color = _silverBright;
    final beakPath = Path()
      ..moveTo(43, 30)
      ..lineTo(57, 30)
      ..lineTo(50, 40)
      ..close();
    canvas.drawPath(beakPath, beak);

    _paintEyes(
      canvas,
      left: const Offset(40, 24),
      right: const Offset(60, 24),
      radius: 6.2,
      motion: motion,
      pupilShift: state == MortMascotState.thinking ? 0.16 : 0.05,
      sclera: MortColors.white,
    );
    _paintMouth(canvas, const Offset(50, 43), 10);
    _paintIcyHighlight(canvas, OvalHighlight(const Offset(32, 22), 5, 9));
    _paintThinkingDots(canvas, motion);
    _paintSparkles(canvas, motion);
  }

  // --------------------------------------------------------------- Mochi ---

  void _paintMochi(Canvas canvas, double motion) {
    final fur = Paint()..color = _bodyGraphite;
    final earLining = Paint()..color = _silver;

    // Ears.
    final leftEar = Path()
      ..moveTo(26, 26)
      ..lineTo(34, 6)
      ..lineTo(46, 20)
      ..close();
    final rightEar = Path()
      ..moveTo(54, 20)
      ..lineTo(66, 6)
      ..lineTo(74, 26)
      ..close();
    canvas.drawPath(leftEar, fur);
    canvas.drawPath(rightEar, fur);
    final leftInner = Path()
      ..moveTo(30, 23)
      ..lineTo(35, 11)
      ..lineTo(43, 20)
      ..close();
    final rightInner = Path()
      ..moveTo(57, 20)
      ..lineTo(65, 11)
      ..lineTo(70, 23)
      ..close();
    canvas.drawPath(leftInner, earLining);
    canvas.drawPath(rightInner, earLining);

    // Head.
    canvas.drawOval(const Rect.fromLTWH(18, 18, 64, 62), fur);

    // Muzzle patch.
    final muzzle = Paint()..color = _bellyWhite;
    canvas.drawOval(const Rect.fromLTWH(32, 52, 36, 24), muzzle);

    // Cheek icy highlights.
    _paintIcyHighlight(canvas, OvalHighlight(const Offset(27, 50), 4.5, 7));
    _paintIcyHighlight(canvas, OvalHighlight(const Offset(73, 50), 4.5, 7));

    _paintEyes(
      canvas,
      left: const Offset(37, 44),
      right: const Offset(63, 44),
      radius: 7.4,
      motion: motion,
      pupilShift: state == MortMascotState.thinking ? 0.14 : 0.04,
      sclera: MortColors.white,
    );

    // Nose.
    final nose = Paint()..color = _silverBright;
    final nosePath = Path()
      ..moveTo(46.5, 55)
      ..lineTo(53.5, 55)
      ..lineTo(50, 59.5)
      ..close();
    canvas.drawPath(nosePath, nose);

    _paintMouth(canvas, const Offset(50, 64), 9);

    // Whiskers.
    final whisker = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = MortColors.silverMid;
    final spread = state == MortMascotState.listening ? 3.0 : 0.0;
    for (final dy in [-2.5, 0.0, 2.5]) {
      canvas.drawLine(
        Offset(30 - spread, 58 + dy),
        Offset(16 - spread, 54 + dy * 1.7),
        whisker,
      );
      canvas.drawLine(
        Offset(70 + spread, 58 + dy),
        Offset(84 + spread, 54 + dy * 1.7),
        whisker,
      );
    }

    _paintThinkingDots(canvas, motion);
    _paintSparkles(canvas, motion);
  }

  // --------------------------------------------------------------- Scout ---

  void _paintScout(Canvas canvas, double motion) {
    final fur = Paint()..color = _bodyGraphite;
    final earFur = Paint()..color = _bodyBlack;

    // Floppy ears (swing subtly).
    final swing = state == MortMascotState.safetySerious
        ? 0.0
        : _sin(motion * 1.8) * 1.8;
    canvas.drawOval(Rect.fromLTWH(8, 26 + swing, 16, 34), earFur);
    canvas.drawOval(Rect.fromLTWH(76, 26 - swing, 16, 34), earFur);

    // Head.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(18, 14, 64, 66),
        const Radius.elliptical(26, 30),
      ),
      fur,
    );

    // Silver brow spots.
    final brow = Paint()..color = _silver;
    canvas.drawCircle(const Offset(32, 26), 2.4, brow);
    canvas.drawCircle(const Offset(68, 26), 2.4, brow);

    // Muzzle patch.
    final muzzle = Paint()..color = _bellyWhite;
    canvas.drawOval(const Rect.fromLTWH(32, 50, 36, 26), muzzle);

    _paintEyes(
      canvas,
      left: const Offset(37, 42),
      right: const Offset(63, 42),
      radius: 6.8,
      motion: motion,
      pupilShift: state == MortMascotState.thinking ? 0.15 : 0.04,
      sclera: MortColors.white,
    );

    // Nose.
    final nose = Paint()..color = MortColors.void_;
    canvas.drawOval(const Rect.fromLTWH(45.5, 52, 9, 7), nose);

    _paintMouth(canvas, const Offset(50, 63), 10);

    // Steel-blue collar with silver tag.
    final collar = Paint()..color = _steelBlueDeep;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(24, 76, 52, 8),
        const Radius.circular(4),
      ),
      collar,
    );
    final tag = Paint()..color = _silverBright;
    canvas.drawCircle(const Offset(50, 86), 4, tag);
    canvas.drawCircle(
      const Offset(50, 86),
      4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = _steelBlue,
    );

    _paintThinkingDots(canvas, motion);
    _paintSparkles(canvas, motion);
  }

  @override
  bool shouldRepaint(MortMascotPainter oldDelegate) =>
      oldDelegate.mascot != mascot ||
      oldDelegate.state != state ||
      oldDelegate.phase != phase;
}

class OvalHighlight {
  const OvalHighlight(this.center, this.width, this.height);

  final Offset center;
  final double width;
  final double height;
}
