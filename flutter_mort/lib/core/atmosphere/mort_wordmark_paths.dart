import 'package:flutter/material.dart';

/// Monoline vector strokes for the MORT wordmark, in a normalized
/// 0..1 coordinate space (scaled to the target rect at draw time).
///
/// Each letter is a list of strokes in the order a hand would actually
/// draw them -- not a typographic outline, and not the order the letters
/// are typed. This is what lets the writing animation look like a pen
/// moving through natural strokes instead of letters fading/sliding in.
class MortWordmarkPaths {
  const MortWordmarkPaths._();

  /// M: left vertical, up-down-up diagonal peak, right vertical.
  /// Drawn as three human strokes: down-left-leg, the V-peak, down-right-leg.
  static List<Path> letterM() {
    return [
      Path()
        ..moveTo(0.00, 1.00)
        ..lineTo(0.00, 0.00),
      Path()
        ..moveTo(0.00, 0.00)
        ..lineTo(0.30, 0.62)
        ..lineTo(0.60, 0.00),
      Path()
        ..moveTo(0.60, 0.00)
        ..lineTo(0.60, 1.00),
    ];
  }

  /// O: a single continuous oval stroke, starting at the top and sweeping
  /// clockwise -- the way a hand naturally draws a closed loop.
  static List<Path> letterO() {
    final rect = const Rect.fromLTWH(0.05, 0.02, 0.5, 0.96);
    return [Path()..addOval(rect)];
  }

  /// R: spine down, bowl loop, then the diagonal leg -- three strokes,
  /// matching how the letter is actually formed by hand.
  static List<Path> letterR() {
    return [
      Path()
        ..moveTo(0.00, 1.00)
        ..lineTo(0.00, 0.00),
      Path()
        ..moveTo(0.00, 0.00)
        ..cubicTo(0.42, -0.04, 0.46, 0.46, 0.02, 0.50),
      Path()
        ..moveTo(0.02, 0.50)
        ..lineTo(0.48, 1.00),
    ];
  }

  /// T: crossbar first, then the descending stem -- the conventional
  /// hand order for a capital T.
  static List<Path> letterT() {
    return [
      Path()
        ..moveTo(0.00, 0.00)
        ..lineTo(0.56, 0.00),
      Path()
        ..moveTo(0.28, 0.00)
        ..lineTo(0.28, 1.00),
    ];
  }

  static List<List<Path>> get all => [
    letterM(),
    letterO(),
    letterR(),
    letterT(),
  ];
}
