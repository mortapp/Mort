import 'package:flutter/material.dart';

/// Centralized tuning for the MORT animated night atmosphere — black sky
/// with silver light inside it, midnight blue buried as depth only.
/// Every opacity, color stop, layer count, and timing value the scene uses
/// lives here -- no screen or painter should hardcode its own atmosphere
/// constant. This is what "one centralized value, no scattered opacity
/// tuning" means in practice.
///
/// This is an original implementation authored for this codebase. It is
/// not extracted from, or a copy of, any third-party product's animation
/// asset -- built from first principles (gradients, procedural blob paths,
/// PathMetric-driven strokes) using Flutter-native primitives.
class MortAtmosphereTuning {
  const MortAtmosphereTuning._();

  /// Single source of truth for how much the whole scene's brightness is
  /// lifted off pure black. Keep this centralized -- do not tune opacity
  /// per-layer to compensate for changing this value elsewhere.
  static const double atmosphereLift = 0.035;

  // -- Sky gradient (vertical): black, with a buried midnight band --
  static const skyTop = Color(0xFF000000);
  static const skyUpperMid = Color(0xFF010102);
  static const skyLowerMid = Color(0xFF020818); // Night1 depth
  static const skyBottom = Color(0xFF010102);

  // -- Center glow (radial): buried midnight blue, very low alpha --
  static const centerGlowInner = Color(0x13183865); // rgba(24,56,101,.075)
  static const centerGlowOuter = Color(0x090C2140); // rgba(12,33,64,.035)

  // Exact alpha per spec (Color() alpha channel is 0-255, spec gives 0-1).
  static Color centerGlowInnerColor() =>
      const Color(0xFF183865).withValues(alpha: 0.075);
  static Color centerGlowOuterColor() =>
      const Color(0xFF0C2140).withValues(alpha: 0.035);

  // -- Vignette --
  static Color vignetteMid() => const Color(0xFF000105).withValues(alpha: 0.27);
  static Color vignetteEdge() =>
      const Color(0xFF000003).withValues(alpha: 0.91);

  // -- Dither / anti-banding --
  static const double ditherModulation = 0.012; // ~1.2%, within the 1-1.5% spec

  // -- Stars: 4 depth layers, deliberately uneven density (not wallpaper) --
  static const starLayers = <MortStarLayerSpec>[
    MortStarLayerSpec(
      count: 90,
      minSize: 0.5,
      maxSize: 0.9,
      minOpacity: 0.08,
      maxOpacity: 0.17,
      driftPxPerSec: 1.5,
    ),
    MortStarLayerSpec(
      count: 60,
      minSize: 0.7,
      maxSize: 1.2,
      minOpacity: 0.13,
      maxOpacity: 0.27,
      driftPxPerSec: 3.0,
    ),
    MortStarLayerSpec(
      count: 35,
      minSize: 1.0,
      maxSize: 1.6,
      minOpacity: 0.20,
      maxOpacity: 0.37,
      driftPxPerSec: 6.0,
    ),
    MortStarLayerSpec(
      count: 12,
      minSize: 1.4,
      maxSize: 2.2,
      minOpacity: 0.29,
      maxOpacity: 0.47,
      driftPxPerSec: 9.0,
    ),
  ];
  static const double starTwinkleFraction = 0.25;
  static const int starRareFlareCount = 3;

  // -- Clouds: 4 layers, procedural asymmetric blob masses --
  static const cloudLayers = <MortCloudLayerSpec>[
    MortCloudLayerSpec(
      peakAlpha: 0.10,
      softness: 18,
      driftPxPerSec: 2,
      driftRight: true,
      hueShiftDegrees: 0,
      density: 0.52,
      bandY: 0.27,
      bandHeight: 0.42,
      tint: Color(0xFF05070B), // graphite-black mass
      layerSeed: 1.7,
    ),
    MortCloudLayerSpec(
      peakAlpha: 0.14,
      softness: 22,
      driftPxPerSec: 3,
      driftRight: false,
      hueShiftDegrees: 8,
      density: 0.57,
      bandY: 0.30,
      bandHeight: 0.46,
      tint: Color(0xFF070B14), // graphite with buried night interior
      layerSeed: 4.3,
    ),
    MortCloudLayerSpec(
      peakAlpha: 0.19,
      softness: 26,
      driftPxPerSec: 5,
      driftRight: true,
      hueShiftDegrees: 16,
      density: 0.63,
      bandY: 0.33,
      bandHeight: 0.50,
      tint: Color(0xFF081020), // night2 depth interior
      layerSeed: 7.9,
    ),
    MortCloudLayerSpec(
      peakAlpha: 0.24,
      softness: 30,
      driftPxPerSec: 8,
      driftRight: false,
      hueShiftDegrees: 24,
      density: 0.68,
      bandY: 0.36,
      bandHeight: 0.56,
      tint: Color(0xFF060A12),
      layerSeed: 12.1,
    ),
  ];
  static Color cloudRimLightStart() =>
      const Color(0xFF9FC0E8).withValues(alpha: 0.08);
  static Color cloudRimLightEnd() =>
      const Color(0xFFCDD5DE).withValues(alpha: 0.12);

  // -- Aurora: 2 bands --
  static const double auroraMinOpacity = 0.030;
  static const double auroraMaxOpacity = 0.082;
  static const double auroraDriftPxPerSecA = 0.4;
  static const double auroraDriftPxPerSecB = -0.25;
  static const double auroraVerticalBreathePx = 8;
  static const Duration auroraBreatheDuration = Duration(seconds: 40);

  // -- Meteors --
  static const double meteorAngleDegrees = 22; // below horizontal
  static const double meteorAngleJitterDegrees = 6;
  static const double meteorMinLength = 120;
  static const double meteorMaxLength = 380;
  static const Duration meteorMinDuration = Duration(milliseconds: 700);
  static const Duration meteorMaxDuration = Duration(milliseconds: 1400);
  static const double meteorHeadMinRadius = 1.2;
  static const double meteorHeadMaxRadius = 2.4;
  static const double meteorTrailMinWidth = 1.0;
  static const double meteorTrailMaxWidth = 2.2;
  static const Color meteorHeadColor = Color(0xFFF0FAFF);
  static const double meteorFadeInFraction = 0.12;
  static const double meteorFadeOutStartFraction = 0.55; // last 45% fades out
  static const double meteorBackgroundFraction =
      0.40; // 40% render behind clouds/wordmark
  static const int meteorNormalSimultaneousCap = 4;
  static const int meteorStarfallSimultaneousCap = 7;

  // -- Shimmer (rare atmospheric sweep, distinct from decorative UI shimmer) --
  static const Duration shimmerMinInterval = Duration(seconds: 14);
  static const Duration shimmerMaxInterval = Duration(seconds: 20);
  static const Duration shimmerDuration = Duration(milliseconds: 2200);
  static const double shimmerWidth = 90;
  static const double shimmerAngleDegrees = 28;
  static const double shimmerPeakOpacity = 0.055;

  // -- Decorative UI shimmer (buttons/cards/nav -- separate system, see
  // mort_shimmer.dart) --
  static const Duration uiShimmerPeriod = Duration(seconds: 6);
  static const double uiShimmerPeakOpacity = 0.07;

  // -- MORT wordmark writing animation --
  static const Duration wordmarkPreDelay = Duration(milliseconds: 350);
  static const Duration wordmarkMDuration = Duration(milliseconds: 620);
  static const Duration wordmarkOStart = Duration(milliseconds: 900);
  static const Duration wordmarkODuration = Duration(milliseconds: 560);
  static const Duration wordmarkRStart = Duration(milliseconds: 1400);
  static const Duration wordmarkRDuration = Duration(milliseconds: 620);
  static const Duration wordmarkTStart = Duration(milliseconds: 1960);
  static const Duration wordmarkTDuration = Duration(milliseconds: 420);
  static const Duration wordmarkPenFadeStart = Duration(milliseconds: 2380);
  static const Duration wordmarkPenFadeDuration = Duration(milliseconds: 300);
  static const Duration wordmarkTaglineStart = Duration(milliseconds: 2500);
  static const Duration wordmarkTaglineDuration = Duration(milliseconds: 600);
  static const Duration wordmarkTotal = Duration(milliseconds: 3100);

  static const double wordmarkRestOpacity = 0.20;
  static Color wordmarkHalo() =>
      const Color(0xFF204B7F).withValues(alpha: 0.06);
  static const double wordmarkTaglineMinOpacity = 0.25;
  static const double wordmarkTaglineMaxOpacity = 0.30;
  static const String wordmarkTagline = 'EARN NEARBY · MOVE SMART';

  static const Color wordmarkPenCore = Color(0xFFF5FBFF);
  static const double wordmarkPenCoreOpacity = 0.9;
  static const double wordmarkPenCoreRadius = 1.5;
  static const double wordmarkPenHaloRadius = 7;
  static Color wordmarkPenHalo() =>
      const Color(0xFFBFC9D9).withValues(alpha: 0.22);
}

@immutable
class MortStarLayerSpec {
  const MortStarLayerSpec({
    required this.count,
    required this.minSize,
    required this.maxSize,
    required this.minOpacity,
    required this.maxOpacity,
    required this.driftPxPerSec,
  });

  final int count;
  final double minSize;
  final double maxSize;
  final double minOpacity;
  final double maxOpacity;
  final double driftPxPerSec;
}

@immutable
class MortCloudLayerSpec {
  const MortCloudLayerSpec({
    required this.peakAlpha,
    required this.softness,
    required this.driftPxPerSec,
    required this.driftRight,
    required this.hueShiftDegrees,
    required this.density,
    required this.bandY,
    required this.bandHeight,
    required this.tint,
    required this.layerSeed,
  });

  final double peakAlpha;
  final double softness;
  final double driftPxPerSec;
  final bool driftRight;
  final double hueShiftDegrees;
  final double density;
  final double bandY;
  final double bandHeight;
  final Color tint;
  final double layerSeed;
}

/// Screen-by-screen atmospheric intensity presets (Stage 5/6).
enum MortAtmosphereIntensity {
  midnight, // Auth, Onboarding, Safety -- highest visibility
  quiet, // Discover, Messages -- medium/low-medium
  settings, // Settings, content-heavy -- very low
  starfall, // Celebration moments
}

class MortAtmosphereProfile {
  const MortAtmosphereProfile({
    required this.starOpacityMultiplier,
    required this.cloudOpacityMultiplier,
    required this.auroraEnabled,
    required this.shimmerEnabled,
    required this.meteorMinInterval,
    required this.meteorMaxInterval,
    required this.meteorClusterChance,
    required this.simultaneousCap,
    this.starfallBurst = false,
  });

  final double starOpacityMultiplier;
  final double cloudOpacityMultiplier;
  final bool auroraEnabled;
  final bool shimmerEnabled;
  final Duration meteorMinInterval;
  final Duration meteorMaxInterval;
  final double meteorClusterChance;
  final int simultaneousCap;
  final bool starfallBurst;

  static const midnight = MortAtmosphereProfile(
    starOpacityMultiplier: 1.0,
    cloudOpacityMultiplier: 1.0,
    auroraEnabled: true,
    shimmerEnabled: true,
    meteorMinInterval: Duration(seconds: 3),
    meteorMaxInterval: Duration(seconds: 8),
    meteorClusterChance: 0.30,
    simultaneousCap: MortAtmosphereTuning.meteorNormalSimultaneousCap,
  );

  static const quiet = MortAtmosphereProfile(
    starOpacityMultiplier: 0.75,
    cloudOpacityMultiplier: 0.7,
    auroraEnabled: true,
    shimmerEnabled: true,
    meteorMinInterval: Duration(seconds: 9),
    meteorMaxInterval: Duration(seconds: 18),
    meteorClusterChance: 0.10,
    simultaneousCap: MortAtmosphereTuning.meteorNormalSimultaneousCap,
  );

  static const settings = MortAtmosphereProfile(
    starOpacityMultiplier: 0.45,
    cloudOpacityMultiplier: 0.4,
    auroraEnabled: false,
    shimmerEnabled: false,
    meteorMinInterval: Duration(seconds: 20),
    meteorMaxInterval: Duration(seconds: 40),
    meteorClusterChance: 0.0,
    simultaneousCap: 1,
  );

  static const starfall = MortAtmosphereProfile(
    starOpacityMultiplier: 1.0,
    cloudOpacityMultiplier: 0.8,
    auroraEnabled: true,
    shimmerEnabled: true,
    meteorMinInterval: Duration(milliseconds: 100),
    meteorMaxInterval: Duration(milliseconds: 100),
    meteorClusterChance: 1.0,
    simultaneousCap: MortAtmosphereTuning.meteorStarfallSimultaneousCap,
    starfallBurst: true,
  );

  static MortAtmosphereProfile forIntensity(
    MortAtmosphereIntensity intensity,
  ) => switch (intensity) {
    MortAtmosphereIntensity.midnight => midnight,
    MortAtmosphereIntensity.quiet => quiet,
    MortAtmosphereIntensity.settings => settings,
    MortAtmosphereIntensity.starfall => starfall,
  };
}
