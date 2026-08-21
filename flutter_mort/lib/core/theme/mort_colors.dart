import 'package:flutter/material.dart';

class MortColors {
  const MortColors._();

  static const bg = Color(0xFF0A0A0C);
  static const bgSecondary = Color(0xFF101013);
  static const bgElevated = Color(0xFF17171A);
  static const card = Color(0xFF17171A);
  static const cardAlt = Color(0xFF222226);
  static const glass = Color(0xB31B191C);
  static const glassPressed = Color(0xE0242226);
  static const line = Color(0x14FFFFFF);
  static const lineStrong = Color(0x38FFFFFF);

  static const text = Color(0xFFF5F3F1);
  static const textSoft = Color(0xFFA9A7AB);
  static const textMuted = Color(0xFF8B8D93);
  static const textDisabled = Color(0xFF6C6A6E);

  static const roseGold = Color(0xFFC89686);
  static const roseGoldLight = Color(0xFFF1CAB4);
  static const roseGoldDark = Color(0xFF93685A);
  static const roseGoldMid = Color(0xFFB98272);
  static const roseGoldDeep = Color(0xFF38241F);
  static const silver = Color(0xFFCBCED3);

  // Kept as compatibility aliases so existing feature screens inherit the
  // redesign without maintaining a second color language.
  static const neon = roseGold;
  static const neonDeep = roseGoldDeep;

  // Light blue is reserved for information, safety, location, and verified
  // system state. It stays secondary to MORT's rose-gold brand.
  static const lightBlue = Color(0xFF7FC4EA);
  static const lightBlueSoft = Color(0xFFB9E5FF);
  static const lightBlueDeep = Color(0xFF16384B);
  static const safetyBlue = lightBlue;

  static const success = Color(0xFF33C48A);
  static const warning = Color(0xFFFFC36A);
  static const danger = Color(0xFFFF5A52);
  static const premium = Color(0xFFC7A8FF);

  static const metallicGradient = <Color>[
    roseGoldDark,
    roseGold,
    roseGoldLight,
    roseGoldMid,
  ];

  static const backgroundGradient = <Color>[bg, bgSecondary, Color(0xFF0C0B0E)];
}
