import 'package:flutter/material.dart';

/// Shared white, black, gray, and silver presentation tokens.
class MortClassicColors {
  const MortClassicColors._();

  static const canvas = Color(0xFFFFFFFF);
  static const ink = Color(0xFF111111);
  static const background = Color(0xFF0D0D0D);
  static const foreground = Color(0xFFF1F1F1);
  static const action = Color(0xFF424242);
  static const muted = Color(0xFFC1C1C1);
  static const subtle = Color(0xFFACACAC);
  static const surface = Color(0xFF1B1B1B);
  static const line = Color(0xFF3D3D3D);
  static const silverSurface = Color(0xFF2C2C2C);
  static const strongLine = Color(0xFF8A8A8A);
  static const danger = foreground;
  static const success = foreground;
  static const warning = foreground;
  static const info = foreground;

  /// Keep semantic foregrounds readable on the black/gray interface.
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
    return candidate.computeLuminance() < 0.28 ? foreground : candidate;
  }
}

/// Compatibility names resolve to the same neutral classic design system.
/// True black/white remain available for imagery and contrasting action text;
/// page/card/text aliases express their role on the black application canvas.
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

  // -- Primary black and graphite surfaces --
  static const graphite1 = MortClassicColors.background;
  static const graphite2 = MortClassicColors.surface;
  static const graphite3 = Color(0xFF222222);
  static const graphite4 = MortClassicColors.silverSurface;

  static const surface = graphite2;
  static const surfaceAlternate = graphite3;
  static const raisedBlack = graphite4;
  static const surfaceRaised = raisedBlack;

  // -- Compatibility depth names: neutral surface steps --
  static const night1 = MortClassicColors.background;
  static const night2 = MortClassicColors.surface;
  static const night3 = Color(0xFF222222);
  static const night4 = MortClassicColors.silverSurface;

  // -- White family --
  static const white = MortClassicColors.canvas;
  static const godWhite = white;
  static const softWhite = MortClassicColors.muted;

  // -- Readable gray foregrounds; light silver uses silverSurface --
  static const silver = MortClassicColors.muted;
  static const silverBright = Color(0xFFD9D9D9);
  static const silverDark = MortClassicColors.subtle;
  static const silverMid = Color(0xFF9A9A9A);

  // -- Bright silver / ice --
  static const ice1 = Color(0xFFEDEDED);
  static const ice2 = Color(0xFFF5F5F5);
  static const ice3 = Color(0xFFF9F9F9);
  static const ice = ice2;

  // -- Readable neutral foreground/accent compatibility aliases --
  static const cobalt = primary;
  static const primary = MortClassicColors.foreground;
  static const primaryBright = MortClassicColors.foreground;
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
  static const premium = MortClassicColors.foreground;

  // -- Background / surface aliases used throughout the app --
  static const bg = MortClassicColors.background;
  static const bgSecondary = MortClassicColors.surface;
  static const bgElevated = MortClassicColors.surface;
  static const card = MortClassicColors.surface;
  static const cardAlt = MortClassicColors.surface;
  static const cardBg = MortClassicColors.surface; // rgba(5,6,9,.75)
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
  static const text = MortClassicColors.foreground;
  static const textSoft = MortClassicColors.muted;
  static const textPrimary = MortClassicColors.foreground;
  static const textSecondary = MortClassicColors.muted;
  static const textMuted = MortClassicColors.subtle;
  static const textDisabled = MortClassicColors.subtle;

  // -- Semantic states --
  static const success = MortClassicColors.foreground;
  static const successDeep = MortClassicColors.foreground;
  static const successSoft = MortClassicColors.muted;
  static const warning = MortClassicColors.foreground;
  static const danger = MortClassicColors.foreground;
  static const dangerDeep = MortClassicColors.foreground;

  // Status meaning is carried by labels/icons, not a color-only signal.
  static const paymentSuccess = MortClassicColors.foreground;
  static const paymentSuccessDeep = MortClassicColors.foreground;
  static const paymentWarning = MortClassicColors.foreground;
  static const paymentDanger = MortClassicColors.foreground;
  static const paymentDangerDeep = MortClassicColors.foreground;
  static const paymentInfo = MortClassicColors.foreground;
  static const paymentInfoSoft = MortClassicColors.silverSurface;
  static const paymentInfoDeep = MortClassicColors.muted;

  static const receiptPaper = MortClassicColors.surface;
  static const receiptInk = MortClassicColors.foreground;
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

/// The current flat layout is independent of whether its palette is dark.
class MortClassicStyle extends ThemeExtension<MortClassicStyle> {
  const MortClassicStyle();

  static bool active(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<MortClassicStyle>() != null ||
        theme.brightness == Brightness.light;
  }

  @override
  MortClassicStyle copyWith() => this;

  @override
  MortClassicStyle lerp(covariant MortClassicStyle? other, double t) => this;
}
