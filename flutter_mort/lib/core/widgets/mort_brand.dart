import 'package:flutter/material.dart';

import '../theme/mort_colors.dart';
import '../theme/mort_tokens.dart';

class MortBrandMark extends StatelessWidget {
  const MortBrandMark({super.key, this.size = 72, this.showWordmark = false});

  static const assetPath = 'assets/branding/mort_arrow_rose_gold.png';

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final safeSize = _finiteDimension(size, fallback: 72, min: 24, max: 320);
    final mark = Semantics(
      image: true,
      label: 'MORT arrow logo',
      child: SizedBox.square(
        dimension: safeSize,
        child: Image.asset(
          assetPath,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, _, _) => Icon(
            Icons.north_east_rounded,
            size: safeSize * 0.58,
            color: MortColors.roseGold,
          ),
        ),
      ),
    );
    if (!showWordmark) return mark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        Text(
          'M O R T',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: MortColors.roseGoldLight,
            letterSpacing: 7,
            fontWeight: FontWeight.w500,
          ),
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
