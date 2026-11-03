import 'package:flutter/material.dart';

import 'mort_atmosphere_tuning.dart';

/// The reusable decorative light-sweep for interactive surfaces (buttons,
/// nav items, cards). This is a distinct system from the atmospheric
/// background shimmer in [MortAtmospherePainter] -- same visual language
/// (a soft diagonal highlight band), different purpose: this one wraps a
/// single widget and sweeps on a short, low-key period so it reads as a
/// material highlight, not a sky event.
class MortUiShimmer extends StatefulWidget {
  const MortUiShimmer({
    super.key,
    required this.child,
    this.enabled = true,
    this.borderRadius,
  });

  final Widget child;
  final bool enabled;
  final BorderRadius? borderRadius;

  @override
  State<MortUiShimmer> createState() => _MortUiShimmerState();
}

class _MortUiShimmerState extends State<MortUiShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: MortAtmosphereTuning.uiShimmerPeriod,
  );

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant MortUiShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.enabled && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (!widget.enabled || reduceMotion) {
      return widget.child;
    }
    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.zero,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  painter: _UiShimmerPainter(progress: _controller.value),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UiShimmerPainter extends CustomPainter {
  _UiShimmerPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final sweepWidth = size.width * 0.35;
    // Travel from just off the left edge to just past the right edge.
    final dx = -sweepWidth + progress * (size.width + sweepWidth * 2);
    final angle = MortAtmosphereTuning.shimmerAngleDegrees * 3.14159265 / 180;
    final rect = Rect.fromLTWH(
      dx - sweepWidth / 2,
      -size.height * 0.5,
      sweepWidth,
      size.height * 2,
    );

    canvas.save();
    canvas.translate(dx, size.height / 2);
    canvas.rotate(angle);
    canvas.translate(-dx, -size.height / 2);
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(
            alpha: MortAtmosphereTuning.uiShimmerPeakOpacity,
          ),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _UiShimmerPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
