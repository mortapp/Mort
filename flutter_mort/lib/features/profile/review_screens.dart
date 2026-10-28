import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/models/application.dart';
import '../../data/models/review.dart';
import '../../data/repositories/providers.dart';

class LeaveReviewScreen extends ConsumerStatefulWidget {
  const LeaveReviewScreen({super.key, required this.applicationId});

  final String applicationId;

  @override
  ConsumerState<LeaveReviewScreen> createState() => _LeaveReviewScreenState();
}

class _LeaveReviewScreenState extends ConsumerState<LeaveReviewScreen> {
  late Future<_ReviewContext> _future;
  int _rating = 5;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ReviewContext> _load() async {
    final application = await ref
        .read(applicationsRepositoryProvider)
        .getApplication(widget.applicationId);
    if (application == null) return const _ReviewContext();
    final repository = ref.read(reviewsRepositoryProvider);
    final existing = await repository.reviewForApplicationByCurrentUser(
      application.id,
    );
    final execution = await ref
        .read(jobExecutionRepositoryProvider)
        .getStatus(application.id);
    return _ReviewContext(
      application: application,
      existing: existing,
      completed: execution.state == 'completed',
    );
  }

  Future<void> _submit(_ReviewContext data) async {
    final application = data.application;
    if (_busy || application == null || !data.completed) return;
    final currentUserId = ref.read(authRepositoryProvider).currentUser?.id;
    final job = application.job;
    if (currentUserId == null || job == null) return;
    final subjectId = currentUserId == application.teenId
        ? job.posterId
        : application.teenId;
    setState(() => _busy = true);
    try {
      await ref
          .read(reviewsRepositoryProvider)
          .createReview(
            applicationId: application.id,
            jobId: application.jobId,
            subjectId: subjectId,
            rating: _rating,
          );
      if (!mounted) return;
      MortToast.show(context, 'Review submitted.');
      setState(() => _future = _load());
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ReviewContext>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MortLoading(label: 'Loading review eligibility');
        }
        if (snapshot.hasError) {
          return MortScreen(
            children: [
              MortErrorState(
                title: 'Review unavailable',
                message: userFacingError(snapshot.error),
              ),
            ],
          );
        }
        final data = snapshot.data ?? const _ReviewContext();
        final application = data.application;
        if (application == null) {
          return const MortScreen(
            children: [
              MortErrorState(
                title: 'Application unavailable',
                message: 'This application is not visible to your account.',
              ),
            ],
          );
        }
        if (data.existing != null) {
          return MortScreen(
            children: [
              const MortHeader(
                eyebrow: 'Review recorded',
                title: 'Thanks for the feedback',
                subtitle: 'MORT permits one review per side for each job.',
              ),
              _ReviewCard(review: data.existing!),
            ],
          );
        }
        if (!data.completed) {
          return const MortScreen(
            children: [
              MortErrorState(
                title: 'Review not available yet',
                message:
                    'Reviews unlock after both people confirm the job is complete.',
              ),
            ],
          );
        }
        return MortScreen(
          children: [
            MortHeader(
              eyebrow: 'Completed job',
              title: 'Leave a review',
              subtitle:
                  'Rate your experience for ${application.job?.title ?? 'this job'}. Ratings stay private until both people submit or 14 days pass. Written reviews are not available yet.',
            ),
            MortCard(
              child: Column(
                children: [
                  Text(
                    '$_rating out of 5',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Slider(
                    value: _rating.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: '$_rating',
                    onChanged: (value) =>
                        setState(() => _rating = value.round()),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var index = 1; index <= 5; index++)
                        Icon(
                          index <= _rating ? Icons.star : Icons.star_border,
                          color: MortColors.warning,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: MortSpacing.md),
            MortButton(
              label: 'Submit review',
              icon: Icons.rate_review_outlined,
              busy: _busy,
              onPressed: () => _submit(data),
            ),
          ],
        );
      },
    );
  }
}

class MyReviewsScreen extends ConsumerWidget {
  const MyReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(receivedReviewsProvider);
    return MortScreen(
      children: [
        MortHeader(
          eyebrow: 'Profile',
          title: 'Reviews received',
          subtitle: 'Only approved reviews appear here.',
          trailing: MortIconButton(
            icon: Icons.refresh,
            tooltip: 'Refresh reviews',
            onPressed: () => ref.invalidate(receivedReviewsProvider),
          ),
        ),
        reviews.when(
          loading: () => const MortSkeletonCard(),
          error: (error, _) => MortErrorState(
            title: 'Reviews unavailable',
            message: userFacingError(error),
            action: MortButton(
              label: 'Retry',
              icon: Icons.refresh,
              onPressed: () => ref.invalidate(receivedReviewsProvider),
            ),
          ),
          data: (reviews) {
            if (reviews.isEmpty) {
              return const MortEmptyState(
                title: 'No reviews yet',
                message: 'Approved reviews appear after completed jobs.',
              );
            }
            return Column(
              children: [
                for (final review in reviews) ...[
                  _ReviewCard(review: review),
                  const SizedBox(height: MortSpacing.sm),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final MortReview review;

  @override
  Widget build(BuildContext context) {
    final removedByModeration = review.moderationStatus != 'approved';
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (removedByModeration) ...[
            // Master contract 178: explain the moderation state in plain
            // language from the real moderation_status field, with the
            // appeal route as the next action. Never renders removed
            // content as if it were still live.
            const MortSafetyBanner(
              message:
                  'This review is not publicly visible. MORT moderation is holding or removed it under the community rules. You can appeal the decision.',
            ),
            const SizedBox(height: MortSpacing.sm),
          ],
          Row(
            children: [
              for (var index = 1; index <= 5; index++)
                Icon(
                  index <= review.rating ? Icons.star : Icons.star_border,
                  size: 20,
                  color: MortColors.warning,
                ),
              const Spacer(),
              MortBadge(label: review.moderationStatus.replaceAll('_', ' ')),
            ],
          ),
          if (review.body?.isNotEmpty == true) ...[
            const SizedBox(height: MortSpacing.sm),
            Text(review.body!),
          ],
          const SizedBox(height: MortSpacing.sm),
          MortActionRow(
            actions: [
              if (removedByModeration)
                const MortAction(
                  label: 'Appeal moderation decision',
                  icon: Icons.gavel_outlined,
                  route: '/settings/trust-appeal',
                ),
              MortAction(
                label: 'Report review',
                icon: Icons.flag_outlined,
                route: '/report/review/${review.id}',
                style: MortButtonStyle.danger,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewContext {
  const _ReviewContext({
    this.application,
    this.existing,
    this.completed = false,
  });

  final MortApplication? application;
  final MortReview? existing;
  final bool completed;
}
