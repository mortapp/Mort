import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/models/application.dart';
import '../../data/models/job.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/providers.dart';
import '../../services/native_permissions_service.dart';
import '../../services/precise_location_service.dart';
import '../profile/profile_avatar_widgets.dart';
import '../teen/teen_shell.dart';
import 'quick_accept_button.dart';

const _feedCategories = [
  'All',
  'cleaning',
  'lawn care',
  'dog walking',
  'pet care',
  'snow removal',
  'trash and recycling',
  'moving/light lifting',
  'tutoring',
  'technology help',
  'organization',
  'errands',
  'event setup',
  'car washing',
  'painting/light maintenance',
  'delivery where legally appropriate',
  'other safe local work',
];

const _quickFeedCategories = <String, String>{
  'All': 'All',
  'Yard': 'lawn care',
  'Pets': 'pet care',
  'Tutoring': 'tutoring',
  'Moving': 'moving/light lifting',
  'Tech': 'technology help',
};

class TeenJobFeedScreen extends ConsumerStatefulWidget {
  const TeenJobFeedScreen({super.key});

  @override
  ConsumerState<TeenJobFeedScreen> createState() => _TeenJobFeedScreenState();
}

class _TeenJobFeedScreenState extends ConsumerState<TeenJobFeedScreen> {
  final _keyword = TextEditingController();
  final _minimumPay = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _filtersController = ExpansionTileController();
  final Set<String> _savedJobIds = {};
  String _category = 'All';
  String _paymentType = 'any';
  String _scheduleType = 'any';
  String _verification = 'any';
  String _guardian = 'any';
  String _environment = 'any';
  JobSort _sort = JobSort.newest;
  bool _locating = false;
  String? _savingJobId;
  final _distances = <String, double>{};
  bool _distancesLoading = false;
  PreciseLocationStatus? _distanceStatus;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSavedJobs());
  }

  @override
  void dispose() {
    _keyword.dispose();
    _minimumPay.dispose();
    _city.dispose();
    _state.dispose();
    _filtersController.dispose();
    super.dispose();
  }

  Future<void> _refreshDistances(List<Job> jobsNeedingDistance) async {
    if (jobsNeedingDistance.isEmpty || _distancesLoading) return;
    setState(() => _distancesLoading = true);
    final result = await const PreciseLocationService()
        .requestFreshPreciseLocation();
    if (!mounted) return;
    if (!result.isUsable) {
      setState(() {
        _distancesLoading = false;
        _distanceStatus = result.status;
      });
      return;
    }
    try {
      final distances = await ref
          .read(jobsRepositoryProvider)
          .getNearbyJobDistances(
            jobsNeedingDistance.map((job) => job.id).toList(),
            latitude: result.position!.latitude,
            longitude: result.position!.longitude,
          );
      if (!mounted) return;
      setState(() {
        _distances.addAll(distances);
        _distancesLoading = false;
        _distanceStatus = PreciseLocationStatus.granted;
      });
    } catch (_) {
      // Distance is an enhancement, not required to browse the feed.
      if (mounted) setState(() => _distancesLoading = false);
    }
  }

  Future<void> _loadSavedJobs() async {
    try {
      final jobs = await ref.read(jobsRepositoryProvider).listSavedJobs();
      if (!mounted) return;
      setState(() {
        _savedJobIds
          ..clear()
          ..addAll(jobs.map((job) => job.id));
      });
    } catch (_) {
      // The feed remains usable when optional saved-state hydration fails.
    }
  }

  Future<void> _toggleSaved(Job job) async {
    if (_savingJobId != null) return;
    final wasSaved = _savedJobIds.contains(job.id);
    setState(() => _savingJobId = job.id);
    try {
      final repository = ref.read(jobsRepositoryProvider);
      if (wasSaved) {
        await repository.unsaveJob(job.id);
      } else {
        await repository.saveJob(job.id);
      }
      if (!mounted) return;
      setState(() {
        if (wasSaved) {
          _savedJobIds.remove(job.id);
        } else {
          _savedJobIds.add(job.id);
        }
      });
      MortToast.show(context, wasSaved ? 'Job unsaved.' : 'Job saved.');
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _savingJobId = null);
    }
  }

  JobSearchFilters _filtersFor(Profile? profile) => JobSearchFilters(
    keyword: _keyword.text.trim(),
    category: _category == 'All' ? null : _category,
    minimumPayCents: _minimumPay.text.trim().isEmpty
        ? null
        : MortValidators.dollarsToCents(_minimumPay.text),
    paymentType: _paymentType == 'any' ? null : _paymentType,
    scheduleType: _scheduleType == 'any' ? null : _scheduleType,
    verificationRequirement: _verification == 'any' ? null : _verification,
    requiresGuardianApproval: switch (_guardian) {
      'required' => true,
      'not_required' => false,
      _ => null,
    },
    workEnvironment: _environment == 'any' ? null : _environment,
    city: _city.text.trim().isEmpty ? null : _city.text.trim(),
    state: _state.text.trim().isEmpty ? null : _state.text.trim().toUpperCase(),
    transportationMethods: profile?.walkingDistanceOnly == true
        ? const ['walking']
        : profile?.transportationMethods.isEmpty == false
        ? profile!.transportationMethods
        : null,
    limit: 20,
    sort: _sort,
  );

  void _clearFilters() {
    _keyword.clear();
    _minimumPay.clear();
    _city.clear();
    _state.clear();
    setState(() {
      _category = 'All';
      _paymentType = 'any';
      _scheduleType = 'any';
      _verification = 'any';
      _guardian = 'any';
      _environment = 'any';
      _sort = JobSort.newest;
    });
  }

  bool _hasActiveFilters() {
    return _keyword.text.isNotEmpty ||
        _category != 'All' ||
        _paymentType != 'any' ||
        _scheduleType != 'any' ||
        _verification != 'any' ||
        _guardian != 'any' ||
        _environment != 'any' ||
        _city.text.isNotEmpty ||
        _state.text.isNotEmpty;
  }

  Future<void> _useCurrentArea() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final area = await const NativePermissionsService()
          .resolveCurrentGeneralArea();
      if (!mounted) return;
      _city.text = area.city;
      _state.text = area.state;
      setState(() {});
      MortToast.show(
        context,
        'Using ${area.city}, ${area.state}. Raw coordinates were discarded.',
      );
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).asData?.value;
    final filters = _filtersFor(profile);
    final jobs = ref.watch(openJobsProvider(filters));
    ref.listen<AsyncValue<JobFeedState>>(openJobsProvider(filters), (
      previous,
      next,
    ) {
      final items = next.asData?.value.items ?? const <Job>[];
      final missing = items
          .where((job) => !_distances.containsKey(job.id))
          .toList();
      if (missing.isNotEmpty) {
        unawaited(_refreshDistances(missing));
      }
    });
    return MortScreen(
      children: [
        MortTeenDestinationHeader(
          eyebrow: 'Teen-safe feed',
          title: 'Jobs',
          subtitle:
              'Open jobs in your selected area. Exact addresses never appear in the feed.',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MortIconButton(
                icon: Icons.bookmark_outline_rounded,
                tooltip: 'Saved jobs',
                onPressed: () => context.push('/teen/saved'),
              ),
              MortIconButton(
                icon: Icons.notifications_none_rounded,
                tooltip: 'Notifications',
                onPressed: () => context.push('/notifications'),
              ),
            ],
          ),
        ),
        const SizedBox(height: MortSpacing.md),
        MortSearchField(
          controller: _keyword,
          hint: 'Try tutoring, yard work, or technology help',
          onSubmitted: (_) => setState(() {}),
          onFilter: _filtersController.expand,
        ),
        const SizedBox(height: MortSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final category in _quickFeedCategories.entries) ...[
                MortChip(
                  label: category.key,
                  selected: _category == category.value,
                  onSelected: (_) => setState(() => _category = category.value),
                ),
                const SizedBox(width: MortSpacing.xs),
              ],
            ],
          ),
        ),
        const SizedBox(height: MortSpacing.xs),
        ExpansionTile(
          controller: _filtersController,
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: MortSpacing.sm),
          title: const Text('Filters and sorting'),
          leading: const Icon(Icons.tune),
          children: [
            MortDropdown<String>(
              label: 'Category',
              value: _category,
              items: {for (final value in _feedCategories) value: value},
              onChanged: (value) => setState(() => _category = value ?? 'All'),
            ),
            const SizedBox(height: MortSpacing.sm),
            MortTextField(
              label: 'Minimum pay in dollars',
              controller: _minimumPay,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: MortSpacing.sm),
            MortDropdown<String>(
              label: 'Payment type',
              value: _paymentType,
              items: const {
                'any': 'Any payment type',
                'fixed': 'Fixed amount',
                'hourly': 'Hourly',
              },
              onChanged: (value) =>
                  setState(() => _paymentType = value ?? 'any'),
            ),
            const SizedBox(height: MortSpacing.sm),
            MortDropdown<String>(
              label: 'Schedule',
              value: _scheduleType,
              items: const {
                'any': 'Any schedule',
                'flexible': 'Flexible',
                'exact': 'Exact date and time',
              },
              onChanged: (value) =>
                  setState(() => _scheduleType = value ?? 'any'),
            ),
            const SizedBox(height: MortSpacing.sm),
            MortDropdown<String>(
              label: 'Applicant verification preference',
              value: _verification,
              items: const {
                'any': 'Any preference',
                'none': 'No additional preference',
                'preferred': 'Verified preferred',
                'required': 'Verified required',
              },
              onChanged: (value) =>
                  setState(() => _verification = value ?? 'any'),
            ),
            const SizedBox(height: MortSpacing.sm),
            MortDropdown<String>(
              label: 'Guardian approval',
              value: _guardian,
              items: const {
                'any': 'Any',
                'not_required': 'Not requested',
                'required': 'Requested for this job',
              },
              onChanged: (value) => setState(() => _guardian = value ?? 'any'),
            ),
            const SizedBox(height: MortSpacing.sm),
            MortDropdown<String>(
              label: 'Work environment',
              value: _environment,
              items: const {
                'any': 'Any environment',
                'indoor': 'Indoor',
                'outdoor': 'Outdoor',
                'both': 'Indoor and outdoor',
              },
              onChanged: (value) =>
                  setState(() => _environment = value ?? 'any'),
            ),
            const SizedBox(height: MortSpacing.sm),
            MortCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'General search area',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: MortSpacing.xs),
                  const Text(
                    'City and state are optional. MORT does not calculate your distance to a job. Manual entry works even when location access is denied.',
                  ),
                  const SizedBox(height: MortSpacing.sm),
                  MortTextField(label: 'City', controller: _city),
                  const SizedBox(height: MortSpacing.sm),
                  MortTextField(
                    label: 'State code',
                    controller: _state,
                    maxLength: 2,
                    textCapitalization: TextCapitalization.characters,
                  ),
                  if (!kIsWeb) ...[
                    const SizedBox(height: MortSpacing.sm),
                    MortButton(
                      label: 'Use current general area',
                      icon: Icons.my_location,
                      style: MortButtonStyle.secondary,
                      busy: _locating,
                      busyLabel: 'Finding general area...',
                      onPressed: _useCurrentArea,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: MortSpacing.sm),
            MortDropdown<JobSort>(
              label: 'Sort',
              value: _sort,
              items: const {
                JobSort.newest: 'Newest',
                JobSort.highestPay: 'Highest pay',
                JobSort.soonestStart: 'Soonest start',
              },
              onChanged: (value) =>
                  setState(() => _sort = value ?? JobSort.newest),
            ),
            const SizedBox(height: MortSpacing.md),
            Row(
              children: [
                Expanded(
                  child: MortButton(
                    label: 'Apply filters',
                    icon: Icons.search,
                    onPressed: () => setState(() {}),
                  ),
                ),
                const SizedBox(width: MortSpacing.sm),
                Expanded(
                  child: MortButton(
                    label: 'Clear',
                    icon: Icons.clear,
                    style: MortButtonStyle.ghost,
                    onPressed: _clearFilters,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: MortSpacing.sm),
        jobs.when(
          loading: () => const Column(
            children: [
              MortSkeletonCard(),
              SizedBox(height: MortSpacing.sm),
              MortSkeletonCard(),
            ],
          ),
          error: (error, _) => MortErrorState(
            title: 'Job feed unavailable',
            message: userFacingError(error),
            action: MortButton(
              label: 'Retry',
              icon: Icons.refresh,
              onPressed: () => ref.invalidate(openJobsProvider(filters)),
            ),
          ),
          data: (feed) {
            final items = feed.items;
            if (items.isEmpty) {
              return MortEmptyState(
                title: 'No jobs in this area yet',
                message:
                    'When approved pilot adults post matching jobs for this city, state, and travel method, they will appear here.',
                action: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MortButton(
                      label: 'Refresh',
                      icon: Icons.refresh_rounded,
                      onPressed: () =>
                          ref.invalidate(openJobsProvider(filters)),
                    ),
                    const SizedBox(height: MortSpacing.xs),
                    MortButton(
                      label: 'Review travel preferences',
                      icon: Icons.route_outlined,
                      style: MortButtonStyle.secondary,
                      onPressed: () => context.go('/onboarding/transportation'),
                    ),
                    const SizedBox(height: MortSpacing.xs),
                    MortButton(
                      label: 'Edit interests',
                      icon: Icons.interests_outlined,
                      style: MortButtonStyle.ghost,
                      onPressed: () => context.go('/teen/skills'),
                    ),
                    const SizedBox(height: MortSpacing.xs),
                    MortButton(
                      label: 'Enable notifications',
                      icon: Icons.notifications_active_outlined,
                      style: MortButtonStyle.ghost,
                      onPressed: () =>
                          context.go('/settings/native-permissions'),
                    ),
                    if (_hasActiveFilters()) ...[
                      const SizedBox(height: MortSpacing.xs),
                      MortButton(
                        label: 'Clear filters',
                        icon: Icons.filter_alt_off_rounded,
                        style: MortButtonStyle.ghost,
                        onPressed: _clearFilters,
                      ),
                    ],
                  ],
                ),
              );
            }
            return Column(
              children: [
                if (feed.servedFromSessionCache) ...[
                  const MortSafetyBanner(
                    message:
                        'Showing job results loaded earlier in this session. Refresh when your connection returns.',
                  ),
                  const SizedBox(height: MortSpacing.sm),
                ],
                if (!_distancesLoading &&
                    _distanceStatus != null &&
                    _distanceStatus != PreciseLocationStatus.granted) ...[
                  MortCard(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_disabled_rounded,
                          color: MortColors.lightBlue,
                        ),
                        const SizedBox(width: MortSpacing.sm),
                        const Expanded(
                          child: Text(
                            'Turn on precise location to see how far each job is.',
                          ),
                        ),
                        MortSecondaryButton(
                          label: 'Enable',
                          onPressed: () => _refreshDistances(items),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: MortSpacing.sm),
                ],
                for (final job in items) ...[
                  _TeenJobCard(
                    job: job,
                    saved: _savedJobIds.contains(job.id),
                    saving: _savingJobId == job.id,
                    onToggleSaved: () => _toggleSaved(job),
                    distanceMiles: _distances[job.id],
                  ),
                  const SizedBox(height: MortSpacing.sm),
                ],
                if (feed.paginationError != null) ...[
                  MortErrorState(
                    title: 'More jobs could not be loaded',
                    message: userFacingError(feed.paginationError),
                    action: MortButton(
                      label: 'Retry load more',
                      icon: Icons.refresh,
                      onPressed: () => ref
                          .read(openJobsProvider(filters).notifier)
                          .loadNext(),
                    ),
                  ),
                  const SizedBox(height: MortSpacing.sm),
                ],
                if (feed.hasMore)
                  MortButton(
                    label: 'Load more jobs',
                    icon: Icons.expand_more,
                    style: MortButtonStyle.secondary,
                    busy: feed.loadingMore,
                    busyLabel: 'Loading more jobs...',
                    onPressed: () =>
                        ref.read(openJobsProvider(filters).notifier).loadNext(),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: MortSpacing.md),
        const MortAdBannerSlot(placement: 'job_feed'),
      ],
    );
  }
}

class _TeenJobCard extends StatelessWidget {
  const _TeenJobCard({
    required this.job,
    required this.saved,
    required this.saving,
    required this.onToggleSaved,
    this.distanceMiles,
  });

  final Job job;
  final bool saved;
  final bool saving;
  final VoidCallback onToggleSaved;
  final double? distanceMiles;

  @override
  Widget build(BuildContext context) {
    return MortGlassCard(
      onTap: () => context.push('/teen/jobs/${job.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: MortSpacing.xxs),
                    Text(
                      job.category,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: MortSpacing.sm),
              // Pay stays the single most prominent figure on the card --
              // the first thing a Teen's eye should land on after the title.
              Text(
                job.payDisplay,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: MortColors.roseGoldLight,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: MortSpacing.xs),
              SizedBox.square(
                dimension: MortSpacing.minTouchTarget,
                child: saving
                    ? const Padding(
                        padding: EdgeInsets.all(MortSpacing.sm),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        tooltip: saved ? 'Unsave job' : 'Save job',
                        onPressed: onToggleSaved,
                        icon: Icon(
                          saved
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: saved
                              ? MortColors.roseGoldLight
                              : MortColors.silver,
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: MortSpacing.sm),
          // A compact wrapping meta-row scans far faster than a stack of
          // full-width fact rows -- the same information, tightened.
          Wrap(
            spacing: MortSpacing.sm,
            runSpacing: MortSpacing.xxs,
            children: [
              if (distanceMiles != null)
                _JobCardMetaChip(
                  icon: Icons.near_me_rounded,
                  value:
                      '${distanceMiles! < 0.1 ? 'Less than 0.1' : distanceMiles!.toStringAsFixed(1)} mi away',
                  emphasize: true,
                ),
              _JobCardMetaChip(
                icon: Icons.place_outlined,
                value: job.locationText,
              ),
              _JobCardMetaChip(
                icon: Icons.schedule_outlined,
                value: job.scheduleDisplay,
              ),
              if (job.estimatedDurationMinutes != null)
                _JobCardMetaChip(
                  icon: Icons.hourglass_bottom_rounded,
                  value: _durationDisplay(job.estimatedDurationMinutes!),
                ),
              if (job.acceptableTransportationMethods.isNotEmpty)
                _JobCardMetaChip(
                  icon: Icons.route_outlined,
                  value: job.acceptableTransportationMethods
                      .map((method) => method.replaceAll('_', ' '))
                      .join(', '),
                ),
            ],
          ),
          if (distanceMiles == null &&
              job.matchExplanation?.isNotEmpty == true) ...[
            const SizedBox(height: MortSpacing.xs),
            Text(
              job.matchExplanation!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (job.summary?.isNotEmpty == true) ...[
            const SizedBox(height: MortSpacing.sm),
            Text(job.summary!, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: MortSpacing.sm),
          Wrap(
            spacing: MortSpacing.xs,
            runSpacing: MortSpacing.xs,
            children: [
              MortStatusPill(
                label: job.verificationDisplay,
                icon: Icons.verified_user_outlined,
                color: job.posterVerified
                    ? MortColors.success
                    : MortColors.lightBlue,
              ),
              if (job.requiresGuardianApproval)
                const MortStatusPill(
                  label: 'Guardian approval requested',
                  icon: Icons.family_restroom_outlined,
                  color: MortColors.lightBlue,
                ),
              MortStatusPill(
                label: job.workEnvironment == 'unspecified'
                    ? 'Environment details in job'
                    : job.workEnvironment.replaceAll('_', ' '),
                icon: Icons.health_and_safety_outlined,
                color: MortColors.silver,
              ),
            ],
          ),
          if (job.quickAcceptEligible) ...[
            const SizedBox(height: MortSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: QuickAcceptButton(
                job: job,
                onAccepted: (application) =>
                    context.push('/teen/applications/${application.id}'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _durationDisplay(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    return remainder == 0 ? '$hours hr' : '$hours hr $remainder min';
  }
}

/// Compact icon+text chip for a job card's meta-row (distance, location,
/// schedule, duration, transportation) -- laid out in a [Wrap] instead of
/// each fact claiming its own full-width row.
class _JobCardMetaChip extends StatelessWidget {
  const _JobCardMetaChip({
    required this.icon,
    required this.value,
    this.emphasize = false,
  });

  final IconData icon;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final color = emphasize ? MortColors.roseGoldLight : MortColors.lightBlue;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: MortSpacing.xxs),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: emphasize ? MortColors.roseGoldLight : null,
            fontWeight: emphasize ? FontWeight.w600 : null,
          ),
        ),
      ],
    );
  }
}

class TeenJobDetailScreen extends ConsumerStatefulWidget {
  const TeenJobDetailScreen({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<TeenJobDetailScreen> createState() =>
      _TeenJobDetailScreenState();
}

class _TeenJobDetailScreenState extends ConsumerState<TeenJobDetailScreen> {
  final _proposal = TextEditingController();
  late Future<_JobDetailData> _future;
  bool _availabilityConfirmed = false;
  bool _saved = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _proposal.dispose();
    super.dispose();
  }

  Future<_JobDetailData> _load() async {
    final jobs = ref.read(jobsRepositoryProvider);
    final job = await jobs.getJob(widget.jobId);
    if (job == null) return const _JobDetailData();
    final results = await Future.wait<Object?>([
      ref.read(applicationsRepositoryProvider).checkEligibility(widget.jobId),
      jobs.isSaved(widget.jobId),
    ]);
    _saved = results[1] == true;
    return _JobDetailData(
      job: job,
      eligibility: results[0] as ApplicationEligibility,
      saved: _saved,
    );
  }

  void _reload() {
    setState(() => _future = _load());
  }

  Future<void> _toggleSaved() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (_saved) {
        await ref.read(jobsRepositoryProvider).unsaveJob(widget.jobId);
      } else {
        await ref.read(jobsRepositoryProvider).saveJob(widget.jobId);
      }
      if (!mounted) return;
      setState(() => _saved = !_saved);
      MortToast.show(
        context,
        _saved ? 'Job saved.' : 'Job removed from saved.',
      );
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apply(ApplicationEligibility eligibility) async {
    if (_busy || !eligibility.eligible) return;
    if (!_availabilityConfirmed) {
      MortToast.show(
        context,
        'Confirm that the schedule works for you before applying.',
      );
      return;
    }
    final proposal = _proposal.text.trim();
    if (proposal.length > 500) {
      MortToast.show(context, 'Keep the proposal under 500 characters.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(applicationsRepositoryProvider)
          .applyToJob(
            widget.jobId,
            note: proposal,
            availabilityConfirmed: true,
          );
      if (!mounted) return;
      MortToast.show(context, 'Application submitted.');
      context.go('/teen/applications');
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
      _reload();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _ctaLabel(ApplicationEligibility eligibility) {
    if (eligibility.eligible) return 'Apply now';
    return switch (eligibility.code) {
      'application_already_exists' => 'Application pending',
      'job_not_open' || 'job_already_assigned' => 'Applications closed',
      'guardian_link_required' ||
      'guardian_approval_required' => 'Guardian link needed for this job',
      _ => 'Not eligible for this job',
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_JobDetailData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MortLoading(label: 'Checking job eligibility');
        }
        if (snapshot.hasError) {
          return MortScreen(
            children: [
              MortErrorState(
                title: 'Job detail unavailable',
                message: userFacingError(snapshot.error),
                action: MortButton(
                  label: 'Retry',
                  icon: Icons.refresh,
                  onPressed: _reload,
                ),
              ),
            ],
          );
        }
        final data = snapshot.data ?? const _JobDetailData();
        final job = data.job;
        final eligibility = data.eligibility;
        if (job == null || eligibility == null) {
          return const MortScreen(
            children: [
              MortErrorState(
                title: 'Job unavailable',
                message: 'This job was removed or is no longer visible.',
              ),
            ],
          );
        }
        return MortScreen(
          padding: const EdgeInsets.fromLTRB(
            MortSpacing.md,
            MortSpacing.md,
            MortSpacing.md,
            180,
          ),
          bottom: SafeArea(
            minimum: const EdgeInsets.fromLTRB(
              MortSpacing.md,
              MortSpacing.xs,
              MortSpacing.md,
              MortSpacing.md,
            ),
            child: DecoratedBox(
              decoration: const BoxDecoration(color: MortColors.bg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (job.quickAcceptEligible && eligibility.eligible) ...[
                    Align(
                      alignment: Alignment.center,
                      child: QuickAcceptButton(
                        job: job,
                        onAccepted: (application) => context.pushReplacement(
                          '/teen/applications/${application.id}',
                        ),
                      ),
                    ),
                    const SizedBox(height: MortSpacing.xs),
                    Text(
                      'Instant accept, or apply the regular way below.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: MortSpacing.sm),
                  ],
                  if (!eligibility.eligible)
                    Padding(
                      padding: const EdgeInsets.only(bottom: MortSpacing.xs),
                      child: Text(
                        eligibility.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  MortButton(
                    label: _ctaLabel(eligibility),
                    icon: Icons.send,
                    busy: _busy,
                    busyLabel: 'Submitting...',
                    style: eligibility.eligible
                        ? MortButtonStyle.primary
                        : MortButtonStyle.disabled,
                    onPressed: eligibility.eligible
                        ? () => _apply(eligibility)
                        : null,
                  ),
                ],
              ),
            ),
          ),
          children: [
            MortGlassHeader(
              eyebrow: job.category,
              title: job.title,
              subtitle: '${job.payDisplay} | General area: ${job.locationText}',
              showBack: true,
              onBack: () =>
                  context.canPop() ? context.pop() : context.go('/teen/home'),
            ),
            const SizedBox(height: MortSpacing.md),
            Wrap(
              spacing: MortSpacing.xs,
              runSpacing: MortSpacing.xs,
              children: [
                MortBadge(label: job.scheduleDisplay),
                MortTrustBadge(
                  label: job.verificationDisplay,
                  verified: job.posterVerified,
                ),
                if (job.requiresGuardianApproval)
                  const MortBadge(
                    label: 'Poster requested guardian approval',
                    color: MortColors.safetyBlue,
                  ),
              ],
            ),
            const SizedBox(height: MortSpacing.md),
            if (job.payAmountCents != null) ...[
              const MortSectionTitle(title: 'Offered compensation'),
              MortGlassCard(
                child: Column(
                  children: [
                    MortPriceDisplay(
                      label: 'Amount listed by the poster',
                      formattedAmount: job.payDisplay,
                      emphasized: true,
                    ),
                    const SizedBox(height: MortSpacing.xs),
                    const Text(
                      'MORT does not process, hold, guarantee, or mark this amount paid.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: MortSpacing.md),
            ],
            MortCard(
              child: Row(
                children: [
                  ProfileAvatarView(
                    profileId: job.posterId,
                    avatarPath: job.posterAvatarPath,
                    fallbackLabel: job.posterName ?? 'Job poster',
                  ),
                  const SizedBox(width: MortSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.posterName ?? 'Job poster',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: MortSpacing.xs),
                        Text(job.verificationDisplay),
                      ],
                    ),
                  ),
                  MortIconButton(
                    icon: Icons.flag_outlined,
                    tooltip: 'Report profile picture or poster',
                    onPressed: () =>
                        context.push('/report/user/${job.posterId}'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: MortSpacing.md),
            const MortSectionTitle(title: 'Job details'),
            MortCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (job.summary?.isNotEmpty == true) ...[
                    Text(
                      job.summary!,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: MortSpacing.sm),
                  ],
                  Text(job.description),
                  const SizedBox(height: MortSpacing.md),
                  _DetailLine(icon: Icons.schedule, label: job.scheduleDisplay),
                  _DetailLine(
                    icon: Icons.place_outlined,
                    label:
                        'Approximate area: ${job.locationText}, ${job.city}, ${job.state}',
                  ),
                  if (job.estimatedDurationMinutes != null)
                    _DetailLine(
                      icon: Icons.timer_outlined,
                      label:
                          'About ${job.estimatedDurationMinutes} minutes, ${job.workersNeeded} worker${job.workersNeeded == 1 ? '' : 's'}',
                    ),
                  _DetailLine(
                    icon: Icons.payments_outlined,
                    label:
                        '${job.payDisplay} ${job.paymentType == 'hourly' ? 'per hour' : 'fixed'} | ${job.paymentTiming.replaceAll('_', ' ')}',
                  ),
                  _DetailLine(
                    icon: Icons.route_outlined,
                    label:
                        'Travel options: ${job.acceptableTransportationMethods.map((method) => method.replaceAll('_', ' ')).join(', ')}',
                  ),
                  if (job.transportationConsiderations?.isNotEmpty == true)
                    _DetailLine(
                      icon: Icons.info_outline_rounded,
                      label: job.transportationConsiderations!,
                    ),
                ],
              ),
            ),
            if (job.skillsNeeded.isNotEmpty ||
                job.physicalRequirements.isNotEmpty ||
                job.equipmentWorkerBrings?.isNotEmpty == true) ...[
              const SizedBox(height: MortSpacing.md),
              const MortSectionTitle(title: 'Requirements'),
              MortCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (job.skillsNeeded.isNotEmpty)
                      Text('Skills: ${job.skillsNeeded.join(', ')}'),
                    if (job.physicalRequirements.isNotEmpty)
                      Text(
                        'Physical details: ${job.physicalRequirements.join(', ')}',
                      ),
                    if (job.equipmentWorkerBrings?.isNotEmpty == true)
                      Text('Bring: ${job.equipmentWorkerBrings}'),
                  ],
                ),
              ),
            ],
            const SizedBox(height: MortSpacing.md),
            const MortSafetyBanner(
              message:
                  'Keep communication on MORT. Do not send private contact details, payment handles, access codes, or an exact address in your proposal.',
            ),
            const SizedBox(height: MortSpacing.md),
            const MortPaymentDisclaimer(),
            const SizedBox(height: MortSpacing.md),
            MortCard(
              color: eligibility.eligible
                  ? MortColors.neon.withValues(alpha: 0.08)
                  : MortColors.danger.withValues(alpha: 0.08),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Application eligibility',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: MortSpacing.xs),
                  Text(eligibility.message),
                  if ((eligibility.code == 'guardian_link_required' ||
                          eligibility.code == 'guardian_approval_required') &&
                      !eligibility.guardianLinked) ...[
                    const SizedBox(height: MortSpacing.md),
                    MortButton(
                      label: 'Link a guardian',
                      icon: Icons.family_restroom,
                      onPressed: () => context.go('/settings/guardian-mode'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: MortSpacing.md),
            Text(
              'You\'re applying for ${job.title}.',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: MortSpacing.sm),
            MortTextArea(
              label: 'Proposal (optional)',
              controller: _proposal,
              hint:
                  'Tell the poster why you are a good fit, what experience you have, and when you are available.',
              maxLines: 6,
              maxLength: 500,
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _availabilityConfirmed,
              onChanged: eligibility.eligible
                  ? (value) =>
                        setState(() => _availabilityConfirmed = value ?? false)
                  : null,
              title: const Text('I checked the schedule and I am available.'),
            ),
            const SizedBox(height: MortSpacing.sm),
            MortActionRow(
              actions: [
                MortAction(
                  label: _saved ? 'Unsave job' : 'Save job',
                  icon: _saved ? Icons.bookmark_remove : Icons.bookmark_add,
                  busy: _busy,
                  onPressed: _toggleSaved,
                ),
                MortAction(
                  label: 'Report job',
                  icon: Icons.report_outlined,
                  onPressed: () => context.push('/report/job/${job.id}'),
                  style: MortButtonStyle.danger,
                ),
                MortAction(
                  label: 'Block poster',
                  icon: Icons.block,
                  onPressed: () => context.push('/block/user/${job.posterId}'),
                  style: MortButtonStyle.danger,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: MortSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: MortColors.textMuted),
          const SizedBox(width: MortSpacing.sm),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class _JobDetailData {
  const _JobDetailData({this.job, this.eligibility, this.saved = false});

  final Job? job;
  final ApplicationEligibility? eligibility;
  final bool saved;
}
