import 'package:flutter/material.dart';

import 'mort_colors.dart';

class MortRadii {
  const MortRadii._();

  static const small = 10.0;
  static const medium = 14.0;
  static const card = 20.0;
  static const sheet = 28.0;
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
    BoxShadow(color: Color(0x16C89686), blurRadius: 18),
  ];

  static const glow = <BoxShadow>[
    BoxShadow(color: Color(0x45F4A78F), blurRadius: 28),
    BoxShadow(color: Color(0x2478CAFF), blurRadius: 42),
  ];
}

class MortGradients {
  const MortGradients._();

  static const metallic = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: MortColors.metallicGradient,
    stops: [0, 0.38, 0.62, 1],
  );

  static const background = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: MortColors.backgroundGradient,
  );

  static const glass = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xD92A272B), Color(0xD917171A), Color(0xE01F1D21)],
  );

  static const infoGlass = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xF20C1B24), Color(0xF2121010)],
  );
}
