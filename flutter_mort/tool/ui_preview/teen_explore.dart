// Local visual review only. This is not the app entry point and uses synthetic
// jobs with backend writes disabled so the production backend is never touched.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/data/models/application.dart';
import 'package:flutter_mort/data/models/job.dart';
import 'package:flutter_mort/data/repositories/applications_repository.dart';
import 'package:flutter_mort/data/repositories/jobs_repository.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/features/jobs/teen_job_screens.dart';

void main() => runApp(const _PreviewApp());

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      openJobsProvider.overrideWith2(_PreviewJobsController.new),
      jobsRepositoryProvider.overrideWithValue(_PreviewJobsRepository()),
      applicationsRepositoryProvider.overrideWithValue(
        _PreviewApplicationsRepository(),
      ),
      savedJobIdsProvider.overrideWith((ref) async => <String>{}),
      interestedJobIdsProvider.overrideWith((ref) async => <String>{}),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: MortTheme.light(),
      home: const TeenJobFeedScreen(),
    ),
  );
}

class _PreviewJobsController extends OpenJobsController {
  _PreviewJobsController(super.filters);

  @override
  Future<JobFeedState> build() async => const JobFeedState(
    items: [_quickJob, _nearbyJob, _tutoringJob],
    hasMore: false,
  );
}

class _PreviewJobsRepository extends JobsRepository {
  @override
  Future<List<Job>> listSavedJobs() async => const [];

  @override
  Future<void> saveJob(String jobId) async {}

  @override
  Future<void> unsaveJob(String jobId) async {}

  @override
  Future<void> setJobInterest(String jobId, {required bool interested}) async {}
}

class _PreviewApplicationsRepository extends ApplicationsRepository {
  @override
  Future<ApplicationEligibility> checkEligibility(String jobId) async =>
      const ApplicationEligibility(
        eligible: false,
        code: 'preview_only',
        message: 'Applications are disabled in this visual preview.',
        guardianRequiredForThisJob: false,
        guardianLinked: false,
      );
}

const _quickJob = Job(
  id: 'quick-preview-job',
  posterId: 'poster-1',
  title: 'Yard cleanup',
  description: 'Collect leaves and tidy the front garden.',
  category: 'lawn care',
  locationText: 'Broad Ripple area',
  city: 'Indianapolis',
  state: 'IN',
  status: 'open',
  requiresGuardianApproval: false,
  posterName: 'Janet',
  posterVerificationStatus: 'approved',
  estimatedDurationMinutes: 20,
  payAmountCents: 2500,
);

const _nearbyJob = Job(
  id: 'nearby-preview-job',
  posterId: 'poster-2',
  title: 'Help organize a garage',
  description: 'Sort boxes and sweep the floor.',
  category: 'organization',
  locationText: 'Meridian-Kessler area',
  city: 'Indianapolis',
  state: 'IN',
  status: 'open',
  requiresGuardianApproval: false,
  posterName: 'Morgan',
  estimatedDurationMinutes: 45,
  payAmountCents: 3200,
);

const _tutoringJob = Job(
  id: 'tutoring-preview-job',
  posterId: 'poster-3',
  title: 'Help with middle-school math',
  description: 'Work through practice problems together.',
  category: 'tutoring',
  locationText: 'Near Broad Ripple',
  city: 'Indianapolis',
  state: 'IN',
  status: 'open',
  requiresGuardianApproval: false,
  posterName: 'Alex',
  estimatedDurationMinutes: 60,
  payAmountCents: 2200,
);
