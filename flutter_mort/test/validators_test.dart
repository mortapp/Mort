import 'package:flutter_mort/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MortValidators', () {
    test('validates email shape without accepting incomplete addresses', () {
      expect(MortValidators.email('teen@example.com'), isNull);
      expect(MortValidators.email('teen@'), isNotNull);
      expect(MortValidators.email(''), isNotNull);
    });

    test('enforces password minimum length', () {
      expect(MortValidators.password('Short1!'), isNotNull);
      expect(MortValidators.password('longbutnocaps1!'), isNotNull);
      expect(MortValidators.password('LongAndSecure1!'), isNull);
      expect(
        MortValidators.password(
          'legacy',
          minimumLength: 6,
          requireComplexity: false,
        ),
        isNull,
      );
    });

    test('accepts only two-letter state codes', () {
      expect(MortValidators.stateCode('IN'), isNull);
      expect(MortValidators.stateCode('Indiana'), isNotNull);
      expect(MortValidators.stateCode('1N'), isNotNull);
    });

    test('converts decimal dollars to cents without truncating', () {
      expect(MortValidators.dollarAmount('12.50'), isNull);
      expect(MortValidators.dollarsToCents('12.50'), 1250);
      expect(MortValidators.dollarAmount('-1'), isNotNull);
      expect(MortValidators.dollarAmount('1.999'), isNotNull);
    });

    test('flags explicit high-risk job terms', () {
      expect(
        MortValidators.teenSafeJobText('Help me with roofing this weekend'),
        contains('roofing'),
      );
      expect(
        MortValidators.teenSafeJobText('Water plants in the front yard'),
        isNull,
      );
    });
  });
}
