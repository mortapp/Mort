import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/data/models/application.dart';
import 'package:flutter_mort/data/models/job.dart';

void main() {
  group('MortApplication live Supabase contract', () {
    test('maps job_applications applicant and cover_note fields', () {
      final application = MortApplication.fromMap({
        'id': 'application-id',
        'job_id': 'job-id',
        'applicant_id': 'teen-id',
        'status': 'submitted',
        'cover_note': 'I can help after school.',
        'guardian_id': null,
        'availability_confirmed': true,
        'created_at': '2026-10-27T12:00:00Z',
        'updated_at': '2026-10-27T12:00:00Z',
      });

      expect(application.teenId, 'teen-id');
      expect(application.note, 'I can help after school.');
      expect(application.availabilityConfirmed, isTrue);
    });
  });

  test('does not expose quick accept without an active backend capability', () {
    final job = Job.fromMap({
      'id': 'job-id',
      'poster_id': 'poster-id',
      'title': 'Yard work',
      'quick_accept_eligible': true,
    });

    expect(job.quickAcceptEligible, isFalse);
  });
}
