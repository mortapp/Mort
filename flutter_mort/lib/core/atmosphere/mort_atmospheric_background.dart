import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'mort_atmosphere_painter.dart';
import 'mort_atmosphere_composition.dart';
import 'mort_atmosphere_device_policy.dart';
import 'mort_atmosphere_scene.dart';
import 'mort_scene_clock.dart';
import 'mort_atmosphere_tuning.dart';
import 'mort_cloud_shader.dart';
import 'mort_meteor_scheduler.dart';
import 'mort_shimmer_scheduler.dart';

/// Degrades the scene for low-end devices (Galaxy A14 class and below), in
/// this exact cumulative order: reduce particle/meteor complexity first,
/// then drop the C1 cloud layer, then drop aurora, then drop the
/// atmospheric shimmer. Each step includes every step before it. Sky,
/// dither, and stars are never removed at any level -- they're the
/// cheapest layers and the ones that keep the background from reading as
/// a flat rectangle.
enum MortAtmosphereQuality {
  full,
  reducedParticles,
  noC1Cloud,
  noAurora,
  noShimmer;

  bool get _reduceParticles =>
      index >= MortAtmosphereQuality.reducedParticles.index;
  bool get _dropC1Cloud => index >= MortAtmosphereQuality.noC1Cloud.index;
  bool get _dropAurora => index >= MortAtmosphereQuality.noAurora.index;
  bool get _dropShimmer => index >= MortAtmosphereQuality.noShimmer.index;
}

/// Owns the single shared [Ticker] driving the whole atmosphere: scene
/// data is built once per size (never re-seeded on rebuild), meteors are
/// advanced every frame, and playback pauses/resumes with the app
/// lifecycle instead of drifting or jumping when the app is backgrounded.
class MortAtmosphericBackground extends StatefulWidget {
  const MortAtmosphericBackground({
    super.key,
    required this.intensity,
    this.quality = MortAtmosphereQuality.full,
    this.seed = 1,
    this.focalLayer,
    this.debugLift = MortAtmosphereTuning.atmosphereLift,
    this.cloudExposure = 1,
    this.forceReducedMotion = false,
  });

  final MortAtmosphereIntensity intensity;
  final MortAtmosphereQuality quality;
  final int seed;
  final Widget? focalLayer;
  final double debugLift;
  final double cloudExposure;
  final bool forceReducedMotion;

  @override
  State<MortAtmosphericBackground> createState() =>
      _MortAtmosphericBackgroundState();
}

class _MortAtmosphericBackgroundState extends State<MortAtmosphericBackground>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final MortSceneClock _clock;
  bool _appVisible = true;

  MortAtmosphereScene? _scene;
  Size? _sceneSize;
  MortMeteorScheduler? _meteorScheduler;
  final MortAtmosphereShimmerScheduler _shimmerScheduler =
      MortAtmosphereShimmerScheduler(seed: 21);
  final MortCloudShaderController _cloudShader = MortCloudShaderController();
  MortAtmosphereQuality _deviceQuality = MortAtmosphereQuality.full;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clock = MortSceneClock(this)..addListener(_advanceSchedulers);
    // `WidgetTester.pumpAndSettle()` -- used throughout this app's existing
    // widget-test suite -- waits for zero pending scheduled frames before
    // returning, and never terminates against a genuinely perpetual
    // animation; that is a structural limitation of pumpAndSettle, not a
    // defect in this ticker. Every other screen in the app embeds this
    // background via MortScreen, so without this guard essentially the
    // whole pre-existing pumpAndSettle-based test suite would hang.
    // Real devices are never running under this binding, so production
    // playback is unaffected; the atmosphere's own logic (scene, meteor
    // scheduler, painter) is covered independently by
    // mort_atmosphere_test.dart without any ticker involved.
    if (!_isAutomatedTestBinding) {
      _clock.start();
    }
    _configureCloudRenderer();
  }

  Future<void> _configureCloudRenderer() async {
    // Fragment-program compilation can take many minutes in Flutter's
    // Windows software test renderer. Painter and shader behavior are covered
    // directly in dedicated tests, so keep widget tests on the vector fallback.
    if (_isAutomatedTestBinding) return;
    final requiresFallback =
        await MortAtmosphereDevicePolicy.detectPerformanceFallback();
    if (requiresFallback) {
      _deviceQuality = MortAtmosphereQuality.noShimmer;
      _cloudShader.usePerformanceFallback();
    } else {
      await _cloudShader.load();
    }
    if (mounted) setState(() {});
  }

  static bool get _isAutomatedTestBinding =>
      WidgetsBinding.instance.runtimeType.toString() ==
      'AutomatedTestWidgetsFlutterBinding';

  void _advanceSchedulers() {
    if (!_appVisible) return;
    final profile = _profileFor(widget.intensity);
    _meteorScheduler?.tick(_clock.elapsed, profile);
    _shimmerScheduler.tick(_clock.elapsed, enabled: profile.shimmerEnabled);
  }

  MortAtmosphereProfile _profileFor(MortAtmosphereIntensity intensity) {
    final base = MortAtmosphereProfile.forIntensity(intensity);
    final quality = _effectiveQuality;
    if (!quality._reduceParticles) return base;
    // Step 1 of the fallback ladder: reduce meteor/particle complexity
    // (wider intervals, lower simultaneous cap) rather than duplicating
    // every profile field.
    return MortAtmosphereProfile(
      starOpacityMultiplier: base.starOpacityMultiplier,
      cloudOpacityMultiplier: base.cloudOpacityMultiplier,
      auroraEnabled: quality._dropAurora ? false : base.auroraEnabled,
      shimmerEnabled: quality._dropShimmer ? false : base.shimmerEnabled,
      meteorMinInterval: base.meteorMinInterval * 1.6,
      meteorMaxInterval: base.meteorMaxInterval * 1.6,
      meteorClusterChance: base.meteorClusterChance * 0.5,
      simultaneousCap: (base.simultaneousCap / 2).ceil().clamp(
        1,
        base.simultaneousCap,
      ),
      starfallBurst: base.starfallBurst,
    );
  }

  MortAtmosphereQuality get _effectiveQuality =>
      widget.quality.index >= _deviceQuality.index
      ? widget.quality
      : _deviceQuality;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _appVisible = false;
        _clock.stop();
      case AppLifecycleState.resumed:
        _appVisible = true;
        if (!_isAutomatedTestBinding) _clock.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock.removeListener(_advanceSchedulers);
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        widget.forceReducedMotion || MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (_scene == null || _sceneSize != size) {
          _sceneSize = size;
          _scene = MortAtmosphereScene(size: size, seed: widget.seed);
          _meteorScheduler = MortMeteorScheduler(
            size: size,
            seed: widget.seed + 100,
          );
        }
        final profile = _profileFor(widget.intensity);
        final quality = _effectiveQuality;
        MortAtmospherePainter painter(MortAtmospherePaintPhase phase) =>
            MortAtmospherePainter(
              scene: _scene!,
              sceneClock: _clock,
              profile: profile,
              meteorScheduler: reduceMotion ? null : _meteorScheduler,
              reducedMotion: reduceMotion,
              dropC1Cloud: quality._dropC1Cloud,
              shimmerScheduler: reduceMotion ? null : _shimmerScheduler,
              cloudShader: _cloudShader,
              lowComplexityShader: quality._reduceParticles,
              phase: phase,
              atmosphereLift: widget.debugLift,
              cloudExposure: widget.cloudExposure,
            );
        final focal = widget.focalLayer;
        return RepaintBoundary(
          child: focal == null
              ? CustomPaint(
                  size: size,
                  painter: painter(MortAtmospherePaintPhase.full),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      size: size,
                      painter: painter(MortAtmospherePaintPhase.background),
                    ),
                    IgnorePointer(child: focal),
                    IgnorePointer(
                      child: CustomPaint(
                        size: size,
                        painter: painter(MortAtmospherePaintPhase.foreground),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
