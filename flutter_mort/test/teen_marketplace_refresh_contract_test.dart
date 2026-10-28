import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/data/models/job.dart';
import 'package:flutter_mort/features/teen/teen_marketplace_home.dart';
import 'package:flutter_mort/features/teen/teen_shell.dart';

Job _job(String id, int? duration) => Job(
  id: id,
  posterId: 'poster-$id',
  title: 'Local task $id',
  description: 'A real published job',
  category: 'Yard work',
  locationText: 'General area',
  city: 'Indianapolis',
  state: 'IN',
  status: 'open',
  requiresGuardianApproval: false,
  estimatedDurationMinutes: duration,
);

void main() {
  test('teen primary destinations follow the four-tab product spec', () {
    expect(
      teenPrimaryDestinations.map((destination) => destination.label),
      ['Home', 'Explore', 'Inbox', 'Profile'],
    );
  });

  test('Quick Jobs includes only jobs with a known duration under 30 minutes', () {
    final quickJobs = selectQuickJobs([
      _job('short', 20),
      _job('boundary', 30),
      _job('unknown', null),
    ]);

    expect(quickJobs.map((job) => job.id), ['short']);
  });
}
