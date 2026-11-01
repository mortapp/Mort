import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/data/models/production_backend_rows.dart';

void main() {
  test(
    'repository table contracts match the authoritative production names',
    () {
      expect(productionGuardianLinksTable, 'guardian_links');
      expect(productionUserBlocksTable, 'user_blocks');
      expect(productionSafetyReportsTable, 'safety_reports');
    },
  );

  group('mapProductionGuardianLink', () {
    test(
      'maps a pending production link to the invitation state expected by UI',
      () {
        final result = mapProductionGuardianLink({
          'id': 'link-1',
          'status': 'pending',
          'teen_user_id': 'teen-1',
          'guardian_user_id': null,
          'teen_consent_at': null,
          'guardian_consent_at': null,
          'updated_at': '2026-10-31T12:00:00Z',
          'teen': {'id': 'teen-1', 'display_name': 'Teen'},
          'guardian': null,
          'guardian_preferences': [],
        });

        expect(result['id'], 'link-1');
        expect(result['status'], 'invited');
        expect(result['teen'], {'id': 'teen-1', 'display_name': 'Teen'});
        expect(result['guardian'], isNull);
        expect(result['accepted_at'], isNull);
        expect(result['guardian_preferences'], isEmpty);
        expect(result.containsKey('invite_code'), isFalse);
      },
    );

    test('uses the consent timestamp for an active production link', () {
      final result = mapProductionGuardianLink({
        'id': 'link-2',
        'status': 'active',
        'teen_user_id': 'teen-2',
        'guardian_user_id': 'guardian-2',
        'teen_consent_at': '2026-10-30T10:00:00Z',
        'guardian_consent_at': '2026-10-30T11:00:00Z',
        'updated_at': '2026-10-30T11:00:00Z',
        'teen': {'id': 'teen-2'},
        'guardian': {'id': 'guardian-2'},
        'guardian_preferences': [],
      });

      expect(result['status'], 'active');
      expect(result['accepted_at'], '2026-10-30T11:00:00Z');
      expect(result['guardian_user_id'], 'guardian-2');
    });
  });

  test(
    'maps production safety-report category to the activity reason field',
    () {
      final result = mapProductionSafetyReport({
        'id': 'report-1',
        'category': 'unsafe_meeting',
        'status': 'open',
        'created_at': '2026-10-31T09:00:00Z',
      });

      expect(result['reason'], 'unsafe_meeting');
      expect(result['status'], 'open');
      expect(result['id'], 'report-1');
    },
  );
}
