// Local visual review only. Synthetic jobs and disabled write repositories
// keep this preview isolated from production data.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/data/models/application.dart';
import 'package:flutter_mort/data/models/job.dart';
import 'package:flutter_mort/data/repositories/applications_repository.dart';
import 'package:flutter_mort/data/repositories/jobs_repository.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/features/teen/teen_marketplace_home_screen.dart';

void main() => runApp(const _PreviewApp());

final _router = GoRouter(
  initialLocation: '/teen/home',
  routes: [
    GoRoute(
      path: '/teen/home',
      builder: (_, _) => const TeenMarketplaceHomeScreen(),
    ),
    GoRoute(
      path: '/teen/explore',
      builder: (_, _) => const _PreviewPlaceholder(title: 'Explore'),
    ),
    GoRoute(
      path: '/teen/jobs/:id',
      builder: (_, state) => _PreviewPlaceholder(
        title: state.pathParameters['id'] ?? 'Job details',
      ),
    ),
    GoRoute(
      path: '/teen/applications/:id',
      builder: (_, state) => _PreviewPlaceholder(
        title: state.pathParameters['id'] ?? 'Application',
      ),
    ),
  ],
);

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
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: MortTheme.light(),
      routerConfig: _router,
    ),
  );
}

class _PreviewJobsController extends OpenJobsController {
  _PreviewJobsController(super.filters);

  @override
  Future<JobFeedState> build() async => const JobFeedState(
    items: [_yardJob, _organizingJob, _tutoringJob, _petCareJob],
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

class _PreviewPlaceholder extends StatelessWidget {
  const _PreviewPlaceholder({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: const Center(child: Text('Local visual preview only')),
  );
}

const _yardJob = Job(
  id: 'preview-yard',
  posterId: 'poster-janet',
  title: 'Tidy up the front garden',
  description: 'Collect leaves and sweep the front walk.',
  category: 'yard work',
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

const _organizingJob = Job(
  id: 'preview-organizing',
  posterId: 'poster-morgan',
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
  id: 'preview-tutoring',
  posterId: 'poster-alex',
  title: 'Practice middle-school math',
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

const _petCareJob = Job(
  id: 'preview-pet-care',
  posterId: 'poster-sam',
  title: 'Walk a friendly dog',
  description: 'A short neighborhood walk with a calm dog.',
  category: 'pet care',
  locationText: 'SoBro area',
  city: 'Indianapolis',
  state: 'IN',
  status: 'open',
  requiresGuardianApproval: false,
  posterName: 'Sam',
  estimatedDurationMinutes: 25,
  payAmountCents: 1800,
);
