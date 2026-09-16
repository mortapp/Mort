import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_colors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('payment tokens', () {
    test('expose the exact approved Payment OS semantic colors', () {
      expect(MortColors.paymentSuccess, const Color(0xFF46C483));
      expect(MortColors.paymentDanger, const Color(0xFFE5605E));
      expect(MortColors.paymentWarning, const Color(0xFFD9A94F));
      expect(MortColors.paymentInfo, const Color(0xFF8FB4D9));

      expect(MortColors.receiptPaper, const Color(0xFFF3F0E7));
      expect(MortColors.receiptInk, const Color(0xFF191D22));
      expect(MortColors.receiptMutedInk, const Color(0xFF4E5560));
      expect(MortColors.receiptRule, const Color(0xFFC9C3B2));
      expect(MortColors.receiptEdge, const Color(0xFFDDD8C9));

      expect(MortColors.paymentSilverHigh, const Color(0xFFE9EEF4));
      expect(MortColors.paymentSilverMid, const Color(0xFFC4CDD7));
      expect(MortColors.paymentSilverLow, const Color(0xFF9BA6B2));
      expect(MortColors.paymentOnSilver, const Color(0xFF0B0E13));
      expect(MortColors.paymentSilverCta, const Color(0xFFE9EEF4));
    });
  });
}
