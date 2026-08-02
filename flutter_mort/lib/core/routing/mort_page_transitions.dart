import 'package:flutter/material.dart';

class MortPageTransitions {
  const MortPageTransitions._();

  static const PageTransitionsTheme theme = PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: MortFiniteFadePageTransitionsBuilder(),
      TargetPlatform.fuchsia: MortFiniteFadePageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
    },
  );
}

class MortFiniteFadePageTransitionsBuilder extends PageTransitionsBuilder {
  const MortFiniteFadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (route.isFirst) return child;
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        return Opacity(
          opacity: _finiteUnit(animation.value),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

double mortFiniteTransitionUnit(double value) => _finiteUnit(value);

double _finiteUnit(double value) {
  if (!value.isFinite) return 1;
  return value.clamp(0, 1).toDouble();
}
