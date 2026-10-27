import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/data/models/job.dart';

void main() {
  test(
    'public job area never falls back to an address-like location string',
    () {
      const job = Job(
        id: 'job-1',
        posterId: 'poster-1',
        title: 'Yard cleanup',
        description: '',
        category: 'yard work',
        locationText: '123 Exact Street',
        city: 'Indianapolis',
        state: 'IN',
        status: 'open',
        requiresGuardianApproval: false,
      );

      expect(job.publicAreaDisplay, 'Indianapolis, IN');
    },
  );

  test('public job area prefers the approximate neighborhood', () {
    const job = Job(
      id: 'job-1',
      posterId: 'poster-1',
      title: 'Yard cleanup',
      description: '',
      category: 'yard work',
      locationText: '123 Exact Street',
      city: 'Indianapolis',
      state: 'IN',
      neighborhood: 'Broad Ripple',
      status: 'open',
      requiresGuardianApproval: false,
    );

    expect(job.publicAreaDisplay, 'Broad Ripple');
  });

  test('public job area rejects a street address in neighborhood data', () {
    const job = Job(
      id: 'job-1',
      posterId: 'poster-1',
      title: 'Yard cleanup',
      description: '',
      category: 'yard work',
      locationText: '123 Exact Street',
      city: 'Indianapolis',
      state: 'IN',
      neighborhood: '123 Exact Street',
      status: 'open',
      requiresGuardianApproval: false,
    );

    expect(job.publicAreaDisplay, 'Indianapolis, IN');
  });
}
