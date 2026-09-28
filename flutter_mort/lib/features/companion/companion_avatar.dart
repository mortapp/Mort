import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/mort_colors.dart';
import 'companion_catalog.dart';
import 'companion_store.dart';

enum CompanionAction {
  idle(''),
  pet('happy'),
  wave('waving'),
  play('playing'),
  rest('resting');

  const CompanionAction(this.semanticLabel);
  final String semanticLabel;
}

/// Original MORT vector companions. Motion is decorative and can be stopped.
class CompanionAvatar extends StatefulWidget {
  const CompanionAvatar({
    super.key,
    required this.companion,
    required this.look,
    this.size = 220,
    this.reducedMotion,
    this.action = CompanionAction.idle,
  });

  final CompanionDefinition companion;
  final CompanionLook look;
  final double size;
  final bool? reducedMotion;
  final CompanionAction action;

  @override
  State<CompanionAvatar> createState() => CompanionAvatarState();
}

class CompanionAvatarState extends State<CompanionAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  bool get isAnimating => _animation.isAnimating;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(CompanionAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion();
  }

  void _syncMotion() {
    final reduced =
        widget.reducedMotion ??
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    if (reduced) {
      _animation.stop();
      _animation.value = 0;
    } else if (!_animation.isAnimating) {
      _animation.repeat();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '${widget.companion.name}, ${widget.companion.kind} companion'
        '${widget.action == CompanionAction.idle ? '' : ', ${widget.action.semanticLabel}'}',
    image: true,
    child: ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _animation,
        builder: (_, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _CompanionPainter(
            companion: widget.companion,
            look: widget.look,
            phase: _animation.value * math.pi * 2,
            action: widget.action,
          ),
        ),
      ),
    ),
  );
}

class _CompanionPainter extends CustomPainter {
  const _CompanionPainter({
    required this.companion,
    required this.look,
    required this.phase,
    required this.action,
  });

  final CompanionDefinition companion;
  final CompanionLook look;
  final double phase;
  final CompanionAction action;

  Color get bodyColor {
    for (final option in companionColors) {
      if (option.id == look.colorId) return option.color ?? companion.baseColor;
    }
    return companion.baseColor;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [MortColors.night4.withValues(alpha: 0.36), Colors.transparent],
      ).createShader(const Rect.fromLTWH(5, 5, 90, 90));
    canvas.drawCircle(const Offset(50, 52), 45, glow);
    final bob = _motionOffset();
    canvas.translate(0, bob);
    if (action == CompanionAction.wave || action == CompanionAction.play) {
      final tilt =
          math.sin(phase * 2) * (action == CompanionAction.play ? .075 : .035);
      canvas.translate(50, 50);
      canvas.rotate(tilt);
      canvas.translate(-50, -50);
    }
    final fill = Paint()..color = bodyColor;
    final dark = Paint()..color = MortColors.graphite3;
    final outline = Paint()
      ..color = MortColors.silverDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    switch (companion.id) {
      case 'wix':
      case 'shadow':
        _tail(canvas, fill, right: companion.id == 'wix');
        _ear(canvas, fill, 22, 31, 12);
        _ear(canvas, fill, 78, 31, 88);
        _oval(canvas, fill, const Rect.fromLTWH(19, 28, 62, 58));
        if (companion.id == 'wix') {
          _oval(canvas, dark, const Rect.fromLTWH(31, 62, 38, 19));
        }
      case 'milo':
        _circle(canvas, fill, 25, 28, 12);
        _circle(canvas, fill, 75, 28, 12);
        _oval(canvas, fill, const Rect.fromLTWH(17, 28, 66, 59));
        _oval(
          canvas,
          Paint()..color = MortColors.softWhite,
          const Rect.fromLTWH(33, 60, 34, 19),
        );
      case 'nova':
        _tail(canvas, fill, right: true);
        _ear(canvas, fill, 20, 34, 12);
        _ear(canvas, fill, 80, 34, 88);
        _oval(canvas, fill, const Rect.fromLTWH(18, 31, 64, 56));
        _star(canvas, const Offset(50, 35), 6, MortColors.silverBright);
      case 'hoots':
        _oval(canvas, fill, const Rect.fromLTWH(18, 20, 64, 68));
        _oval(canvas, dark, const Rect.fromLTWH(12, 50, 17, 29));
        _oval(canvas, dark, const Rect.fromLTWH(71, 50, 17, 29));
        _circle(canvas, Paint()..color = MortColors.silverBright, 36, 51, 12);
        _circle(canvas, Paint()..color = MortColors.silverBright, 64, 51, 12);
      case 'rocky':
        _polygon(canvas, fill, const [
          Offset(23, 75),
          Offset(16, 52),
          Offset(29, 27),
          Offset(64, 22),
          Offset(83, 43),
          Offset(78, 76),
          Offset(55, 88),
        ]);
        _polygon(canvas, Paint()..color = MortColors.silverDark, const [
          Offset(29, 27),
          Offset(64, 22),
          Offset(48, 42),
        ]);
      case 'seedy':
      case 'sprig':
        _oval(canvas, fill, const Rect.fromLTWH(24, 39, 52, 46));
        _leaf(canvas, Offset(47, 38), Offset(27, 16), fill);
        _leaf(canvas, Offset(52, 37), Offset(72, 14), fill);
        if (companion.id == 'sprig') {
          _leaf(canvas, Offset(59, 43), Offset(83, 29), fill);
        }
      case 'stacky':
        _roundRect(canvas, fill, const Rect.fromLTWH(18, 32, 64, 54), 10);
        _roundRect(canvas, dark, const Rect.fromLTWH(25, 39, 50, 29), 7);
        canvas.drawLine(const Offset(50, 32), const Offset(50, 19), outline);
        _circle(canvas, fill, 50, 18, 5);
      case 'dewey':
        final path = Path()
          ..moveTo(50, 12)
          ..cubicTo(37, 36, 21, 52, 22, 65)
          ..cubicTo(23, 95, 77, 95, 78, 65)
          ..cubicTo(79, 52, 63, 36, 50, 12)
          ..close();
        canvas.drawPath(path, fill);
      case 'mizu':
        _oval(canvas, fill, const Rect.fromLTWH(18, 39, 64, 48));
        _circle(canvas, fill, 28, 37, 13);
        _circle(canvas, fill, 51, 29, 17);
        _circle(canvas, fill, 72, 38, 12);
        _circle(canvas, Paint()..color = MortColors.silverBright, 79, 21, 5);
      case 'nimbus':
        _circle(canvas, fill, 29, 55, 19);
        _circle(canvas, fill, 49, 42, 23);
        _circle(canvas, fill, 71, 55, 18);
        _oval(canvas, fill, const Rect.fromLTWH(19, 54, 62, 29));
      case 'ember':
        final path = Path()
          ..moveTo(50, 12)
          ..cubicTo(40, 35, 18, 44, 24, 69)
          ..cubicTo(29, 93, 71, 93, 77, 67)
          ..cubicTo(80, 48, 62, 30, 50, 12)
          ..close();
        canvas.drawPath(path, fill);
        _oval(
          canvas,
          Paint()..color = MortColors.silverMid,
          const Rect.fromLTWH(38, 62, 24, 21),
        );
      case 'pebble':
        _polygon(canvas, fill, const [
          Offset(34, 25),
          Offset(67, 29),
          Offset(84, 49),
          Offset(72, 80),
          Offset(43, 87),
          Offset(18, 70),
          Offset(21, 42),
        ]);
        _polygon(canvas, Paint()..color = MortColors.silverDark, const [
          Offset(34, 25),
          Offset(67, 29),
          Offset(52, 45),
          Offset(21, 42),
        ]);
    }

    _face(canvas);
    _accessory(canvas);
    _item(canvas);
    _aura(canvas);
    canvas.restore();
  }

  double _motionOffset() {
    final wave = math.sin(phase);
    if (action == CompanionAction.rest) return 0;
    if (action == CompanionAction.play) return -wave.abs() * 5;
    if (action == CompanionAction.pet) return -wave.abs() * 2;
    return switch (companion.id) {
      'mizu' || 'stacky' => wave * 2.8,
      'rocky' || 'pebble' => wave * 0.5,
      'nimbus' || 'nova' => wave * 2.2,
      'seedy' || 'sprig' => wave * 1.0,
      _ => wave * 1.5,
    };
  }

  void _face(Canvas canvas) {
    final eyeColor = bodyColor.computeLuminance() < .1
        ? MortColors.silverBright
        : MortColors.ink2;
    final eye = Paint()..color = eyeColor;
    final eyeY = companion.id == 'stacky' ? 53.0 : 55.0;
    // Each companion has a distinct motion profile, including blink cadence.
    final blink =
        action == CompanionAction.rest ||
        math.sin(phase * (companions.indexOf(companion) % 4 + 2)) > 0.985;
    if (blink) {
      final line = Paint()
        ..color = eyeColor
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(37, eyeY), Offset(43, eyeY), line);
      canvas.drawLine(Offset(57, eyeY), Offset(63, eyeY), line);
    } else {
      _circle(canvas, eye, 40, eyeY, 2.8);
      _circle(canvas, eye, 60, eyeY, 2.8);
    }
    _circle(canvas, Paint()..color = MortColors.silverDark, 50, eyeY + 11, 2);
  }

  void _accessory(Canvas canvas) {
    final line = Paint()
      ..color = MortColors.silverBright
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    switch (look.accessoryId) {
      case 'glasses':
        canvas.drawCircle(const Offset(40, 55), 8, line);
        canvas.drawCircle(const Offset(60, 55), 8, line);
        canvas.drawLine(const Offset(48, 55), const Offset(52, 55), line);
      case 'scarf':
        canvas.drawArc(
          const Rect.fromLTWH(26, 63, 48, 19),
          0,
          math.pi,
          false,
          line,
        );
      case 'crown':
        _polygon(canvas, Paint()..color = MortColors.silverBright, const [
          Offset(36, 28),
          Offset(34, 15),
          Offset(43, 22),
          Offset(50, 12),
          Offset(57, 22),
          Offset(66, 15),
          Offset(64, 28),
        ]);
      case 'bow':
        _polygon(canvas, Paint()..color = MortColors.silverBright, const [
          Offset(46, 32),
          Offset(33, 26),
          Offset(33, 38),
        ]);
        _polygon(canvas, Paint()..color = MortColors.silverBright, const [
          Offset(54, 32),
          Offset(67, 26),
          Offset(67, 38),
        ]);
      case 'beanie':
        _oval(
          canvas,
          Paint()..color = MortColors.graphite4,
          const Rect.fromLTWH(25, 19, 50, 23),
        );
      case 'headphones':
        canvas.drawArc(
          const Rect.fromLTWH(24, 27, 52, 48),
          math.pi,
          math.pi,
          false,
          line,
        );
        _roundRect(
          canvas,
          Paint()..color = MortColors.silverBright,
          const Rect.fromLTWH(20, 48, 10, 20),
          4,
        );
        _roundRect(
          canvas,
          Paint()..color = MortColors.silverBright,
          const Rect.fromLTWH(70, 48, 10, 20),
          4,
        );
    }
  }

  void _item(Canvas canvas) {
    if (look.itemId == 'none') return;
    final paint = Paint()..color = MortColors.silverBright;
    if (look.itemId == 'star') {
      _star(canvas, const Offset(82, 72), 8, MortColors.silverBright);
    } else {
      _roundRect(canvas, paint, const Rect.fromLTWH(77, 67, 12, 13), 3);
      canvas.drawLine(
        const Offset(80, 70),
        const Offset(86, 70),
        Paint()..color = MortColors.graphite3,
      );
    }
  }

  void _aura(Canvas canvas) {
    if (look.auraId == 'none') return;
    final paint = Paint()
      ..color = MortColors.silverBright.withValues(alpha: .7);
    for (final offset in const [
      Offset(15, 29),
      Offset(85, 36),
      Offset(27, 87),
    ]) {
      if (look.auraId == 'stars' || look.auraId == 'sparkles') {
        _star(canvas, offset, 3.5, paint.color);
      } else {
        canvas.drawCircle(offset, 2.5, paint);
      }
    }
  }

  void _tail(Canvas canvas, Paint fill, {required bool right}) {
    final side = right ? 1.0 : -1.0;
    final path = Path()
      ..moveTo(50 + side * 25, 72)
      ..quadraticBezierTo(50 + side * 46, 53, 50 + side * 40, 36)
      ..quadraticBezierTo(50 + side * 56, 71, 50 + side * 27, 84)
      ..close();
    canvas.drawPath(path, fill);
  }

  void _ear(Canvas canvas, Paint fill, double x, double base, double tipX) {
    _polygon(canvas, fill, [
      Offset(x - 10, base + 12),
      Offset(tipX, 15),
      Offset(x + 10, base + 12),
    ]);
  }

  void _leaf(Canvas canvas, Offset base, Offset tip, Paint fill) {
    final path = Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(tip.dx - 12, tip.dy + 5, tip.dx, tip.dy)
      ..quadraticBezierTo(tip.dx + 5, tip.dy + 15, base.dx, base.dy);
    canvas.drawPath(path, fill);
  }

  void _circle(Canvas canvas, Paint paint, double x, double y, double radius) =>
      canvas.drawCircle(Offset(x, y), radius, paint);

  void _oval(Canvas canvas, Paint paint, Rect rect) =>
      canvas.drawOval(rect, paint);

  void _roundRect(Canvas canvas, Paint paint, Rect rect, double radius) =>
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        paint,
      );

  void _polygon(Canvas canvas, Paint paint, List<Offset> points) {
    final path = Path()..addPolygon(points, true);
    canvas.drawPath(path, paint);
  }

  void _star(Canvas canvas, Offset center, double radius, Color color) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final angle = math.pi * i / 4 - math.pi / 2;
      final r = i.isEven ? radius : radius * .4;
      final point = Offset(
        center.dx + math.cos(angle) * r,
        center.dy + math.sin(angle) * r,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CompanionPainter oldDelegate) =>
      oldDelegate.companion != companion ||
      oldDelegate.look != look ||
      oldDelegate.action != action ||
      oldDelegate.phase != phase;
}
