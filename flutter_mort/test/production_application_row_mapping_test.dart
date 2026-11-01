import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/data/models/application.dart';

void main() {
  test('maps production job_applications column names', () {
    final application = MortApplication.fromMap({
      'id': 'application-1',
      'job_id': 'job-1',
      'applicant_id': 'teen-1',
      'status': 'shortlisted',
      'cover_note': 'I can help after school.',
      'guardian_id': 'guardian-1',
      'availability_confirmed': true,
      'created_at': '2026-10-30T12:00:00Z',
      'updated_at': '2026-10-30T13:00:00Z',
    });

    expect(application.teenId, 'teen-1');
    expect(application.note, 'I can help after school.');
    expect(application.guardianId, 'guardian-1');
    expect(application.status, 'shortlisted');
  });

  test('continues to map the authorized current-user RPC shape', () {
    final application = MortApplication.fromMap({
      'id': 'application-2',
      'job_id': 'job-2',
      'teen_id': 'teen-2',
      'status': 'accepted',
      'note': 'I can help.',
    });

    expect(application.teenId, 'teen-2');
    expect(application.note, 'I can help.');
  });
}
