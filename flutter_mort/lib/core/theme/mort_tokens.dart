import 'package:flutter/material.dart';

import 'mort_colors.dart';

class MortRadii {
  const MortRadii._();

  static const small = 10.0;
  static const medium = 14.0;
  static const card = 12.0;
  static const sheet = 20.0;
  static const pill = 999.0;
}

class MortGlassTokens {
  const MortGlassTokens._();

  static const opacity = 0.76;
  static const pressedOpacity = 0.9;
  static const blurSigma = 22.0;
  static const borderWidth = 1.0;
}

class MortMotion {
  const MortMotion._();

  static const quick = Duration(milliseconds: 140);
  static const standard = Duration(milliseconds: 240);
  static const emphasized = Duration(milliseconds: 420);
}

class MortIconSizes {
  const MortIconSizes._();

  static const small = 16.0;
  static const standard = 22.0;
  static const large = 28.0;
}

class MortShadows {
  const MortShadows._();

  static const card = <BoxShadow>[
    BoxShadow(color: Color(0x80000000), blurRadius: 26, offset: Offset(0, 12)),
    BoxShadow(color: Color(0x1CD98C8C), blurRadius: 18),
  ];

  static const glow = <BoxShadow>[
    BoxShadow(color: Color(0x45F0AAA3), blurRadius: 28),
    BoxShadow(color: Color(0x2475C7F7), blurRadius: 42),
  ];
}

class MortGradients {
  const MortGradients._();

  /// Primary metallic Rose Gold: dark edge -> deep -> core -> a narrow
  /// bright highlight band -> core -> deep -> dark edge. The narrow
  /// highlight (tightly clustered stops around 0.5) is what reads as a
  /// specular reflection off polished metal instead of a flat pink fill.
  static const metallic = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: MortColors.metallicGradient,
    stops: [0, 0.18, 0.38, 0.5, 0.62, 0.82, 1],
  );

  static const darkRoseGold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: MortColors.darkRoseGoldGradient,
  );

  static const background = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: MortColors.backgroundGradient,
  );

  static const silverMetallic = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: MortColors.silverMetallicGradient,
  );

  static const babyBlue = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: MortColors.babyBlueGradient,
  );

  static const godPink = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: MortColors.godPinkGradient,
  );

  /// Use very selectively -- not the default CTA gradient.
  static const signature = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: MortColors.signatureGradient,
  );

  static const glass = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xD9151217), Color(0xD9111116), Color(0xE00A0A0D)],
  );

  static const infoGlass = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xF20D2432), Color(0xF2111116)],
  );
}
