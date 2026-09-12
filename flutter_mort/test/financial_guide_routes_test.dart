import 'package:flutter_mort/core/utils/safe_uri.dart';
import 'package:flutter_mort/features/guide/mort_guide_screens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Guide source-card routing into Financial Safety', () {
    test('financial routes are allowed internal help routes', () {
      expect(safeInternalHelpRoute('/financial'), '/financial');
      expect(
        safeInternalHelpRoute('/financial/benefits'),
        '/financial/benefits',
      );
      expect(
        safeInternalHelpRoute('/financial/expenses'),
        '/financial/expenses',
      );
    });

    test('non-financial guards still apply', () {
      expect(safeInternalHelpRoute('/financial/../secret'), isNull);
      expect(safeInternalHelpRoute('https://evil.example/financial'), isNull);
      expect(safeInternalHelpRoute('/unmapped/route'), isNull);
      expect(safeInternalHelpRoute('/support/chat'), '/support/chat');
    });
  });

  group('MORT Guide financial integration', () {
    test(
      'suggested questions include earnings-safety and benefits prompts',
      () {
        const questions = MortGuideSuggestedQuestions.questions;
        expect(questions, contains('Why did I get an earnings alert?'));
        expect(
          questions,
          contains('My mom says I need to stop working because we get SNAP.'),
        );
        expect(questions, contains('How do I record an expense or receipt?'));
      },
    );

    test('suggested questions never suggest evasion', () {
      for (final question in MortGuideSuggestedQuestions.questions) {
        final lowered = question.toLowerCase();
        expect(lowered.contains('hide'), isFalse);
        expect(lowered.contains('avoid reporting'), isFalse);
        expect(lowered.contains('1099'), isFalse);
        expect(lowered.contains('tax-free'), isFalse);
        expect(lowered.contains('split payments'), isFalse);
      }
    });
  });
}
