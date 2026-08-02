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
    final mark = Semantics(
      image: true,
      label: 'MORT arrow logo',
      child: SizedBox.square(
        dimension: size,
        child: Image.asset(
          assetPath,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, _, _) => Icon(
            Icons.north_east_rounded,
            size: size * 0.58,
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
  late final Animation<Offset> _rise;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: MortMotion.emphasized,
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _rise = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = DecoratedBox(
      decoration: const BoxDecoration(boxShadow: MortShadows.glow),
      child: MortBrandMark(
        size: widget.size,
        showWordmark: widget.showWordmark,
      ),
    );
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _rise, child: child),
    );
  }
}
