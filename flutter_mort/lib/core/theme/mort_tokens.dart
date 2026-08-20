import 'package:flutter/material.dart';

import 'mort_colors.dart';

class MortRadii {
  const MortRadii._();

  static const small = 6.0;
  static const standard = 10.0;
  static const card = 12.0;
  static const medium = 12.0;
  static const container = 14.0;
  static const sheet = 16.0;
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
    BoxShadow(color: Color(0x8A05040A), blurRadius: 26, offset: Offset(0, 12)),
    BoxShadow(color: Color(0x1C2446A8), blurRadius: 18),
  ];

  static const glow = <BoxShadow>[
    BoxShadow(color: Color(0x453B64D9), blurRadius: 28),
    BoxShadow(color: Color(0x248A52B8), blurRadius: 42),
  ];

  static const goldGlow = <BoxShadow>[
    BoxShadow(color: Color(0x45C8A84E), blurRadius: 24),
  ];
}

class MortGradients {
  const MortGradients._();

  /// Primary royal gradient: Royal Blue -> Imperial Purple.
  static const metallic = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: MortColors.metallicGradient,
    stops: [0, 0.4, 0.72, 1],
  );

  /// Royal Blue -> Imperial Purple -> Ruby, for rare ceremonial moments.
  static const ceremonial = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: MortColors.ceremonialGradient,
  );

  static const background = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: MortColors.backgroundGradient,
  );

  static const glass = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xD9161225), Color(0xD912101A), Color(0xE00E0C16)],
  );

  static const infoGlass = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xF20E1830), Color(0xF2121010)],
  );

  static const goldFoil = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: MortColors.goldFoilGradient,
  );

  static const success = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: MortColors.successGradient,
  );

  static const ruby = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: MortColors.rubyGradient,
  );
}
