import 'package:flutter/material.dart';

import '../theme/mort_colors.dart';
import '../theme/mort_tokens.dart';

class MortLogo extends StatelessWidget {
  const MortLogo({super.key, this.size = 72, this.showWordmark = false});

  static const assetPath = 'assets/branding/mort_arrow_adaptive_monochrome.png';

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
            color: MortColors.silver,
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
            color: MortColors.godWhite,
            letterSpacing: 7,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Backwards-compatible name for existing feature call sites.
class MortBrandMark extends MortLogo {
  const MortBrandMark({super.key, super.size, super.showWordmark});

  static const assetPath = MortLogo.assetPath;
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
  AnimationController? _controller;
  Animation<double>? _fade;
  Animation<double>? _rise;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ?..stop()
        ..value = 1;
      return;
    }
    if (_controller != null) return;
    final controller = AnimationController(
      vsync: this,
      duration: MortMotion.reveal,
    );
    _controller = controller;
    _fade = CurvedAnimation(
      parent: controller,
      curve: MortMotion.standardCurve,
    );
    _rise = CurvedAnimation(
      parent: controller,
      curve: MortMotion.standardCurve,
    );
    controller.forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
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
      child: MortLogo(size: safeSize, showWordmark: widget.showWordmark),
    );
    final controller = _controller;
    final fadeAnimation = _fade;
    final riseAnimation = _rise;
    if (MediaQuery.disableAnimationsOf(context) ||
        controller == null ||
        fadeAnimation == null ||
        riseAnimation == null) {
      return child;
    }
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        final fade = _finiteUnitInterval(fadeAnimation.value);
        final rise = _finiteUnitInterval(riseAnimation.value);
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
