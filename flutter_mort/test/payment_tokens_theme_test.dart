import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_colors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('payment tokens', () {
    test('use neutral state colors and readable receipt surfaces', () {
      for (final state in [
        MortColors.paymentSuccess,
        MortColors.paymentDanger,
        MortColors.paymentWarning,
        MortColors.paymentInfo,
      ]) {
        expect(state, MortClassicColors.foreground);
      }
      expect(MortColors.receiptPaper, MortClassicColors.surface);
      expect(MortColors.receiptInk, MortClassicColors.foreground);
      expect(MortColors.receiptMutedInk, MortClassicColors.muted);
      expect(MortColors.receiptRule, MortClassicColors.line);
      expect(MortColors.receiptEdge, MortClassicColors.line);
      expect(MortColors.paymentSilverHigh, const Color(0xFFEDEDED));
      expect(MortColors.paymentSilverMid, const Color(0xFFCCCCCC));
      expect(MortColors.paymentSilverLow, const Color(0xFFA5A5A5));
      expect(MortColors.paymentOnSilver, MortClassicColors.ink);
      expect(MortColors.paymentSilverCta, MortColors.paymentSilverHigh);
    });
  });
}
