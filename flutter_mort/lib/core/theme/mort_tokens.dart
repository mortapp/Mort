import 'package:flutter/material.dart';

import 'mort_colors.dart';

class MortRadii {
  const MortRadii._();

  static const small = 10.0;
  static const medium = 14.0;
  static const card = 16.0;
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

  static const micro = Duration(milliseconds: 120);
  static const control = Duration(milliseconds: 180);
  static const content = Duration(milliseconds: 240);
  static const reveal = Duration(milliseconds: 420);

  static const standardCurve = Curves.easeOutCubic;
  static const exitCurve = Curves.easeInCubic;

  // Compatibility names retained while call sites move to intent-based tokens.
  static const quick = Duration(milliseconds: 140);
  static const standard = content;
  static const emphasized = reveal;
}

class MortIconSizes {
  const MortIconSizes._();

  static const small = 16.0;
  static const standard = 22.0;
  static const large = 28.0;
}

class MortShadows {
  const MortShadows._();

  /// Deep black elevation with a barely-there silver rim — polished dark
  /// material, never a colored bloom.
  static const card = <BoxShadow>[
    BoxShadow(color: Color(0x99000000), blurRadius: 26, offset: Offset(0, 12)),
    BoxShadow(color: Color(0x14D6DAE0), blurRadius: 1, offset: Offset(0, -1)),
  ];

  /// Silver specular bloom for the primary CTA — reads as light reflecting
  /// off polished metal, not a cobalt neon halo.
  static const glow = <BoxShadow>[
    BoxShadow(color: Color(0x2ED6DAE0), blurRadius: 18),
    BoxShadow(color: Color(0x59000000), blurRadius: 26, offset: Offset(0, 10)),
  ];
}

class MortGradients {
  const MortGradients._();

  /// Restrained cobalt CTA: dark edges, a short brighter-blue reflection,
  /// and no white/ice hotspot.
  static const metallic = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: MortColors.metallicGradient,
    stops: [0, 0.30, 0.52, 0.58, 1],
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

  /// Graphite-black glass — surfaces stay neutral; midnight blue lives in
  /// the atmosphere layer only.
  static const glass = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xE0080A0D), Color(0xE0090B0F), Color(0xF0000208)],
  );

  static const infoGlass = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xF2090B0F), Color(0xF207090C)],
  );
}
