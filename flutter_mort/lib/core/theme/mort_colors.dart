import 'package:flutter/material.dart';

/// Prototype-aligned neutral palette. Compatibility aliases remain so older
/// screens inherit the new direction until their component APIs are renamed.
class MortColors {
  const MortColors._();

  // Neutral ramp. Use semantic colors only for positive, held, and emergency
  // states; the rest of the interface stays black, white, and gray.
  static const white = Color(0xFFFFFFFF);
  static const gray0 = Color(0xFFFAFAFA);
  static const gray1 = Color(0xFFF5F5F5);
  static const gray2 = Color(0xFFE6E6E6);
  static const gray3 = Color(0xFFD1D1D1);
  static const gray4 = Color(0xFFB8B8B8);
  static const gray5 = Color(0xFF9E9E9E);
  static const gray6 = Color(0xFF858585);
  static const gray7 = Color(0xFF6B6B6B);
  static const gray8 = Color(0xFF525252);
  static const gray9 = Color(0xFF333333);
  static const black = Color(0xFF0A0A0A);

  // Compatibility brand names now resolve to neutral values.
  static const godBlack = black;
  static const softBlack = gray9;
  static const raisedBlack = gray1;
  static const godWhite = black;
  static const softWhite = gray8;
  static const silver = gray7;
  // Legacy `silverBright` is used by older screens for primary text/icons.
  // Keep it high contrast on the new white surface instead of near-white.
  static const silverBright = black;
  static const silverDark = gray8;
  static const roseGold = gray7;
  static const roseGoldDeep = gray9;
  static const roseGoldBright = gray3;
  static const roseGoldHighlight = white;
  static const roseGoldShadow = gray9;
  static const roseGoldVeryDark = gray9;
  static const roseGoldLight = gray3;
  static const roseGoldDark = gray8;
  static const roseGoldMid = gray6;
  static const neon = black;
  static const neonDeep = gray8;
  static const babyBlue = gray3;
  static const babyBlueDeep = gray7;
  static const babyBlueSoft = gray1;
  static const lightBlue = gray7;
  static const lightBlueSoft = gray3;
  static const lightBlueDeep = gray9;
  static const safetyBlue = gray7;
  static const godPink = gray6;
  static const godPinkSoft = gray4;
  static const godPinkDeep = gray8;

  static const bg = white;
  static const bgSecondary = gray0;
  static const bgElevated = white;
  static const card = white;
  static const cardAlt = gray0;
  static const glass = gray0;
  static const glassPressed = gray1;
  static const line = gray2;
  static const lineStrong = gray3;

  static const text = black;
  static const textSoft = gray8;
  static const textMuted = gray7;
  static const textDisabled = gray5;

  // Semantic state colors from the prototype.
  static const success = Color(0xFF18845B);
  static const successDeep = Color(0xFF126846);
  static const successSoft = Color(0xFFDDF3E9);
  static const warning = Color(0xFF9A5C00);
  static const danger = Color(0xFFC62828);
  static const dangerDeep = Color(0xFFB71C1C);

  // Payment OS tokens are an approved semantic surface system, kept separate
  // from the prototype's monochrome app chrome.
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
  static const premium = black;

  static const metallicGradient = <Color>[black, black];
  static const darkRoseGoldGradient = <Color>[black, black];
  static const backgroundGradient = <Color>[white, white];
  static const silverMetallicGradient = <Color>[gray5, gray3, gray5];
  static const babyBlueGradient = <Color>[gray7, gray5, gray3];
  static const godPinkGradient = <Color>[gray9, gray6, gray3];
  static const signatureGradient = <Color>[gray7, gray3, gray7];
  static const accent = black;
}
