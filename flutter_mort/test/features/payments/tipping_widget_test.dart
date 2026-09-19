import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/features/payments/models/tipping.dart';

void main() {
  group('tipping rules', () {
    test('includes the approved tip presets and custom option', () {
      expect(
        MortTipPreset.values,
        containsAll([
          MortTipPreset.none,
          MortTipPreset.two,
          MortTipPreset.five,
          MortTipPreset.ten,
          MortTipPreset.tenPercent,
          MortTipPreset.fifteenPercent,
          MortTipPreset.twentyPercent,
          MortTipPreset.custom,
          MortTipPreset.lateTip,
        ]),
      );
    });

    test('tip is 100% teen-directed and excluded from fees & Fair Pay', () {
      const jobTotal = 2500;
      const tip = MortTipSelection(
        preset: MortTipPreset.tenPercent,
        amountCents: 250,
      );

      expect(tip.amountCents, 250);
      expect(tip.toTeenCents(jobTotal), 250);
      expect(tip.excludesFeeFromFairPay, isTrue);
      expect(tip.excludesTipFromServiceFee, isTrue);
    });

    test('custom tip supports values over one dollar', () {
      const tip = MortTipSelection(
        preset: MortTipPreset.custom,
        amountCents: 1250,
      );

      expect(tip.amountCents, 1250);
      expect(tip.isCustom, isTrue);
    });

    test('percentage tips use nearest-cent integer rounding', () {
      expect(
        MortTipSelection.percentage(MortTipPreset.tenPercent, 999).amountCents,
        100,
      );
      expect(
        MortTipSelection.percentage(
          MortTipPreset.fifteenPercent,
          999,
        ).amountCents,
        150,
      );
      expect(
        MortTipSelection.percentage(
          MortTipPreset.twentyPercent,
          999,
        ).amountCents,
        200,
      );
      expect(
        MortTipSelection.percentage(MortTipPreset.tenPercent, 1001).amountCents,
        100,
      );
      expect(
        MortTipSelection.percentage(
          MortTipPreset.fifteenPercent,
          1001,
        ).amountCents,
        150,
      );
      expect(
        MortTipSelection.percentage(
          MortTipPreset.twentyPercent,
          1001,
        ).amountCents,
        200,
      );
      expect(
        MortTipSelection.percentage(
          MortTipPreset.fifteenPercent,
          2200,
        ).amountCents,
        330,
      );
      expect(parseMortCurrencyToCents(r'$7.50'), 750);
      expect(parseMortCurrencyToCents('7.5'), 750);
      expect(parseMortCurrencyToCents('7'), 700);
      expect(parseMortCurrencyToCents('1,250.75'), 125075);
      expect(parseMortCurrencyToCents(r'$1,250.75'), 125075);
      expect(parseMortCurrencyToCents('7.505'), isNull);
      expect(parseMortCurrencyToCents('-1.00'), isNull);
      expect(parseMortCurrencyToCents('not money'), isNull);
      expect(parseMortCurrencyToCents(r'7$50'), isNull);
      expect(parseMortCurrencyToCents('1,2,3'), isNull);
      expect(parseMortCurrencyToCents(r'$$7.50'), isNull);
    });

    test('custom tip validation is typed and fails closed without policy', () {
      const policy = MortTipPolicy(
        minTipCents: 200,
        maxTipCents: 10000,
        backendAuthoritative: true,
      );
      expect(
        validateMortCustomTip('', policy).state,
        MortTipValidationState.empty,
      );
      expect(
        validateMortCustomTip(r'$', policy).state,
        MortTipValidationState.typing,
      );
      expect(
        validateMortCustomTip('7.', policy).state,
        MortTipValidationState.typing,
      );
      expect(
        validateMortCustomTip(r'$7.', policy).state,
        MortTipValidationState.typing,
      );
      expect(
        validateMortCustomTip('1,', policy).state,
        MortTipValidationState.typing,
      );
      expect(
        validateMortCustomTip('1,2', policy).state,
        MortTipValidationState.typing,
      );
      expect(
        validateMortCustomTip('1,25', policy).state,
        MortTipValidationState.typing,
      );
      expect(
        validateMortCustomTip('abc.', policy).state,
        MortTipValidationState.invalid,
      );
      expect(
        validateMortCustomTip('abc,', policy).state,
        MortTipValidationState.invalid,
      );
      expect(
        validateMortCustomTip(r'7$.', policy).state,
        MortTipValidationState.invalid,
      );
      expect(
        validateMortCustomTip(r'$$.', policy).state,
        MortTipValidationState.invalid,
      );
      expect(
        validateMortCustomTip('1,,', policy).state,
        MortTipValidationState.invalid,
      );
      expect(
        validateMortCustomTip('1,,2', policy).state,
        MortTipValidationState.invalid,
      );
      expect(
        validateMortCustomTip(r'$1,,2', policy).state,
        MortTipValidationState.invalid,
      );
      expect(
        validateMortCustomTip('1,2,3', policy).state,
        MortTipValidationState.invalid,
      );
      expect(
        validateMortCustomTip('1.00', policy).state,
        MortTipValidationState.tooLow,
      );
      expect(
        validateMortCustomTip('100.01', policy).state,
        MortTipValidationState.tooHigh,
      );
      expect(
        validateMortCustomTip('7.50', policy).state,
        MortTipValidationState.valid,
      );
      expect(
        validateMortCustomTip('bad', policy).state,
        MortTipValidationState.invalid,
      );
      expect(validateMortCustomTip(r'$', policy).canConfirm, isFalse);
      expect(validateMortCustomTip('7.50', policy).canConfirm, isTrue);
      expect(validateMortCustomTip('7.50', null).canConfirm, isFalse);
      expect(
        validateMortCustomTip(
          '7.50',
          const MortTipPolicy(
            minTipCents: 200,
            maxTipCents: 10000,
            backendAuthoritative: false,
          ),
        ).canConfirm,
        isFalse,
      );
    });
  });
}
