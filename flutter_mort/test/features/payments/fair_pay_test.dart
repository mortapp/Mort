import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/features/payments/models/fair_pay.dart';
import 'package:flutter_mort/features/jobs/job_creation_flow.dart';

void main() {
  group('fair pay', () {
    test(
      'classifies green, yellow, and red bands with hard minimum enforcement',
      () {
        final green = MortFairPayAssessment(
          recommendedRangeCents: const RangeValues(1500, 2500),
          hardMinimumCents: 1200,
          actualCents: 1800,
        );
        final yellow = MortFairPayAssessment(
          recommendedRangeCents: const RangeValues(1500, 2500),
          hardMinimumCents: 1200,
          actualCents: 1300,
        );
        final red = MortFairPayAssessment(
          recommendedRangeCents: const RangeValues(1500, 2500),
          hardMinimumCents: 1200,
          actualCents: 1000,
        );

        expect(green.status, MortFairPayStatus.green);
        expect(yellow.status, MortFairPayStatus.yellow);
        expect(red.status, MortFairPayStatus.red);
        expect(red.blocksContinue, isTrue);
        expect(green.blocksContinue, isFalse);
      },
    );

    test('backend remains authoritative and a red band blocks continue', () {
      const assessment = MortFairPayAssessment(
        recommendedRangeCents: RangeValues(2000, 3000),
        hardMinimumCents: 1500,
        actualCents: 1200,
        backendAuthoritative: true,
      );

      expect(assessment.backendAuthoritative, isTrue);
      expect(assessment.blocksContinue, isTrue);
    });

    test(
      'the real job creation gate blocks red or non-authoritative policy',
      () {
        const red = MortFairPayAssessment(
          recommendedRangeCents: RangeValues(2000, 3000),
          hardMinimumCents: 1500,
          actualCents: 1200,
        );
        const unavailable = MortFairPayAssessment(
          recommendedRangeCents: RangeValues(2000, 3000),
          hardMinimumCents: 1500,
          actualCents: 2200,
          backendAuthoritative: false,
        );
        expect(MortJobCreationFairPayGate.canContinue(red), isFalse);
        expect(MortJobCreationFairPayGate.canContinue(unavailable), isFalse);
      },
    );

    test('authoritative yellow policy controls both gates', () {
      const yellowAllowed = MortFairPayAssessment(
        recommendedRangeCents: RangeValues(2000, 3000),
        hardMinimumCents: 1500,
        actualCents: 1800,
        yellowMayContinue: true,
      );
      const yellowBlocked = MortFairPayAssessment(
        recommendedRangeCents: RangeValues(2000, 3000),
        hardMinimumCents: 1500,
        actualCents: 1800,
        yellowMayContinue: false,
      );

      expect(MortJobCreationFairPayGate.canContinue(yellowAllowed), isTrue);
      expect(MortJobCreationFairPayGate.canPublish(yellowAllowed), isTrue);
      expect(MortJobCreationFairPayGate.canContinue(yellowBlocked), isFalse);
      expect(MortJobCreationFairPayGate.canPublish(yellowBlocked), isFalse);
    });
  });
}
