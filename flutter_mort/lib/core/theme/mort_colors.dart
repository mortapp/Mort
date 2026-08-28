import 'package:flutter/material.dart';

/// MORT Rose Gold 2.0: God Black, metallic Rose Gold, God White, Silver,
/// Baby Blue, and God Pink as a rare signature accent.
class MortColors {
  const MortColors._();

  // -- Black family --
  // Darkened one notch below the original Rose Gold 2.0 pass so God Black
  // reads as the dominant surface across more of the app, not just the
  // deepest corner of the gradient.
  static const godBlack = Color(0xFF020205);
  static const black = Color(0xFF07070A);
  static const softBlack = Color(0xFF0C0C10);
  static const raisedBlack = Color(0xFF121217);

  // -- White family --
  static const white = Color(0xFFF5F5F7);
  static const godWhite = Color(0xFFFFFDF9);
  static const softWhite = Color(0xFFDADCE2);

  // -- Silver family --
  static const silver = Color(0xFFC6CBD3);
  static const silverBright = Color(0xFFE4E7EC);
  static const silverDark = Color(0xFF747B86);

  // -- Rose Gold family (primary brand) --
  static const roseGold = Color(0xFFD98C8C);
  static const roseGoldDeep = Color(0xFF8E4D56);
  static const roseGoldBright = Color(0xFFF0AAA3);
  static const roseGoldHighlight = Color(0xFFFFD4CC);
  static const roseGoldShadow = Color(0xFF5A3037);

  // Near-black rose tint used only at metallic-gradient extremes, so
  // buttons read as reflective polished metal (dark edge -> bright
  // narrow highlight -> dark edge) rather than a flat pink/salmon fill.
  static const roseGoldVeryDark = Color(0xFF231014);

  // Compatibility aliases so existing feature screens inherit the palette
  // without maintaining a second color language.
  static const roseGoldLight = roseGoldBright;
  static const roseGoldDark = roseGoldDeep;
  static const roseGoldMid = roseGoldBright;
  static const neon = roseGold;
  static const neonDeep = roseGoldDeep;

  // -- Baby Blue family (supporting identity color) --
  static const babyBlue = Color(0xFFA7DFFF);
  static const babyBlueDeep = Color(0xFF75C7F7);
  static const babyBlueSoft = Color(0xFFD3F0FF);

  // Baby Blue is reserved for information, safety, location, and verified
  // system state. It stays secondary to MORT's rose-gold brand.
  static const lightBlue = babyBlueDeep;
  static const lightBlueSoft = babyBlueSoft;
  static const lightBlueDeep = Color(0xFF16384B);
  static const safetyBlue = lightBlue;

  // -- God Pink (rare, high-energy signature accent -- not the primary) --
  static const godPink = Color(0xFFFF4FA3);
  static const godPinkSoft = Color(0xFFFF8AC5);
  static const godPinkDeep = Color(0xFF8A245B);

  // -- Background / surface aliases used throughout the app --
  static const bg = godBlack;
  static const bgSecondary = black;
  static const bgElevated = raisedBlack;
  static const card = softBlack;
  static const cardAlt = raisedBlack;
  static const glass = Color(0xB30E0E12);
  static const glassPressed = Color(0xE0161619);
  static const line = Color(0x14FFFFFF);
  static const lineStrong = Color(0x38FFFFFF);

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

  // Premium/paywall accents use the soft God Pink tone -- God Pink itself
  // stays rare, this keeps premium surfaces from tipping the app pink.
  static const premium = godPinkSoft;

  // -- Canonical gradients --
  // Dark edge -> deep -> core -> narrow bright highlight -> core -> deep
  // -> dark edge. A narrow, sharp highlight band reads as a specular
  // reflection off polished metal; a broad even blend reads as flat
  // pink. Pair with MortGradients.metallic's matching stop list.
  static const metallicGradient = <Color>[
    roseGoldVeryDark,
    roseGoldDeep,
    roseGold,
    roseGoldHighlight,
    roseGold,
    roseGoldDeep,
    roseGoldVeryDark,
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

  static const godPinkGradient = <Color>[godPinkDeep, godPink, godPinkSoft];

  /// Very selective use only -- not the default CTA gradient.
  static const signatureGradient = <Color>[roseGold, godPink, babyBlue];
}
