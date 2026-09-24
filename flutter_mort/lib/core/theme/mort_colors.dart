import 'package:flutter/material.dart';

/// MORT canonical palette — BLACK + SILVER.
///
/// Visual balance target:
/// 70-80% black / near-black, 10-15% graphite, 7-12% silver/white,
/// 2-6% midnight blue atmospheric depth, <1% icy-blue highlight.
///
/// Midnight blue is atmosphere only: buried depth, subtle reflections,
/// meteor trail depth, cloud shadows, rare focus illumination. It is never
/// the main UI paint. Legacy semantic names (roseGold*, neon*, cobalt,
/// premium, godPink*, babyBlue*) are kept as compatibility aliases pointing
/// at the new silver identity so every screen/widget inherits the new
/// palette without a call-site rewrite — only the meaning of "the brand
/// light" changed, not the names.
class MortColors {
  const MortColors._();

  // -- Primary black family (dominant surface) --
  static const void_ = Color(0xFF000000);
  static const godBlack = void_;
  static const ink1 = Color(0xFF010101);
  static const ink2 = Color(0xFF030405);
  static const ink3 = Color(0xFF050607);

  static const midnight = ink2;
  static const night = midnight;
  static const black = midnight;
  static const deepNavy = ink3;
  static const lowerNight = Color(0xFF080A0D);
  static const softBlack = deepNavy;

  // -- Graphite family (soft black / elevated surfaces) --
  static const graphite1 = Color(0xFF080A0D);
  static const graphite2 = Color(0xFF0B0D11);
  static const graphite3 = Color(0xFF101218);
  static const graphite4 = Color(0xFF14171D);

  static const surface = graphite2;
  static const surfaceAlternate = graphite3;
  static const raisedBlack = graphite4;
  static const surfaceRaised = raisedBlack;

  // -- Midnight blue depth (atmosphere only, not UI paint) --
  static const night1 = Color(0xFF020818);
  static const night2 = Color(0xFF061020);
  static const night3 = Color(0xFF0A1930);
  static const night4 = Color(0xFF0C2140);

  // -- White family --
  static const white = Color(0xFFF7F8FA);
  static const godWhite = white;
  static const softWhite = Color(0xFFE1E4E8);

  // -- Silver family (the brand light) --
  static const silver = Color(0xFFBFC3CA);
  static const silverBright = Color(0xFFD6DAE0);
  static const silverDark = Color(0xFF707680);
  static const silverMid = Color(0xFF9BA1AA);

  // -- Bright silver / ice --
  static const ice1 = Color(0xFFE9EDF2);
  static const ice2 = Color(0xFFF2F5F8);
  static const ice3 = Color(0xFFF7F9FB);
  static const ice = ice2;

  // -- Brand accent (was electric cobalt; now polished silver) --
  static const cobalt = silverBright;
  static const primary = silverBright;
  static const primaryBright = ice1;
  static const sky = primaryBright;
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

  // -- Cold-blue family (buried depth + rare icy highlight only) --
  static const babyBlue = ice;
  static const babyBlueDeep = primaryBright;
  static const babyBlueSoft = ice;

  static const lightBlue = babyBlueDeep;
  static const lightBlueSoft = babyBlueSoft;
  static const lightBlueDeep = night4;
  static const safetyBlue = silver;

  static const blueLight1 = Color(0xFF13284A);
  static const blueLight2 = Color(0xFF183865);
  static const blueLight3 = Color(0xFF204B7F);

  // -- Star light (atmosphere) --
  static const star = Color(0xFFCDD5DE);
  static const starCold = Color(0xFFAEB8C4);
  static const starIce = Color(0xFFE5EBF1);
  static const starBlue = Color(0xFF9FC0E8);

  // -- Premium accent (compat name only; icy-bright silver) --
  static const godPink = ice;
  static const godPinkSoft = ice;
  static const godPinkDeep = primaryBright;
  static const premium = ice;

  // -- Background / surface aliases used throughout the app --
  static const bg = void_;
  static const bgSecondary = night;
  static const bgElevated = surfaceRaised;
  static const card = surface;
  static const cardAlt = surfaceAlternate;
  static const cardBg = Color(0xBF050609); // rgba(5,6,9,.75)
  static const cardBg2 = Color(0xCC080A0D); // rgba(8,10,13,.80)
  static const cardBg3 = Color(0xD10B0D11); // rgba(11,13,17,.82)
  static const glass = cardBg2;
  static const glassPressed = Color(0xE00B0D11);
  static const border = Color(0xFF1A1D23);
  static const borderStrong = Color(0xFF23272F);
  static const borderSilver = Color(0xFF555C67);
  static const line = border;
  static const lineStrong = borderStrong;
  static const hairline = Color(0x0FE1E4E8); // rgba(225,228,232,.06)
  static const hairline2 = Color(0x1AD6DAE0); // rgba(214,218,224,.10)
  static const blueHairline = Color(0x14788CAA); // rgba(120,140,170,.08)
  static const focus = primary;

  // -- Text --
  static const text = godWhite;
  static const textSoft = softWhite;
  static const textPrimary = godWhite;
  static const textSecondary = Color(0xFFADB2BA);
  static const textMuted = Color(0xFF707680);
  static const textDisabled = Color(0xFF4A4F58);

  // -- Semantic states --
  static const success = Color(0xFF4DBD8A);
  static const successDeep = Color(0xFF2E7D57);
  static const successSoft = Color(0xFF85D9B1);
  static const warning = Color(0xFFD59A42);
  static const danger = Color(0xFFE5484D);
  static const dangerDeep = Color(0xFF7F2B2E);

  // Payment and receipt semantics stay distinct from the silver identity.
  static const paymentSuccess = Color(0xFF46C483);
  static const paymentSuccessDeep = Color(0xFF2E8F62);
  static const paymentWarning = Color(0xFFD9A94F);
  static const paymentDanger = Color(0xFFE5605E);
  static const paymentDangerDeep = Color(0xFFB64645);
  static const paymentInfo = Color(0xFF8FB4D9);
  static const paymentInfoSoft = Color(0xFFC5D9ED);
  static const paymentInfoDeep = Color(0xFF5E7EAB);

  static const receiptPaper = Color(0xFFF3F0E7);
  static const receiptInk = Color(0xFF191D22);
  static const receiptMutedInk = Color(0xFF4E5560);
  static const receiptRule = Color(0xFFC9C3B2);
  static const receiptEdge = Color(0xFFDDD8C9);

  static const paymentSilverHigh = Color(0xFFE9EEF4);
  static const paymentSilverMid = Color(0xFFC4CDD7);
  static const paymentSilverLow = Color(0xFF9BA6B2);
  static const paymentOnSilver = Color(0xFF0B0E13);
  static const paymentSilverCta = paymentSilverHigh;
  static const paymentSilverCtaBright = paymentSilverHigh;
  static const paymentSilverCtaDeep = paymentSilverLow;

  // -- Canonical gradients --
  // Dark edge -> deep -> core -> narrow bright highlight -> core.
  // A narrow, sharp highlight band reads as a specular reflection off
  // polished dark material; a broad even blend reads flat.
  static const metallicGradient = <Color>[
    Color(0xFF6E7580),
    silverMid,
    silverBright,
    ice3,
    silver,
  ];

  static const darkRoseGoldGradient = <Color>[godBlack, roseGoldShadow, silver];

  static const backgroundGradient = <Color>[void_, ink2, ink3, graphite1];

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
