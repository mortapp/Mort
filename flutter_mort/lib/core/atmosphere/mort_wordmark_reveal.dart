import 'package:flutter/material.dart';

import 'mort_atmosphere_tuning.dart';
import 'mort_wordmark_paths.dart';

/// Tracks whether the MORT "handwriting" reveal has already played during
/// this app launch. The animation is a once-per-launch moment, never a
/// per-navigation/per-rebuild replay -- every [MortWordmarkReveal] instance
/// checks this before deciding whether to animate or render the settled
/// mark immediately.
class MortWordmarkPlayback {
  MortWordmarkPlayback._();

  static bool hasPlayedThisLaunch = false;
}

/// The MORT wordmark "written in light" once, on first launch: an
/// invisible pen tracing each letter's human stroke order (see
/// [MortWordmarkPaths]), never typed, faded, or slid in. After the trace
/// completes the pen glow fades out and the mark settles into a static
/// state -- it never moves again for the lifetime of the app process.
class MortWordmarkReveal extends StatefulWidget {
  const MortWordmarkReveal({
    super.key,
    this.width = 220,
    this.height = 64,
    this.showTagline = true,
    this.onComplete,
  });

  final double width;
  final double height;
  final bool showTagline;
  final VoidCallback? onComplete;

  @override
  State<MortWordmarkReveal> createState() => _MortWordmarkRevealState();
}

class _MortWordmarkRevealState extends State<MortWordmarkReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _alreadySettled = false;
  bool _started = false;

  static const List<Duration> _letterStarts = [
    MortAtmosphereTuning.wordmarkPreDelay,
    MortAtmosphereTuning.wordmarkOStart,
    MortAtmosphereTuning.wordmarkRStart,
    MortAtmosphereTuning.wordmarkTStart,
  ];
  static const List<Duration> _letterDurations = [
    MortAtmosphereTuning.wordmarkMDuration,
    MortAtmosphereTuning.wordmarkODuration,
    MortAtmosphereTuning.wordmarkRDuration,
    MortAtmosphereTuning.wordmarkTDuration,
  ];

  @override
  void initState() {
    super.initState();
    _alreadySettled = MortWordmarkPlayback.hasPlayedThisLaunch;
    _controller = AnimationController(
      vsync: this,
      duration: MortAtmosphereTuning.wordmarkTotal,
      value: _alreadySettled ? 1 : 0,
    )..addStatusListener(_handleStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (_alreadySettled) return;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      // Reduced motion: settle instantly, no trace animation, mark stays.
      _alreadySettled = true;
      _controller.value = 1;
      MortWordmarkPlayback.hasPlayedThisLaunch = true;
      return;
    }
    _controller.forward();
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      MortWordmarkPlayback.hasPlayedThisLaunch = true;
      widget.onComplete?.call();
    }
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_handleStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: CustomPaint(
          painter: _MortWordmarkPainter(
            animation: _controller,
            letterStarts: _letterStarts,
            letterDurations: _letterDurations,
            showTagline: widget.showTagline,
            settled: _alreadySettled,
          ),
        ),
      ),
    );
  }
}

class _MortWordmarkPainter extends CustomPainter {
  _MortWordmarkPainter({
    required this.animation,
    required this.letterStarts,
    required this.letterDurations,
    required this.showTagline,
    required this.settled,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final List<Duration> letterStarts;
  final List<Duration> letterDurations;
  final bool showTagline;
  final bool settled;

  static final List<List<Path>> _letters = MortWordmarkPaths.all;
  // Each letter's own normalized advance width (bounding width used for
  // layout), matching the coordinate space each letterX() was authored in.
  static const List<double> _advanceWidths = [0.60, 0.55, 0.48, 0.56];
  static const double _letterGap = 0.14;

  double get _elapsedMs =>
      MortAtmosphereTuning.wordmarkTotal.inMicroseconds *
      animation.value /
      1000.0;

  @override
  void paint(Canvas canvas, Size size) {
    final totalUnits =
        _advanceWidths.fold<double>(0, (a, b) => a + b) +
        _letterGap * (_advanceWidths.length - 1);
    final scale = size.height; // letters authored in a 0..1 square-ish box
    final totalWidth = totalUnits * scale;
    final startX = (size.width - totalWidth) / 2;
    final startY = 0.0;

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = MortAtmosphereTuning.wordmarkPenCore.withValues(
        alpha: settled || animation.value >= 1
            ? MortAtmosphereTuning.wordmarkRestOpacity
            : MortAtmosphereTuning.wordmarkPenCoreOpacity,
      );

    double cursorX = startX;
    Offset? penTip;
    double penTipOpacity = 0;

    for (var i = 0; i < _letters.length; i++) {
      final letterWidth = _advanceWidths[i] * scale;
      final offset = Offset(cursorX, startY);
      final letterProgress = settled ? 1.0 : _progressFor(i);

      if (letterProgress > 0) {
        final result = _drawLetter(
          canvas,
          _letters[i],
          offset,
          scale,
          letterProgress,
          strokePaint,
        );
        if (!settled && letterProgress < 1.0 && result != null) {
          penTip = result;
          penTipOpacity = 1.0;
        }
      }

      cursorX += letterWidth + _letterGap * scale;
    }

    if (!settled && penTip != null) {
      final fadeStartMs =
          MortAtmosphereTuning.wordmarkPenFadeStart.inMicroseconds / 1000.0;
      final fadeDurMs =
          MortAtmosphereTuning.wordmarkPenFadeDuration.inMicroseconds / 1000.0;
      if (_elapsedMs > fadeStartMs) {
        penTipOpacity = (1 - (_elapsedMs - fadeStartMs) / fadeDurMs).clamp(
          0.0,
          1.0,
        );
      }
      if (penTipOpacity > 0) {
        final haloPaint = Paint()
          ..color = MortAtmosphereTuning.wordmarkPenHalo().withValues(
            alpha: MortAtmosphereTuning.wordmarkPenHalo().a * penTipOpacity,
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawCircle(
          penTip,
          MortAtmosphereTuning.wordmarkPenHaloRadius,
          haloPaint,
        );
        final corePaint = Paint()
          ..color = MortAtmosphereTuning.wordmarkPenCore.withValues(
            alpha: penTipOpacity,
          );
        canvas.drawCircle(
          penTip,
          MortAtmosphereTuning.wordmarkPenCoreRadius,
          corePaint,
        );
      }
    }

    if (showTagline) {
      final taglineStartMs =
          MortAtmosphereTuning.wordmarkTaglineStart.inMicroseconds / 1000.0;
      final taglineDurMs =
          MortAtmosphereTuning.wordmarkTaglineDuration.inMicroseconds / 1000.0;
      double taglineOpacity;
      if (settled) {
        taglineOpacity = MortAtmosphereTuning.wordmarkTaglineMaxOpacity;
      } else {
        final t = ((_elapsedMs - taglineStartMs) / taglineDurMs).clamp(
          0.0,
          1.0,
        );
        taglineOpacity =
            MortAtmosphereTuning.wordmarkTaglineMinOpacity +
            (MortAtmosphereTuning.wordmarkTaglineMaxOpacity -
                    MortAtmosphereTuning.wordmarkTaglineMinOpacity) *
                t;
      }
      if (taglineOpacity > 0) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: MortAtmosphereTuning.wordmarkTagline,
            style: TextStyle(
              color: Colors.white.withValues(alpha: taglineOpacity),
              fontSize: scale * 0.11,
              letterSpacing: 2.2,
              fontWeight: FontWeight.w500,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          Offset(
            (size.width - textPainter.width) / 2,
            size.height - textPainter.height,
          ),
        );
      }
    }
  }

  double _progressFor(int index) {
    final startMs = letterStarts[index].inMicroseconds / 1000.0;
    final durMs = letterDurations[index].inMicroseconds / 1000.0;
    return ((_elapsedMs - startMs) / durMs).clamp(0.0, 1.0);
  }

  /// Draws one letter's strokes trimmed proportionally to [progress] across
  /// their combined arc length (so a long stroke and a short stroke both
  /// finish together, matching natural pen speed rather than each stroke
  /// taking equal wall-clock time). Returns the current pen-tip position if
  /// the letter is mid-reveal, else null.
  Offset? _drawLetter(
    Canvas canvas,
    List<Path> strokes,
    Offset origin,
    double scale,
    double progress,
    Paint paint,
  ) {
    final transformed = strokes
        .map(
          (p) => p
              .transform(Matrix4.diagonal3Values(scale, scale, 1).storage)
              .shift(origin),
        )
        .toList();
    final metricsPerStroke = transformed
        .map((p) => p.computeMetrics().toList())
        .toList();
    final lengthsPerStroke = metricsPerStroke
        .map((metrics) => metrics.fold<double>(0, (a, m) => a + m.length))
        .toList();
    final totalLength = lengthsPerStroke.fold<double>(0, (a, b) => a + b);
    if (totalLength <= 0) return null;

    final targetLength = totalLength * progress;
    var consumed = 0.0;
    Offset? tip;

    for (var s = 0; s < transformed.length; s++) {
      final strokeLength = lengthsPerStroke[s];
      if (strokeLength <= 0) continue;
      final strokeTarget = (targetLength - consumed).clamp(0.0, strokeLength);
      if (strokeTarget > 0) {
        var remaining = strokeTarget;
        for (final metric in metricsPerStroke[s]) {
          final take = remaining.clamp(0.0, metric.length);
          if (take > 0) {
            final extracted = metric.extractPath(0, take);
            canvas.drawPath(extracted, paint);
            if (take >= remaining - 0.01) {
              tip = metric.getTangentForOffset(take)?.position;
            }
          }
          remaining -= take;
          if (remaining <= 0) break;
        }
      }
      consumed += strokeLength;
      if (consumed >= targetLength) break;
    }
    return progress < 1.0 ? tip : null;
  }

  @override
  bool shouldRepaint(covariant _MortWordmarkPainter oldDelegate) {
    return !identical(oldDelegate.animation, animation) ||
        oldDelegate.settled != settled;
  }
}
