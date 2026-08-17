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
  final _body = TextEditingController();
  late Future<_ReviewContext> _future;
  int _rating = 5;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<_ReviewContext> _load() async {
    final application = await ref
        .read(applicationsRepositoryProvider)
        .getApplication(widget.applicationId);
    if (application == null) return const _ReviewContext();
    final existing = await ref
        .read(reviewsRepositoryProvider)
        .reviewForJobByCurrentUser(application.jobId);
    return _ReviewContext(application: application, existing: existing);
  }

  Future<void> _submit(MortApplication application) async {
    if (_busy || application.status != 'completed') return;
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
            jobId: application.jobId,
            subjectId: subjectId,
            rating: _rating,
            body: _body.text,
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
        if (application.status != 'completed') {
          return const MortScreen(
            children: [
              MortErrorState(
                title: 'Review not available yet',
                message:
                    'Reviews unlock only after the job and application are completed.',
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
                  'Rate your experience for ${application.job?.title ?? 'this job'}. Keep the review factual and do not include private contact details.',
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
            MortTextArea(
              label: 'Short review (optional)',
              controller: _body,
              maxLength: 500,
              maxLines: 5,
            ),
            const SizedBox(height: MortSpacing.md),
            MortButton(
              label: 'Submit review',
              icon: Icons.rate_review_outlined,
              busy: _busy,
              onPressed: () => _submit(application),
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
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
  const _ReviewContext({this.application, this.existing});

  final MortApplication? application;
  final MortReview? existing;
}
