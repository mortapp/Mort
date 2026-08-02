import 'package:flutter/material.dart';

class MortColors {
  const MortColors._();

  static const bg = Color(0xFF050505);
  static const bgSecondary = Color(0xFF0B0909);
  static const bgElevated = Color(0xFF121010);
  static const card = Color(0xB31A1515);
  static const cardAlt = Color(0xD9241C1B);
  static const glass = Color(0xA6181414);
  static const glassPressed = Color(0xD12B211F);
  static const line = Color(0x664E3A36);
  static const lineStrong = Color(0xA8734F47);

  static const text = Color(0xFFFFF8F5);
  static const textSoft = Color(0xFFCBBAB5);
  static const textMuted = Color(0xFF9B8C88);
  static const textDisabled = Color(0xFF685E5B);

  static const roseGold = Color(0xFFF4A78F);
  static const roseGoldLight = Color(0xFFFFD1C3);
  static const roseGoldDark = Color(0xFF9B5145);
  static const roseGoldMid = Color(0xFFC97865);
  static const roseGoldDeep = Color(0xFF3B1E1A);

  // Kept as compatibility aliases so existing feature screens inherit the
  // redesign without maintaining a second color language.
  static const neon = roseGold;
  static const neonDeep = roseGoldDeep;

  // Light blue is reserved for information, safety, location, and verified
  // system state. It stays secondary to MORT's rose-gold brand.
  static const lightBlue = Color(0xFF78CAFF);
  static const lightBlueSoft = Color(0xFFB9E5FF);
  static const lightBlueDeep = Color(0xFF12344A);
  static const safetyBlue = lightBlue;

  static const success = Color(0xFF79D7A5);
  static const warning = Color(0xFFFFC36A);
  static const danger = Color(0xFFFF6F7D);
  static const premium = Color(0xFFC7A8FF);

  static const metallicGradient = <Color>[
    roseGoldDark,
    roseGold,
    roseGoldLight,
    roseGoldMid,
  ];

  static const backgroundGradient = <Color>[bg, bgSecondary, Color(0xFF090707)];
}
