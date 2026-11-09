import 'package:flutter/material.dart';

/// Backwards-compatible screen wrapper that now paints the flat product
/// surface from the active MORT theme instead of a decorative star field.
class MortSpaceBackground extends StatelessWidget {
  const MortSpaceBackground({
    super.key,
    required this.child,
    this.seed = 20260908,
  });

  final Widget child;

  /// Retained to avoid breaking older call sites. The flat background is not
  /// randomized and does not use a seed.
  final int seed;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).scaffoldBackgroundColor,
    child: Material(type: MaterialType.transparency, child: child),
  );
}
