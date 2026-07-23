import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/models/application.dart';
import '../../data/models/job.dart';
import '../../data/models/profile.dart';
import '../../data/models/review.dart';
import '../../data/repositories/providers.dart';

class ActivityHistoryScreen extends ConsumerWidget {
  const ActivityHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).asData?.value;
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Account history',
          title: 'Your MORT activity',
          subtitle:
              'This view shows only activity available to your account. Admin records and other users\' private activity are excluded.',
        ),
        if (profile?.role == UserRole.teen)
          _ApplicationsHistory(
            future: ref
                .watch(applicationsRepositoryProvider)
                .listMyApplications(),
          ),
        if (profile?.role == UserRole.adult)
          _JobsHistory(future: ref.watch(jobsRepositoryProvider).listMyJobs()),
        if (profile?.role == UserRole.guardian)
          _GuardianHistory(
            future: ref.watch(guardianRepositoryProvider).listConnections(),
          ),
        const SizedBox(height: MortSpacing.md),
        _ReviewsHistory(
          future: ref.watch(reviewsRepositoryProvider).listReceived(),
        ),
        const SizedBox(height: MortSpacing.md),
        _ReportsHistory(
          future: ref.watch(safetyRepositoryProvider).listMyReports(),
        ),
      ],
    );
  }
}

class _ApplicationsHistory extends StatelessWidget {
  const _ApplicationsHistory({required this.future});

  final Future<List<MortApplication>> future;

  @override
  Widget build(BuildContext context) {
    return _HistorySection<MortApplication>(
      title: 'Applications and work',
      future: future,
      empty: 'No application activity yet.',
      item: (application) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.assignment_outlined),
        title: Text(application.job?.title ?? 'Application'),
        subtitle: Text(application.status.replaceAll('_', ' ')),
      ),
    );
  }
}

class _JobsHistory extends StatelessWidget {
  const _JobsHistory({required this.future});

  final Future<List<Job>> future;

  @override
  Widget build(BuildContext context) {
    return _HistorySection<Job>(
      title: 'Posted jobs',
      future: future,
      empty: 'No posted job activity yet.',
      item: (job) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.work_outline),
        title: Text(job.title),
        subtitle: Text(job.status.replaceAll('_', ' ')),
      ),
    );
  }
}

class _GuardianHistory extends StatelessWidget {
  const _GuardianHistory({required this.future});

  final Future<List<Map<String, dynamic>>> future;

  @override
  Widget build(BuildContext context) {
    return _HistorySection<Map<String, dynamic>>(
      title: 'Guardian links',
      future: future,
      empty: 'No Guardian Mode activity yet.',
      item: (row) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.family_restroom),
        title: Text('Guardian Mode connection'),
        subtitle: Text((row['status'] ?? 'unknown').toString()),
      ),
    );
  }
}

class _ReviewsHistory extends StatelessWidget {
  const _ReviewsHistory({required this.future});

  final Future<List<MortReview>> future;

  @override
  Widget build(BuildContext context) {
    return _HistorySection<MortReview>(
      title: 'Approved reviews received',
      future: future,
      empty: 'No approved reviews received yet.',
      item: (review) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.star_outline),
        title: Text('${review.rating} out of 5'),
        subtitle: review.body == null ? null : Text(review.body!),
      ),
    );
  }
}

class _ReportsHistory extends StatelessWidget {
  const _ReportsHistory({required this.future});

  final Future<List<Map<String, dynamic>>> future;

  @override
  Widget build(BuildContext context) {
    return _HistorySection<Map<String, dynamic>>(
      title: 'Safety reports you submitted',
      future: future,
      empty: 'No submitted reports.',
      item: (row) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.flag_outlined),
        title: Text(
          (row['reason'] ?? 'Report').toString().replaceAll('_', ' '),
        ),
        subtitle: Text((row['status'] ?? 'open').toString()),
      ),
    );
  }
}

class _HistorySection<T> extends StatelessWidget {
  const _HistorySection({
    required this.title,
    required this.future,
    required this.empty,
    required this.item,
  });

  final String title;
  final Future<List<T>> future;
  final String empty;
  final Widget Function(T value) item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MortSectionTitle(title: title),
        FutureBuilder<List<T>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const MortSkeletonCard();
            }
            if (snapshot.hasError) {
              return MortErrorState(
                title: '$title unavailable',
                message: userFacingError(snapshot.error),
              );
            }
            final values = snapshot.data ?? const [];
            if (values.isEmpty) {
              return MortCard(child: Text(empty));
            }
            return MortCard(
              child: Column(
                children: [for (final value in values) item(value)],
              ),
            );
          },
        ),
      ],
    );
  }
}
