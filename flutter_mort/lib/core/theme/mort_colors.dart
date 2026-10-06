import 'package:flutter/material.dart';

/// Shared white, black, gray, and silver presentation tokens.
class MortClassicColors {
  const MortClassicColors._();

  static const canvas = Color(0xFFFFFFFF);
  static const ink = Color(0xFF111111);
  static const muted = Color(0xFF616161);
  static const subtle = Color(0xFF616161);
  static const surface = Color(0xFFF7F7F7);
  static const line = Color(0xFFE2E2E2);
  static const silverSurface = Color(0xFFE9E9E9);
  static const strongLine = Color(0xFF8A8A8A);
  static const danger = ink;
  static const success = ink;
  static const warning = ink;
  static const info = ink;

  /// Decorative light silver is never used as foreground text on white.
  static Color readableAccent(Color candidate) {
    if (candidate == MortColors.danger ||
        candidate == MortColors.paymentDanger ||
        candidate == MortColors.paymentDangerDeep) {
      return danger;
    }
    if (candidate == MortColors.warning ||
        candidate == MortColors.paymentWarning) {
      return warning;
    }
    if (candidate == MortColors.success ||
        candidate == MortColors.paymentSuccess ||
        candidate == MortColors.paymentSuccessDeep) {
      return success;
    }
    if (candidate == MortColors.lightBlue ||
        candidate == MortColors.safetyBlue ||
        candidate == MortColors.paymentInfo) {
      return info;
    }
    return candidate.computeLuminance() > 0.28 ? ink : candidate;
  }
}

/// Compatibility names resolve to the same neutral classic design system.
/// True black/white remain available for imagery and contrasting action text;
/// page/card/text aliases express their role on the white application canvas.
class MortColors {
  const MortColors._();

  // -- True black for contrast and original monochrome artwork --
  static const void_ = Color(0xFF000000);
  static const godBlack = void_;
  static const ink1 = MortClassicColors.ink;
  static const ink2 = MortClassicColors.ink;
  static const ink3 = MortClassicColors.ink;

  static const midnight = ink2;
  static const night = midnight;
  static const black = midnight;
  static const deepNavy = ink3;
  static const lowerNight = MortClassicColors.surface;
  static const softBlack = deepNavy;

  // -- Legacy surface names now resolve to white/light gray --
  static const graphite1 = MortClassicColors.canvas;
  static const graphite2 = MortClassicColors.surface;
  static const graphite3 = Color(0xFFF2F2F2);
  static const graphite4 = MortClassicColors.silverSurface;

  static const surface = graphite2;
  static const surfaceAlternate = graphite3;
  static const raisedBlack = graphite4;
  static const surfaceRaised = raisedBlack;

  // -- Compatibility depth names: neutral surface steps --
  static const night1 = MortClassicColors.canvas;
  static const night2 = MortClassicColors.surface;
  static const night3 = Color(0xFFF2F2F2);
  static const night4 = MortClassicColors.silverSurface;

  // -- White family --
  static const white = MortClassicColors.canvas;
  static const godWhite = white;
  static const softWhite = MortClassicColors.muted;

  // -- Readable gray foregrounds; light silver uses silverSurface --
  static const silver = MortClassicColors.muted;
  static const silverBright = Color(0xFF444444);
  static const silverDark = MortClassicColors.muted;
  static const silverMid = Color(0xFF707070);

  // -- Bright silver / ice --
  static const ice1 = Color(0xFFEDEDED);
  static const ice2 = Color(0xFFF5F5F5);
  static const ice3 = Color(0xFFF9F9F9);
  static const ice = ice2;

  // -- All primary/accent aliases use near-black --
  static const cobalt = primary;
  static const primary = MortClassicColors.ink;
  static const primaryBright = MortClassicColors.ink;
  static const sky = primary;
  static const accent = primary;

  static const roseGold = primary;
  static const roseGoldDeep = silverMid;
  static const roseGoldBright = primaryBright;
  static const roseGoldHighlight = ice;
  static const roseGoldShadow = ink3;

  // Near-black tint used only at metallic-gradient extremes, so buttons read
  // as reflective polished dark material (dark edge -> bright narrow
  // highlight -> dark edge) rather than a flat fill.
  static const roseGoldVeryDark = graphite1;

  static const roseGoldLight = roseGoldBright;
  static const roseGoldDark = roseGoldDeep;
  static const roseGoldMid = roseGoldBright;
  static const neon = primary;
  static const neonDeep = roseGoldDeep;

  // -- Legacy colored aliases are neutral --
  static const babyBlue = ice;
  static const babyBlueDeep = primaryBright;
  static const babyBlueSoft = ice;

  static const lightBlue = babyBlueDeep;
  static const lightBlueSoft = babyBlueSoft;
  static const lightBlueDeep = night4;
  static const safetyBlue = silver;

  static const blueLight1 = MortClassicColors.surface;
  static const blueLight2 = MortClassicColors.silverSurface;
  static const blueLight3 = MortClassicColors.strongLine;

  // -- Star light (atmosphere) --
  static const star = Color(0xFFD4D4D4);
  static const starCold = Color(0xFFB7B7B7);
  static const starIce = Color(0xFFEAEAEA);
  static const starBlue = Color(0xFFBCBCBC);

  // -- Premium accent (compat name only; icy-bright silver) --
  static const godPink = ice;
  static const godPinkSoft = ice;
  static const godPinkDeep = primaryBright;
  static const premium = MortClassicColors.ink;

  // -- Background / surface aliases used throughout the app --
  static const bg = MortClassicColors.canvas;
  static const bgSecondary = MortClassicColors.surface;
  static const bgElevated = MortClassicColors.surface;
  static const card = MortClassicColors.canvas;
  static const cardAlt = MortClassicColors.surface;
  static const cardBg = MortClassicColors.canvas; // rgba(5,6,9,.75)
  static const cardBg2 = MortClassicColors.surface; // rgba(8,10,13,.80)
  static const cardBg3 = MortClassicColors.surface; // rgba(11,13,17,.82)
  static const glass = cardBg2;
  static const glassPressed = MortClassicColors.silverSurface;
  static const border = MortClassicColors.line;
  static const borderStrong = MortClassicColors.strongLine;
  static const borderSilver = MortClassicColors.strongLine;
  static const line = border;
  static const lineStrong = borderStrong;
  static const hairline = MortClassicColors.line; // rgba(225,228,232,.06)
  static const hairline2 = MortClassicColors.line; // rgba(214,218,224,.10)
  static const blueHairline = MortClassicColors.line; // rgba(120,140,170,.08)
  static const focus = primary;

  // -- Text --
  static const text = MortClassicColors.ink;
  static const textSoft = MortClassicColors.muted;
  static const textPrimary = MortClassicColors.ink;
  static const textSecondary = MortClassicColors.muted;
  static const textMuted = MortClassicColors.subtle;
  static const textDisabled = MortClassicColors.subtle;

  // -- Semantic states --
  static const success = MortClassicColors.ink;
  static const successDeep = MortClassicColors.ink;
  static const successSoft = MortClassicColors.muted;
  static const warning = MortClassicColors.ink;
  static const danger = MortClassicColors.ink;
  static const dangerDeep = MortClassicColors.ink;

  // Status meaning is carried by labels/icons, not a color-only signal.
  static const paymentSuccess = MortClassicColors.ink;
  static const paymentSuccessDeep = MortClassicColors.ink;
  static const paymentWarning = MortClassicColors.ink;
  static const paymentDanger = MortClassicColors.ink;
  static const paymentDangerDeep = MortClassicColors.ink;
  static const paymentInfo = MortClassicColors.ink;
  static const paymentInfoSoft = MortClassicColors.silverSurface;
  static const paymentInfoDeep = MortClassicColors.muted;

  static const receiptPaper = MortClassicColors.canvas;
  static const receiptInk = MortClassicColors.ink;
  static const receiptMutedInk = MortClassicColors.muted;
  static const receiptRule = MortClassicColors.line;
  static const receiptEdge = MortClassicColors.line;

  static const paymentSilverHigh = Color(0xFFEDEDED);
  static const paymentSilverMid = Color(0xFFCCCCCC);
  static const paymentSilverLow = Color(0xFFA5A5A5);
  static const paymentOnSilver = MortClassicColors.ink;
  static const paymentSilverCta = paymentSilverHigh;
  static const paymentSilverCtaBright = paymentSilverHigh;
  static const paymentSilverCtaDeep = paymentSilverLow;

  // -- Canonical gradients --
  // Dark edge -> deep -> core -> narrow bright highlight -> core.
  // A narrow, sharp highlight band reads as a specular reflection off
  // polished dark material; a broad even blend reads flat.
  static const metallicGradient = <Color>[
    Color(0xFF747474),
    silverMid,
    silverBright,
    ice3,
    silver,
  ];

  static const darkRoseGoldGradient = <Color>[godBlack, roseGoldShadow, silver];

  static const backgroundGradient = <Color>[bg, cardAlt, bgElevated, graphite1];

  static const silverMetallicGradient = <Color>[
    silverDark,
    ice1,
    silver,
    silverDark,
  ];

  static const babyBlueGradient = <Color>[babyBlueDeep, babyBlue, babyBlueSoft];

  static const godPinkGradient = <Color>[ice, ice3, ice];

  /// Very selective use only -- not the default CTA gradient.
  static const signatureGradient = <Color>[silverBright, ice, ice1];

  /// Buried midnight depth gradient — atmosphere and rare reflections only.
  static const midnightDepthGradient = <Color>[night1, night2, night3, night4];
}
