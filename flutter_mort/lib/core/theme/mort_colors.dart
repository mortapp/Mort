import 'package:flutter/material.dart';

/// MORT monochrome palette: space black, graphite, silver, white, and a
/// restrained cool-blue signal accent.
class MortColors {
  const MortColors._();

  // -- Black family --
  // Darkened one notch below the original Rose Gold 2.0 pass so God Black
  // reads as the dominant surface across more of the app, not just the
  // deepest corner of the gradient.
  static const godBlack = Color(0xFF030507);
  static const black = Color(0xFF0A0D11);
  static const softBlack = Color(0xFF10141A);
  static const raisedBlack = Color(0xFF151B22);

  // -- White family --
  static const white = Color(0xFFF4F7FB);
  static const godWhite = Color(0xFFF4F7FB);
  static const softWhite = Color(0xFFDCE2E8);

  // -- Silver family --
  static const silver = Color(0xFFB8C1CB);
  static const silverBright = Color(0xFFE7EDF3);
  static const silverDark = Color(0xFF89939F);

  // Compatibility aliases retained while feature screens migrate to the
  // canonical monochrome names.
  static const roseGold = silver;
  static const roseGoldDeep = silverDark;
  static const roseGoldBright = silverBright;
  static const roseGoldHighlight = white;
  static const roseGoldShadow = Color(0xFF3B4652);
  static const roseGoldVeryDark = black;
  static const roseGoldLight = silverBright;
  static const roseGoldDark = silverDark;
  static const roseGoldMid = silver;
  static const neon = accent;
  static const neonDeep = lightBlueDeep;

  // -- Baby Blue family (supporting identity color) --
  static const babyBlue = Color(0xFFA7DFFF);
  static const babyBlueDeep = Color(0xFF75C7F7);
  static const babyBlueSoft = Color(0xFFD3F0FF);

  // Cool blue is reserved for information, safety, location, and verified
  // system state.
  static const lightBlue = babyBlueDeep;
  static const lightBlueSoft = babyBlueSoft;
  static const lightBlueDeep = Color(0xFF16384B);
  static const safetyBlue = lightBlue;

  // Legacy aliases kept source-compatible while feature surfaces migrate.
  static const godPink = silverBright;
  static const godPinkSoft = silver;
  static const godPinkDeep = silverDark;

  // -- Background / surface aliases used throughout the app --
  static const bg = godBlack;
  static const bgSecondary = black;
  static const bgElevated = raisedBlack;
  static const card = softBlack;
  static const cardAlt = raisedBlack;
  static const glass = Color(0xCC10141A);
  static const glassPressed = Color(0xE01A222B);
  static const line = Color(0xFF27303A);
  static const lineStrong = Color(0xFF3A4652);

  // -- Text --
  static const text = godWhite;
  static const textSoft = softWhite;
  static const textMuted = silverDark;
  static const textDisabled = Color(0xFF52565E);

  // -- Semantic states --
  static const success = Color(0xFF35B779);
  static const successDeep = Color(0xFF1E7A50);
  static const successSoft = Color(0xFF85D9B1);
  static const warning = Color(0xFFD59A42);
  static const danger = Color(0xFFD44A5C);
  static const dangerDeep = Color(0xFF912E3B);

  // -- Payment-specific semantic tokens (approved Rork mapping) --
  // Keep the MORT V7 palette intact while exposing the dedicated Payment OS
  // color names required by the approved UI authority.
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

  static const premium = accent;

  // -- Canonical gradients --
  // Neutral metallic silver used by legacy gradient call sites.
  static const metallicGradient = <Color>[
    silverDark,
    silver,
    silverBright,
    white,
    silverBright,
    silver,
    silverDark,
  ];

  static const darkRoseGoldGradient = <Color>[
    godBlack,
    roseGoldShadow,
    roseGold,
  ];

  static const backgroundGradient = <Color>[godBlack, black, softBlack];

  static const silverMetallicGradient = <Color>[
    silverDark,
    silverBright,
    silver,
    silverDark,
  ];

  static const babyBlueGradient = <Color>[babyBlueDeep, babyBlue, babyBlueSoft];

  static const godPinkGradient = <Color>[black, silver, white];

  static const signatureGradient = <Color>[silverDark, silverBright, accent];

  static const accent = Color(0xFFDCE7F2);
}
