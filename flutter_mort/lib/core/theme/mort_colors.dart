import 'package:flutter/material.dart';

/// MORT's Royal House identity: obsidian foundations, royal blue, imperial
/// purple, ruby, antique gold (ceremonial only), success green, and
/// parchment/ivory text. Rose gold is retired.
class MortColors {
  const MortColors._();

  // Foundation / night surfaces.
  static const bg = Color(0xFF08070A);
  static const bgSecondary = Color(0xFF0D0A10);
  static const bgElevated = Color(0xFF191522);
  static const card = Color(0xFF12101A);
  static const cardAlt = Color(0xFF191522);
  static const chamber = Color(0xFF211A2C);
  static const glass = Color(0xB3140F1C);
  static const glassPressed = Color(0xE01B1526);
  static const line = Color(0x14FFFFFF);
  static const lineStrong = Color(0x38FFFFFF);

  // Text.
  static const text = Color(0xFFF4EFE6);
  static const textSoft = Color(0xFFCEC3B5);
  static const textMuted = Color(0xFF918779);
  static const textDisabled = Color(0xFF675F57);
  static const textDark = Color(0xFF18120B);

  // Royal Blue -- primary CTA / navigation identity.
  static const royalBlue = Color(0xFF2446A8);
  static const royalBlueDeep = Color(0xFF172D70);
  static const royalBlueBright = Color(0xFF3B64D9);
  static const royalBlueSoft = Color(0xFF7896E8);

  // Imperial Purple -- rank, reputation, leaderboard identity.
  static const imperialPurple = Color(0xFF67348F);
  static const imperialPurpleDeep = Color(0xFF43205F);
  static const imperialPurpleBright = Color(0xFF8A52B8);
  static const imperialPurpleSoft = Color(0xFFB08BCB);

  // Ruby -- accent ornament, not a primary CTA color.
  static const ruby = Color(0xFFA72D55);
  static const rubyDeep = Color(0xFF701B39);
  static const rubyBright = Color(0xFFCC4777);
  static const rubySoft = Color(0xFFE789A9);

  // Antique Gold -- ceremonial only: rank, verified prestige, leaderboard
  // #1, section headings. Never a full-surface fill.
  static const antiqueGold = Color(0xFFC8A84E);
  static const antiqueGoldDeep = Color(0xFF8E722D);
  static const antiqueGoldBright = Color(0xFFE2C76F);
  static const antiqueGoldPale = Color(0xFFF0DFA3);

  // Compatibility aliases so existing feature screens inherit the rebrand
  // without maintaining a second color language.
  static const neon = royalBlue;
  static const neonDeep = royalBlueDeep;
  static const roseGold = royalBlue;
  static const roseGoldLight = royalBlueSoft;
  static const roseGoldDark = royalBlueDeep;
  static const roseGoldMid = royalBlueBright;
  static const roseGoldDeep = royalBlueDeep;
  static const silver = Color(0xFFBFB29D);

  // Info / secondary -- reserved for information, safety, location, and
  // verified system state.
  static const lightBlue = Color(0xFF4876C7);
  static const lightBlueSoft = Color(0xFF7896E8);
  static const lightBlueDeep = Color(0xFF172D70);
  static const safetyBlue = lightBlue;

  // Semantic states.
  static const success = Color(0xFF2F8F5B);
  static const successDeep = Color(0xFF1E6340);
  static const successBright = Color(0xFF45B879);
  static const successSoft = Color(0xFF8FD5AD);
  static const warning = Color(0xFFC88A34);
  static const warningDeep = Color(0xFF885C21);
  static const danger = Color(0xFFB53A48);
  static const dangerDeep = Color(0xFF7B2631);
  static const dangerBright = Color(0xFFD95A67);
  static const premium = imperialPurpleSoft;

  // Borders.
  static const goldBorder = Color(0xFF806A32);
  static const goldBorderBright = Color(0xFFB89A46);

  static const metallicGradient = <Color>[
    royalBlueDeep,
    royalBlue,
    imperialPurple,
    imperialPurpleBright,
  ];

  static const ceremonialGradient = <Color>[royalBlue, imperialPurple, ruby];

  static const backgroundGradient = <Color>[bg, bgSecondary, Color(0xFF0C0913)];

  static const goldFoilGradient = <Color>[
    antiqueGoldDeep,
    antiqueGoldBright,
    Color(0xFFA98534),
  ];

  static const successGradient = <Color>[successDeep, successBright];
  static const rubyGradient = <Color>[rubyDeep, rubyBright];
}
