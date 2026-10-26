import 'package:flutter/material.dart';

import '../atmosphere/mort_wordmark_reveal.dart';
import '../theme/mort_tokens.dart';
import 'mort_motion_mark.dart';

class MortBrandMark extends StatelessWidget {
  const MortBrandMark({super.key, this.size = 72, this.showWordmark = false});

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final safeSize = _finiteDimension(size, fallback: 72, min: 24, max: 320);
    final mark = MortMotionMark(size: safeSize);
    if (!showWordmark) return mark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(height: 4),
        // Sized to the footprint of a single text line (roughly what the
        // previous static "M O R T" headlineSmall occupied), not the full
        // brand-mark size, so this never overflows tight layouts.
        MortWordmarkReveal(
          width: safeSize * 1.6,
          height: safeSize * 0.22,
          showTagline: false,
        ),
      ],
    );
  }
}

class MortAnimatedBrandMark extends StatefulWidget {
  const MortAnimatedBrandMark({
    super.key,
    this.size = 150,
    this.showWordmark = true,
  });

  final double size;
  final bool showWordmark;

  @override
  State<MortAnimatedBrandMark> createState() => _MortAnimatedBrandMarkState();
}

class _MortAnimatedBrandMarkState extends State<MortAnimatedBrandMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _rise;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: MortMotion.emphasized,
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _rise = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeSize = _finiteDimension(
      widget.size,
      fallback: 150,
      min: 24,
      max: 320,
    );
    final child = DecoratedBox(
      decoration: const BoxDecoration(boxShadow: MortShadows.glow),
      child: MortBrandMark(size: safeSize, showWordmark: widget.showWordmark),
    );
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedBuilder(
      animation: _controller,
      child: child,
      builder: (context, child) {
        final fade = _finiteUnitInterval(_fade.value);
        final rise = _finiteUnitInterval(_rise.value);
        final dy = _finiteOffset(safeSize * 0.08 * (1 - rise));
        return Opacity(
          opacity: fade,
          child: Transform.translate(offset: Offset(0, dy), child: child),
        );
      },
    );
  }
}

double _finiteDimension(
  double value, {
  required double fallback,
  required double min,
  required double max,
}) {
  if (!value.isFinite || value <= 0) return fallback;
  return value.clamp(min, max).toDouble();
}

double _finiteUnitInterval(double value) {
  if (!value.isFinite) return 1;
  return value.clamp(0.0, 1.0).toDouble();
}

double _finiteOffset(double value) {
  if (!value.isFinite) return 0;
  return value.clamp(-32.0, 32.0).toDouble();
}
