import 'package:flutter/material.dart';

import '../theme/mort_colors.dart';

/// A small original forward-motion symbol drawn as transparent vector paths.
/// It deliberately has no raster tile or rectangular background.
class MortMotionMark extends StatelessWidget {
  const MortMotionMark({
    super.key,
    this.size = 44,
    this.settled = false,
    this.outlinedUp = false,
  });

  final double size;
  final bool settled;
  final bool outlinedUp;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'MORT motion mark',
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _MortMotionMarkPainter(
          settled: settled,
          outlinedUp: outlinedUp,
        ),
      ),
    ),
  );
}

class _MortMotionMarkPainter extends CustomPainter {
  const _MortMotionMarkPainter({
    required this.settled,
    required this.outlinedUp,
  });

  final bool settled;
  final bool outlinedUp;

  // One chevron of the double-arrow mark: a concave dart pointing right,
  // matching the app icon's brushed-silver double-chevron silhouette.
  Path _chevron(Size size, double backX, double frontOffset) {
    final tipX = size.width * (backX + frontOffset);
    final notchX = size.width * (backX + frontOffset * 0.55);
    final x = size.width * backX;
    return Path()
      ..moveTo(x, size.height * 0.22)
      ..lineTo(tipX, size.height * 0.50)
      ..lineTo(x, size.height * 0.78)
      ..lineTo(notchX, size.height * 0.50)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (outlinedUp) {
      final front = Path()
        ..moveTo(size.width * 0.12, size.height * 0.56)
        ..lineTo(size.width * 0.50, size.height * 0.18)
        ..lineTo(size.width * 0.88, size.height * 0.56);
      final back = Path()
        ..moveTo(size.width * 0.22, size.height * 0.82)
        ..lineTo(size.width * 0.50, size.height * 0.54)
        ..lineTo(size.width * 0.78, size.height * 0.82);
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(front, stroke..color = MortColors.ice);
      canvas.drawPath(back, stroke..color = MortColors.silverDark);
      return;
    }
    const frontOffset = 0.42;
    final path = Path()
      ..addPath(_chevron(size, 0.20, frontOffset), Offset.zero)
      ..addPath(_chevron(size, 0.40, frontOffset), Offset.zero);
    final bounds = Offset.zero & size;
    final halo = Paint()
      ..color = MortColors.primary.withValues(alpha: settled ? 0.05 : 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawPath(path, halo);
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [MortColors.cobalt, MortColors.primary, MortColors.ice],
          stops: [0, 0.72, 1],
        ).createShader(bounds),
    );
    // Thin icy-blue rim light along the front chevron's top edge, echoing
    // the app icon's brushed-metal highlight.
    final frontTop = Offset(size.width * 0.40, size.height * 0.22);
    final frontTip = Offset(
      size.width * (0.40 + frontOffset),
      size.height * 0.50,
    );
    canvas.drawLine(
      frontTop,
      Offset.lerp(frontTop, frontTip, 0.55)!,
      Paint()
        ..color = MortColors.lightBlueSoft.withValues(alpha: 0.55)
        ..strokeWidth = size.width * 0.02
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _MortMotionMarkPainter oldDelegate) =>
      oldDelegate.settled != settled || oldDelegate.outlinedUp != outlinedUp;
}
