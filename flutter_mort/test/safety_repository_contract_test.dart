import 'package:flutter_mort/data/repositories/safety_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('report reasons map to categories accepted by the live backend', () {
    const accepted = {
      'harassment',
      'unsafe_meeting',
      'scam',
      'inappropriate_content',
      'privacy',
      'underage_concern',
      'payment',
      'other',
    };
    for (final reason in [
      'unsafe_job',
      'scam',
      'contact_sharing',
      'harassment',
      'threats',
      'stalking',
      'sexual_content',
      'grooming_exploitation',
      'private_images',
      'weapons_substances',
      'other',
    ]) {
      expect(
        accepted,
        contains(SafetyRepository.reportCategoryForReason(reason)),
      );
    }
  });

  test('safety report severity uses live backend values', () {
    expect(
      SafetyRepository.reportSeverityForReason(
        'unsafe_job',
        immediateDanger: false,
      ),
      'normal',
    );
    expect(
      SafetyRepository.reportSeverityForReason(
        'threats',
        immediateDanger: false,
      ),
      'high',
    );
    expect(
      SafetyRepository.reportSeverityForReason(
        'unsafe_job',
        immediateDanger: true,
      ),
      'critical',
    );
  });
}
