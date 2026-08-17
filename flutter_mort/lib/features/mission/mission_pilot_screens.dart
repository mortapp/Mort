import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/utils/safe_uri.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/models/mission_pilot.dart';
import '../../data/repositories/providers.dart';

class PilotEligibilityScreen extends ConsumerStatefulWidget {
  const PilotEligibilityScreen({super.key});

  @override
  ConsumerState<PilotEligibilityScreen> createState() =>
      _PilotEligibilityScreenState();
}

class _PilotEligibilityScreenState
    extends ConsumerState<PilotEligibilityScreen> {
  late Future<MissionPilotDashboard> _future = _load();
  bool _working = false;

  Future<MissionPilotDashboard> _load() {
    return ref.read(missionPilotRepositoryProvider).dashboard();
  }

  Future<void> _acknowledgeTeenRules() async {
    setState(() => _working = true);
    try {
      final repository = ref.read(missionPilotRepositoryProvider);
      for (final type in const [
        'teen_safety_training',
        'pilot_rules',
        'explicit_consent',
      ]) {
        await repository.acknowledge(type);
      }
      if (!mounted) return;
      MortToast.show(
        context,
        'Current teen pilot acknowledgements saved. Partner enrollment and all server requirements still apply.',
      );
      setState(() => _future = _load());
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Closed pilot',
          title: 'Pilot eligibility',
          subtitle:
              'Approved organization support and hosted server rules control protected marketplace access.',
        ),
        FutureBuilder<MissionPilotDashboard>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const MortSkeletonCard();
            }
            if (snapshot.hasError) {
              return MortErrorState(
                title: 'Pilot access unavailable',
                message: userFacingError(snapshot.error),
                action: MortButton(
                  label: 'Try again',
                  onPressed: () => setState(() => _future = _load()),
                ),
              );
            }
            final dashboard = snapshot.data!;
            final eligibility = dashboard.eligibility;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MortSafetyBanner(
                  message: eligibility.allowed
                      ? 'Hosted pilot access is active for this account. Every job still needs a server-owned safety decision.'
                      : 'Hosted pilot access is not active. ${eligibility.missingRequirements.length} requirement(s) remain.',
                ),
                const SizedBox(height: MortSpacing.md),
                MortCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dashboard.mission,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: MortSpacing.md),
                      const _TruthRow(
                        label: 'Guardian Mode',
                        value: 'Optional',
                      ),
                      const _TruthRow(
                        label: 'Permanent address',
                        value: 'Not required for teens',
                      ),
                      const _TruthRow(
                        label: 'Public marketplace',
                        value: 'Closed',
                      ),
                      const _TruthRow(
                        label: 'Real document collection',
                        value: 'Disabled',
                      ),
                      const _TruthRow(label: 'Payment custody', value: 'None'),
                    ],
                  ),
                ),
                if (eligibility.missingRequirements.isNotEmpty) ...[
                  const SizedBox(height: MortSpacing.md),
                  MortCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Server-reported requirements',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        for (final item in eligibility.missingRequirements)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.lock_clock_outlined,
                              color: MortColors.warning,
                            ),
                            title: Text(_readable(item)),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: MortSpacing.md),
        MortActionRow(
          actions: [
            const MortAction(
              label: 'Partner invitation',
              icon: Icons.confirmation_number_outlined,
              route: '/mission/partner-invitation',
            ),
            const MortAction(
              label: 'Partner attestations',
              icon: Icons.account_balance_outlined,
              route: '/mission/partner-affiliation',
            ),
            MortAction(
              label: 'Acknowledge teen rules',
              icon: Icons.fact_check_outlined,
              busy: _working,
              onPressed: _acknowledgeTeenRules,
            ),
          ],
        ),
        const SizedBox(height: MortSpacing.md),
        const MortVerificationDisclaimer(),
      ],
    );
  }
}

class PartnerInvitationScreen extends StatelessWidget {
  const PartnerInvitationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const sources = {
      'Approved partner code':
          'Hashed on the server, limited-use, expiring, and revocable.',
      'Verified partner email':
          'The organization relationship must already be approved.',
      'Partner staff attestation':
          'Staff may attest only to specifically authorized facts.',
      'Manual pilot enrollment':
          'An authorized reviewer records the decision and reason.',
    };
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Invitation only',
          title: 'Join through an approved partner',
          subtitle:
              'Unrestricted random adult enrollment is closed during the organization-supported pilot.',
        ),
        MortCard(
          child: Column(
            children: [
              for (final entry in sources.entries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.verified_user_outlined,
                    color: MortColors.neon,
                  ),
                  title: Text(entry.key),
                  subtitle: Text(entry.value),
                ),
            ],
          ),
        ),
        const SizedBox(height: MortSpacing.md),
        MortButton(
          label: 'Enter approved partner code',
          icon: Icons.pin_outlined,
          onPressed: () => context.go('/settings/partner-code'),
        ),
        const SizedBox(height: MortSpacing.md),
        const MortSafetyBanner(
          message:
              'A school, program, shelter, or partner relationship does not establish government identity. MORT keeps those trust labels separate.',
        ),
      ],
    );
  }
}

class PartnerAffiliationScreen extends ConsumerWidget {
  const PartnerAffiliationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Private trust signals',
          title: 'Partner affiliation',
          subtitle:
              'See exactly what was attested and what the attestation did not establish.',
        ),
        FutureBuilder<List<PartnerAttestation>>(
          future: ref
              .read(missionPilotRepositoryProvider)
              .partnerAttestations(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const MortSkeletonCard();
            }
            if (snapshot.hasError) {
              return MortErrorState(
                title: 'Attestations unavailable',
                message: userFacingError(snapshot.error),
              );
            }
            final rows = snapshot.data ?? const [];
            if (rows.isEmpty) {
              return const MortEmptyState(
                title: 'No partner attestations',
                message:
                    'No approved partner fact has been recorded for this account.',
              );
            }
            return Column(
              children: [
                for (final item in rows) ...[
                  MortCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MortBadge(label: _readable(item.factType)),
                        const SizedBox(height: MortSpacing.sm),
                        Text(item.statement),
                        const SizedBox(height: MortSpacing.xs),
                        Text(
                          'Does not establish: ${item.whatWasNotEstablished}',
                          style: const TextStyle(color: MortColors.textMuted),
                        ),
                        Text(
                          'Version ${item.version} | ${_readable(item.status)}',
                          style: const TextStyle(color: MortColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: MortSpacing.sm),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: MortSpacing.md),
        const MortSafetyBanner(
          message:
              'School or program affiliation never grants a Government identity verified label.',
        ),
      ],
    );
  }
}

class DiscreetModeScreen extends ConsumerStatefulWidget {
  const DiscreetModeScreen({super.key});

  @override
  ConsumerState<DiscreetModeScreen> createState() => _DiscreetModeScreenState();
}

class _DiscreetModeScreenState extends ConsumerState<DiscreetModeScreen> {
  bool _enabled = false;
  bool _appLock = false;
  int _minutes = 5;
  String _quickExit = 'home';
  bool _loading = true;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final state = (await ref.read(missionPilotRepositoryProvider).dashboard())
          .discreetMode;
      if (!mounted) return;
      setState(() {
        _enabled = state['enabled'] == true;
        _appLock = !kIsWeb && state['app_lock_enabled'] == true;
        _minutes = int.tryParse('${state['automatic_lock_minutes']}') ?? 5;
        _quickExit = state['quick_exit_destination']?.toString() ?? 'home';
      });
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _working = true);
    try {
      await ref
          .read(missionPilotRepositoryProvider)
          .updateDiscreetMode(
            enabled: _enabled,
            appLockEnabled: !kIsWeb && _appLock,
            automaticLockMinutes: _minutes,
            quickExitDestination: _quickExit,
          );
      if (mounted) {
        MortToast.show(context, 'Discreet Mode saved.');
      }
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Privacy',
          title: 'Discreet Mode',
          subtitle:
              'Hide sensitive notification content and keep private resource activity out of public surfaces.',
        ),
        if (_loading)
          const MortSkeletonCard()
        else
          MortCard(
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _enabled,
                  title: const Text('Enable Discreet Mode'),
                  subtitle: const Text(
                    'Generic title and hidden notification body.',
                  ),
                  onChanged: (value) => setState(() => _enabled = value),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _appLock,
                  title: Text(
                    kIsWeb
                        ? 'Native Face ID / passcode lock unavailable on web'
                        : 'Require device authentication',
                  ),
                  subtitle: Text(
                    kIsWeb
                        ? 'Native device authentication is unavailable in the web preview.'
                        : 'Android and iOS can use the device biometric, PIN, pattern, or passcode prompt when configured.',
                  ),
                  onChanged: kIsWeb
                      ? null
                      : (value) => setState(() => _appLock = value),
                ),
                DropdownButtonFormField<int>(
                  initialValue: _minutes,
                  decoration: const InputDecoration(
                    labelText: 'Automatic lock time',
                  ),
                  items: const [1, 5, 10, 15, 30, 60]
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text('$value minutes'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _minutes = value ?? 5),
                ),
                const SizedBox(height: MortSpacing.sm),
                DropdownButtonFormField<String>(
                  initialValue: _quickExit,
                  decoration: const InputDecoration(
                    labelText: 'Quick-exit destination',
                  ),
                  items:
                      const {
                            'home': 'Home',
                            'job_feed': 'Job feed',
                            'sign_in': 'Sign in',
                          }.entries
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                  onChanged: (value) =>
                      setState(() => _quickExit = value ?? 'home'),
                ),
              ],
            ),
          ),
        const SizedBox(height: MortSpacing.md),
        MortButton(
          label: 'Save Discreet Mode',
          busy: _working,
          icon: Icons.visibility_off_outlined,
          onPressed: _loading ? null : _save,
        ),
        const SizedBox(height: MortSpacing.sm),
        MortButton(
          label: 'Quick exit now',
          style: MortButtonStyle.secondary,
          icon: Icons.exit_to_app,
          onPressed: () => context.go('/account-status'),
        ),
        const SizedBox(height: MortSpacing.md),
        MortSafetyBanner(
          message: kIsWeb
              ? 'Browser quick exit changes the active route, but browser history may remain. Discreet Mode does not disguise illegal activity.'
              : 'Discreet Mode protects privacy in unsafe or unstable situations. It does not disguise illegal activity.',
        ),
      ],
    );
  }
}

class SupportCircleScreen extends ConsumerStatefulWidget {
  const SupportCircleScreen({super.key});

  @override
  ConsumerState<SupportCircleScreen> createState() =>
      _SupportCircleScreenState();
}

class _SupportCircleScreenState extends ConsumerState<SupportCircleScreen> {
  bool _enabled = false;
  int _memberCount = 0;
  bool _loading = true;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final circle =
          (await ref.read(missionPilotRepositoryProvider).dashboard())
              .supportCircle;
      if (!mounted) return;
      setState(() {
        _enabled = circle['enabled'] == true;
        _memberCount = int.tryParse('${circle['member_count']}') ?? 0;
      });
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _working = true);
    try {
      await ref
          .read(missionPilotRepositoryProvider)
          .configureSupportCircle(_enabled);
      if (mounted) {
        MortToast.show(
          context,
          'Support Circle saved. It does not affect marketplace eligibility.',
        );
      }
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Teen controlled',
          title: 'Optional Support Circle',
          subtitle:
              'Choose whether trusted adults receive narrowly granted safety alerts. Guardian Mode stays optional.',
        ),
        if (_loading)
          const MortSkeletonCard()
        else
          MortCard(
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _enabled,
                  title: const Text('Enable Support Circle'),
                  onChanged: (value) => setState(() => _enabled = value),
                ),
                _TruthRow(label: 'Active members', value: '$_memberCount'),
                const _TruthRow(
                  label: 'Affects marketplace eligibility',
                  value: 'No',
                ),
              ],
            ),
          ),
        const SizedBox(height: MortSpacing.md),
        MortButton(
          label: 'Save Support Circle',
          icon: Icons.group_outlined,
          busy: _working,
          onPressed: _loading ? null : _save,
        ),
        const SizedBox(height: MortSpacing.sm),
        MortButton(
          label: 'Manage granted safety contacts',
          style: MortButtonStyle.secondary,
          icon: Icons.manage_accounts_outlined,
          onPressed: () => context.go('/settings/safety-circle'),
        ),
        const SizedBox(height: MortSpacing.md),
        const MortSafetyBanner(
          message:
              'Members cannot read unrestricted messages, control earnings, impersonate the teen, or access identity documents.',
        ),
      ],
    );
  }
}

class EarningsGoalsScreen extends ConsumerStatefulWidget {
  const EarningsGoalsScreen({super.key});

  @override
  ConsumerState<EarningsGoalsScreen> createState() =>
      _EarningsGoalsScreenState();
}

class _EarningsGoalsScreenState extends ConsumerState<EarningsGoalsScreen> {
  final _title = TextEditingController();
  final _target = TextEditingController();
  String _type = 'emergency_savings';
  late Future<List<IndependenceGoal>> _goals = _loadGoals();
  late final Future<Map<String, dynamic>> _summary = _loadSummary();
  bool _working = false;

  Future<List<IndependenceGoal>> _loadGoals() =>
      ref.read(missionPilotRepositoryProvider).goals();
  Future<Map<String, dynamic>> _loadSummary() =>
      ref.read(missionPilotRepositoryProvider).privateWorkSummary();

  @override
  void dispose() {
    _title.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_title.text.trim().length < 2) {
      MortToast.show(context, 'Enter a goal name.');
      return;
    }
    setState(() => _working = true);
    try {
      final dollars = double.tryParse(_target.text.trim());
      await ref
          .read(missionPilotRepositoryProvider)
          .createGoal(
            goalType: _type,
            title: _title.text,
            targetAmountCents: dollars == null ? null : (dollars * 100).round(),
          );
      if (!mounted) return;
      _title.clear();
      _target.clear();
      setState(() => _goals = _loadGoals());
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const types = {
      'weekly_earnings': 'Weekly earnings',
      'emergency_savings': 'Emergency savings',
      'future_housing': 'Future housing',
      'transportation': 'Transportation',
      'school_supplies': 'School supplies',
      'family_support': 'Family support',
      'work_equipment': 'Work equipment',
      'custom': 'Custom',
    };
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Private by default',
          title: 'Earnings and goals',
          subtitle:
              'Track self-recorded work history and plan savings without exposing goals publicly.',
        ),
        FutureBuilder<Map<String, dynamic>>(
          future: _summary,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const MortSkeletonCard();
            final data = snapshot.data!;
            return MortCard(
              child: Wrap(
                spacing: MortSpacing.lg,
                runSpacing: MortSpacing.sm,
                children: [
                  _Metric(
                    value: _money(data['total_self_recorded_earnings_cents']),
                    label: 'Self-recorded',
                  ),
                  _Metric(
                    value: '${data['completed_job_count'] ?? 0}',
                    label: 'Completed jobs',
                  ),
                  _Metric(
                    value: '${data['reference_count'] ?? 0}',
                    label: 'References',
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: MortSpacing.md),
        const MortPaymentDisclaimer(),
        const SizedBox(height: MortSpacing.md),
        MortDropdown<String>(
          label: 'Goal type',
          value: _type,
          items: types,
          onChanged: (value) => setState(() => _type = value ?? _type),
        ),
        const SizedBox(height: MortSpacing.sm),
        MortTextField(label: 'Goal name', controller: _title, maxLength: 100),
        const SizedBox(height: MortSpacing.sm),
        MortTextField(
          label: 'Target dollars',
          controller: _target,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: MortSpacing.md),
        MortButton(
          label: 'Create private goal',
          icon: Icons.add_circle_outline,
          busy: _working,
          onPressed: _create,
        ),
        const SizedBox(height: MortSpacing.lg),
        const MortSectionTitle(title: 'Your goals'),
        FutureBuilder<List<IndependenceGoal>>(
          future: _goals,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const MortSkeletonCard();
            }
            if (snapshot.hasError) {
              return MortErrorState(
                title: 'Goals unavailable',
                message: userFacingError(snapshot.error),
              );
            }
            final goals = snapshot.data ?? const [];
            if (goals.isEmpty) {
              return const MortEmptyState(
                title: 'No goals yet',
                message: 'Create a private target when it is useful to you.',
              );
            }
            return Column(
              children: [
                for (final goal in goals) ...[
                  MortCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(_readable(goal.goalType)),
                        if (goal.targetAmountCents != null)
                          Text(
                            '${_money(goal.currentAmountCents)} of ${_money(goal.targetAmountCents)}',
                          ),
                      ],
                    ),
                  ),
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

class FutureIndependenceScreen extends ConsumerStatefulWidget {
  const FutureIndependenceScreen({super.key});

  @override
  ConsumerState<FutureIndependenceScreen> createState() =>
      _FutureIndependenceScreenState();
}

class _FutureIndependenceScreenState
    extends ConsumerState<FutureIndependenceScreen> {
  final _education = TextEditingController();
  final _employment = TextEditingController();
  final _transportation = TextEditingController();
  final _savings = TextEditingController();
  bool _working = false;

  @override
  void dispose() {
    _education.dispose();
    _employment.dispose();
    _transportation.dispose();
    _savings.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _working = true);
    try {
      final dollars = double.tryParse(_savings.text.trim());
      await ref
          .read(missionPilotRepositoryProvider)
          .saveFuturePlan(
            educationPlan: _education.text,
            employmentPlan: _employment.text,
            transportationPlan: _transportation.text,
            savingsTargetCents: dollars == null
                ? null
                : (dollars * 100).round(),
          );
      if (mounted) {
        MortToast.show(context, 'Your private preparation plan was saved.');
      }
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Lawful adulthood preparation',
          title: 'Future Independence Plan',
          subtitle:
              'Plan education, employment, savings, transportation, references, and trusted support.',
        ),
        const MortSafetyBanner(
          message:
              'MORT does not provide instructions for minors to evade lawful protections or secretly run away. For immediate danger, contact emergency services or a qualified crisis resource.',
        ),
        const SizedBox(height: MortSpacing.md),
        MortTextArea(
          label: 'Education plan',
          controller: _education,
          maxLength: 1000,
        ),
        const SizedBox(height: MortSpacing.sm),
        MortTextArea(
          label: 'Employment plan',
          controller: _employment,
          maxLength: 1000,
        ),
        const SizedBox(height: MortSpacing.sm),
        MortTextArea(
          label: 'Safe transportation plan',
          controller: _transportation,
          maxLength: 1000,
        ),
        const SizedBox(height: MortSpacing.sm),
        MortTextField(
          label: 'Savings target dollars',
          controller: _savings,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: MortSpacing.md),
        MortButton(
          label: 'Save private plan',
          icon: Icons.lock_outline,
          busy: _working,
          onPressed: _save,
        ),
        const SizedBox(height: MortSpacing.sm),
        MortButton(
          label: 'Open reviewed resources',
          style: MortButtonStyle.secondary,
          icon: Icons.menu_book_outlined,
          onPressed: () => context.go('/mission/resources'),
        ),
      ],
    );
  }
}

class ResourceDirectoryScreen extends ConsumerWidget {
  const ResourceDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(missionPilotRepositoryProvider);
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Private use',
          title: 'Reviewed resources',
          subtitle:
              'MORT lists official or reviewed sources and does not invent availability claims.',
        ),
        const MortSafetyBanner(
          message:
              'Confirm services directly. Listings do not replace emergency services, legal counsel, healthcare, or qualified crisis support.',
        ),
        const SizedBox(height: MortSpacing.md),
        FutureBuilder<List<ResourceDirectoryEntry>>(
          future: repository.resources(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const MortSkeletonCard();
            }
            if (snapshot.hasError) {
              return MortErrorState(
                title: 'Resources unavailable',
                message: userFacingError(snapshot.error),
              );
            }
            final resources = snapshot.data ?? const [];
            if (resources.isEmpty) {
              return const MortEmptyState(
                title: 'No reviewed resources yet',
                message: 'MORT will not show unreviewed or invented listings.',
              );
            }
            return Column(
              children: [
                for (final resource in resources) ...[
                  MortCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MortBadge(label: _readable(resource.category)),
                        const SizedBox(height: MortSpacing.sm),
                        Text(
                          resource.organizationName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: MortSpacing.xs),
                        Text(resource.summary),
                        const SizedBox(height: MortSpacing.xs),
                        Text(
                          resource.emergencyLimitations,
                          style: const TextStyle(color: MortColors.warning),
                        ),
                        const SizedBox(height: MortSpacing.sm),
                        Wrap(
                          spacing: MortSpacing.sm,
                          runSpacing: MortSpacing.sm,
                          children: [
                            MortButton(
                              label: 'Official source',
                              fullWidth: false,
                              style: MortButtonStyle.secondary,
                              icon: Icons.open_in_new,
                              onPressed: () async {
                                final uri = safeExternalHttpsUri(
                                  resource.sourceUrl,
                                );
                                if (uri == null ||
                                    !await launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                    )) {
                                  if (context.mounted) {
                                    MortToast.show(
                                      context,
                                      'The official source could not be opened.',
                                    );
                                  }
                                }
                              },
                            ),
                            MortButton(
                              label: 'Save privately',
                              fullWidth: false,
                              style: MortButtonStyle.secondary,
                              icon: Icons.bookmark_outline,
                              onPressed: () async {
                                try {
                                  await repository.bookmarkResource(
                                    resource.id,
                                  );
                                  if (context.mounted) {
                                    MortToast.show(
                                      context,
                                      'Saved privately. Resource use is not public.',
                                    );
                                  }
                                } catch (error) {
                                  if (context.mounted) {
                                    MortToast.show(
                                      context,
                                      userFacingError(error),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
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

class PilotJobSafetyScreen extends StatelessWidget {
  const PilotJobSafetyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const allowed = [
      'Verified businesses, schools, and nonprofits',
      'Staffed community projects and public events',
      'Visible outdoor community spaces',
    ];
    const blocked = [
      'Unknown residences, isolated properties, hotels, bedrooms, or overnight work',
      'Poster-provided transportation',
      'Weapons, alcohol, drugs, roofing, dangerous heights, hazardous chemicals, or high-risk machinery',
      'Secrecy, adult services, or risk that cannot be reasonably reviewed',
    ];
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Server enforced',
          title: 'Pilot job safety',
          subtitle:
              'MORT controls pilot-job eligibility. Browser controls cannot grant marketplace access.',
        ),
        _BulletCard(
          title: 'Initially allowed settings',
          items: allowed,
          icon: Icons.check_circle_outline,
          color: MortColors.neon,
        ),
        const SizedBox(height: MortSpacing.md),
        _BulletCard(
          title: 'Blocked during the pilot',
          items: blocked,
          icon: Icons.block,
          color: MortColors.danger,
        ),
        const SizedBox(height: MortSpacing.md),
        const MortSafetyBanner(
          message:
              'A safety cancellation does not automatically damage a teen reputation. Report, block, and Safety Ping remain free.',
        ),
      ],
    );
  }
}

class VerificationExplanationScreen extends StatelessWidget {
  const VerificationExplanationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const labels = {
      'Email ownership confirmed':
          'The user controlled a confirmation link sent to that email.',
      'Phone ownership confirmed':
          'The user controlled a confirmation challenge sent to that phone.',
      'School affiliation confirmed':
          'An approved school signal supports affiliation, not government identity.',
      'Partner organization confirmed':
          'An authorized organization relationship was recorded.',
      'MORT document reviewed':
          'A reviewer inspected evidence. Authenticity and legal identity are not automatically established.',
      'Age evidence reviewed':
          'Evidence supported an age decision under the documented standard.',
      'Business registration matched':
          'Official registry data matched the reviewed business claim.',
      'Provider-backed identity verified':
          'An approved provider returned its documented assurance result.',
    };
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Truthful labels',
          title: 'What verification means',
          subtitle:
              'MORT displays precise trust signals instead of one vague Verified badge.',
        ),
        for (final item in labels.entries) ...[
          MortCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.key, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: MortSpacing.xs),
                Text(item.value),
              ],
            ),
          ),
          const SizedBox(height: MortSpacing.sm),
        ],
        const MortVerificationDisclaimer(),
      ],
    );
  }
}

class DocumentReviewStatusScreen extends ConsumerWidget {
  const DocumentReviewStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(missionPilotRepositoryProvider);
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Collection disabled',
          title: 'Document review status',
          subtitle:
              'Real identity-document collection stays off until every server-owned operational gate passes.',
        ),
        FutureBuilder<DocumentCollectionReadiness>(
          future: repository.documentReadiness(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const MortSkeletonCard();
            }
            if (snapshot.hasError) {
              return MortErrorState(
                title: 'Readiness unavailable',
                message: userFacingError(snapshot.error),
              );
            }
            final readiness = snapshot.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MortSafetyBanner(
                  message:
                      '${readiness.passedGateCount} of ${readiness.requiredGateCount} readiness gates are recorded as passed. Clients cannot enable collection.',
                ),
                const SizedBox(height: MortSpacing.sm),
                Text(readiness.truthStatement),
                const SizedBox(height: MortSpacing.md),
                const MortButton(
                  label: 'Upload identity document',
                  icon: Icons.upload_file_outlined,
                  style: MortButtonStyle.disabled,
                ),
                const SizedBox(height: MortSpacing.xs),
                const Text(
                  'Do not send identity documents by email, message, or support ticket.',
                  style: TextStyle(color: MortColors.warning),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: MortSpacing.lg),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: repository.documentCases(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const MortSkeletonCard();
            final cases = snapshot.data!;
            if (cases.isEmpty) {
              return const MortEmptyState(
                title: 'No document review cases',
                message:
                    'MORT is not collecting real identity documents in this foundation phase.',
              );
            }
            return Column(
              children: [
                for (final item in cases) ...[
                  MortCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['public_label']?.toString() ??
                              'MORT document reviewed',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        MortBadge(label: _readable('${item['status']}')),
                        Text(
                          'Established: ${item['what_was_established'] ?? 'No final decision'}',
                        ),
                        Text(
                          'Not established: ${item['what_was_not_established'] ?? 'Legal identity is not implied'}',
                        ),
                      ],
                    ),
                  ),
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

class _TruthRow extends StatelessWidget {
  const _TruthRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MortSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(color: MortColors.textMuted)),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        Text(label, style: const TextStyle(color: MortColors.textMuted)),
      ],
    );
  }
}

class _BulletCard extends StatelessWidget {
  const _BulletCard({
    required this.title,
    required this.items,
    required this.icon,
    required this.color,
  });

  final String title;
  final List<String> items;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          for (final item in items)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(icon, color: color),
              title: Text(item),
            ),
        ],
      ),
    );
  }
}

String _readable(String value) {
  if (value.isEmpty || value == 'null') return 'Unknown';
  return value
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String _money(Object? cents) {
  final value = int.tryParse('$cents') ?? 0;
  return '\$${(value / 100).toStringAsFixed(value % 100 == 0 ? 0 : 2)}';
}
