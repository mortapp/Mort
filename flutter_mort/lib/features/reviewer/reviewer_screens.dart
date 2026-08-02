import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/reviewer/reviewer_session.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';

class ReviewerRoleSelectorScreen extends ConsumerWidget {
  const ReviewerRoleSelectorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(reviewerSessionProvider);
    if (!session.isActive) return const ReviewerSessionRequiredScreen();

    return MortScreen(
      children: [
        const _ReviewerBanner(),
        const SizedBox(height: MortSpacing.md),
        const MortHeader(
          eyebrow: 'Review Role',
          title: 'Choose a synthetic experience',
          subtitle:
              'Each role uses local demonstration state. No production account, token, or data is used.',
        ),
        ...ReviewerRole.values.map(
          (role) => Padding(
            padding: const EdgeInsets.only(bottom: MortSpacing.sm),
            child: MortCard(
              onTap: () => _openRole(context, ref, role),
              child: Row(
                children: [
                  Icon(_roleIcon(role), color: MortColors.neon),
                  const SizedBox(width: MortSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          role.label,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: MortSpacing.xs),
                        Text(_roleSummary(role)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: MortSpacing.sm),
        MortButton(
          label: 'Exit Google Play Review Mode',
          icon: Icons.logout,
          style: MortButtonStyle.danger,
          onPressed: () => _exitReviewer(context, ref),
        ),
      ],
    );
  }
}

class ReviewerTeenScreen extends StatelessWidget {
  const ReviewerTeenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ReviewerRoleExperience(role: ReviewerRole.teen);
  }
}

class ReviewerAdultScreen extends StatelessWidget {
  const ReviewerAdultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ReviewerRoleExperience(role: ReviewerRole.adult);
  }
}

class ReviewerGuardianScreen extends StatelessWidget {
  const ReviewerGuardianScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ReviewerRoleExperience(role: ReviewerRole.guardian);
  }
}

class ReviewerSupportScreen extends StatelessWidget {
  const ReviewerSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ReviewerRoleExperience(role: ReviewerRole.support);
  }
}

class ReviewerAdminScreen extends StatelessWidget {
  const ReviewerAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ReviewerRoleExperience(role: ReviewerRole.admin);
  }
}

class ReviewerRoleExperience extends ConsumerWidget {
  const ReviewerRoleExperience({super.key, required this.role});

  final ReviewerRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(reviewerSessionProvider);
    if (!session.isActive) return const ReviewerSessionRequiredScreen();

    final groups = _workflowGroups(role);
    return MortScreen(
      children: [
        const _ReviewerBanner(),
        const SizedBox(height: MortSpacing.md),
        MortHeader(
          eyebrow: '${role.label} demo',
          title: '${role.label} review experience',
          subtitle: _roleSummary(role),
          trailing: Icon(_roleIcon(role), color: MortColors.neon, size: 30),
        ),
        MortDropdown<ReviewerRole>(
          label: 'Review Role',
          value: role,
          items: {for (final item in ReviewerRole.values) item: item.label},
          onChanged: (value) {
            if (value != null) _openRole(context, ref, value);
          },
        ),
        const SizedBox(height: MortSpacing.md),
        for (final group in groups) ...[
          _WorkflowGroup(role: role, group: group),
          const SizedBox(height: MortSpacing.md),
        ],
        if (role == ReviewerRole.teen || role == ReviewerRole.adult) ...[
          _ReviewerPinPanel(role: role),
          const SizedBox(height: MortSpacing.md),
          const _SyntheticPaymentPanel(),
          const SizedBox(height: MortSpacing.md),
        ],
        if (role == ReviewerRole.teen) ...[
          const _SyntheticProofPanel(),
          const SizedBox(height: MortSpacing.md),
        ],
        if (role == ReviewerRole.admin) ...[
          const _AdminBoundaryPanel(),
          const SizedBox(height: MortSpacing.md),
        ],
        Row(
          children: [
            Expanded(
              child: MortButton(
                label: 'Role selector',
                icon: Icons.switch_account,
                style: MortButtonStyle.secondary,
                onPressed: () => context.go('/review'),
              ),
            ),
            const SizedBox(width: MortSpacing.sm),
            Expanded(
              child: MortButton(
                label: 'Exit review',
                icon: Icons.logout,
                style: MortButtonStyle.danger,
                onPressed: () => _exitReviewer(context, ref),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class ReviewerSessionRequiredScreen extends StatelessWidget {
  const ReviewerSessionRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Reviewer access required',
          title: 'Review session is not active',
          subtitle:
              'Return to sign in and enter the exact Google Play reviewer identifier.',
        ),
        MortButton(
          label: 'Go to sign in',
          icon: Icons.login,
          onPressed: () => context.go('/auth/sign-in'),
        ),
      ],
    );
  }
}

class _ReviewerBanner extends StatelessWidget {
  const _ReviewerBanner();

  @override
  Widget build(BuildContext context) {
    return const MortCard(
      color: MortColors.cardAlt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MortBadge(
            label: 'Google Play Review Mode',
            color: MortColors.warning,
            icon: Icons.verified_user,
          ),
          SizedBox(height: MortSpacing.sm),
          Text(
            'Synthetic demonstration data',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: MortSpacing.xs),
          Text('No real financial or administrative actions'),
        ],
      ),
    );
  }
}

class _WorkflowGroup extends ConsumerWidget {
  const _WorkflowGroup({required this.role, required this.group});

  final ReviewerRole role;
  final _DemoGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(reviewerSessionProvider);
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(group.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: MortSpacing.xs),
          Text(group.description),
          const SizedBox(height: MortSpacing.sm),
          for (final item in group.items)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: session.completedActions.contains(
                '${role.name}-${item.id}',
              ),
              title: Text(item.title),
              subtitle: Text(item.description),
              onChanged: (_) {
                ref
                    .read(reviewerSessionProvider)
                    .toggleAction('${role.name}-${item.id}');
              },
            ),
        ],
      ),
    );
  }
}

class _ReviewerPinPanel extends ConsumerStatefulWidget {
  const _ReviewerPinPanel({required this.role});

  final ReviewerRole role;

  @override
  ConsumerState<_ReviewerPinPanel> createState() => _ReviewerPinPanelState();
}

class _ReviewerPinPanelState extends ConsumerState<_ReviewerPinPanel> {
  final _startPin = TextEditingController();
  final _completionPin = TextEditingController();

  @override
  void dispose() {
    _startPin.dispose();
    _completionPin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(reviewerSessionProvider);
    final adult = widget.role == ReviewerRole.adult;
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Demo job PINs', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: MortSpacing.xs),
          const Text(
            'These deterministic codes exist only in local reviewer state. Production job verification never receives them.',
          ),
          const SizedBox(height: MortSpacing.md),
          if (adult) ...[
            const SelectableText('START PIN: 123456'),
            const SizedBox(height: MortSpacing.sm),
            MortButton(
              label: session.startPinAccepted
                  ? 'START PIN displayed'
                  : 'Display START PIN',
              icon: Icons.pin,
              style: MortButtonStyle.secondary,
              onPressed: () {
                ref
                    .read(reviewerSessionProvider)
                    .confirmStartPin(reviewerStartPin);
              },
            ),
            const SizedBox(height: MortSpacing.md),
            const SelectableText('COMPLETION PIN: 654321'),
            const SizedBox(height: MortSpacing.sm),
            MortButton(
              label: session.completionPinAccepted
                  ? 'COMPLETION PIN displayed'
                  : 'Display COMPLETION PIN',
              icon: Icons.task_alt,
              style: MortButtonStyle.secondary,
              onPressed: () {
                ref
                    .read(reviewerSessionProvider)
                    .confirmCompletionPin(reviewerCompletionPin);
              },
            ),
          ] else ...[
            MortTextField(
              label: 'START PIN',
              controller: _startPin,
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
            MortButton(
              label: session.startPinAccepted
                  ? 'Job started in demo'
                  : 'Confirm demo START PIN',
              icon: Icons.play_arrow,
              onPressed: () {
                final accepted = ref
                    .read(reviewerSessionProvider)
                    .confirmStartPin(_startPin.text);
                MortToast.show(
                  context,
                  accepted
                      ? 'Demo START PIN accepted.'
                      : 'Use demo PIN 123456.',
                );
              },
            ),
            const SizedBox(height: MortSpacing.md),
            MortTextField(
              label: 'COMPLETION PIN',
              controller: _completionPin,
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
            MortButton(
              label: session.completionPinAccepted
                  ? 'Job completed in demo'
                  : 'Confirm demo COMPLETION PIN',
              icon: Icons.task_alt,
              onPressed: () {
                final accepted = ref
                    .read(reviewerSessionProvider)
                    .confirmCompletionPin(_completionPin.text);
                MortToast.show(
                  context,
                  accepted
                      ? 'Demo COMPLETION PIN accepted.'
                      : 'Use demo PIN 654321.',
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _SyntheticPaymentPanel extends ConsumerWidget {
  const _SyntheticPaymentPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(reviewerSessionProvider);
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Synthetic payment timeline',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: MortSpacing.sm),
          MortBadge(
            label: session.paymentState,
            color: MortColors.safetyBlue,
            icon: Icons.receipt_long,
          ),
          const SizedBox(height: MortSpacing.md),
          const Text(
            'Demonstration only - no real payment was created.',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: MortSpacing.sm),
          const Text(
            'No Stripe customer, card, bank account, payout, refund, or payment credential is created or contacted.',
          ),
          const SizedBox(height: MortSpacing.md),
          MortButton(
            label: 'Advance synthetic payment state',
            icon: Icons.fast_forward,
            style: MortButtonStyle.secondary,
            onPressed: () =>
                ref.read(reviewerSessionProvider).advanceSyntheticPayment(),
          ),
        ],
      ),
    );
  }
}

class _SyntheticProofPanel extends ConsumerWidget {
  const _SyntheticProofPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(reviewerSessionProvider);
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Local proof demo',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: MortSpacing.xs),
          const Text(
            'The demo generates a local synthetic proof card. It does not open real evidence or upload to Storage.',
          ),
          if (session.syntheticProofAttached) ...[
            const SizedBox(height: MortSpacing.md),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.image, color: MortColors.neon),
              title: Text('synthetic-yard-proof.jpg'),
              subtitle: Text(
                'Generated demonstration file - local session only',
              ),
              trailing: Icon(Icons.check_circle, color: MortColors.neon),
            ),
          ],
          const SizedBox(height: MortSpacing.md),
          MortButton(
            label: session.syntheticProofAttached
                ? 'Synthetic proof attached'
                : 'Attach synthetic proof',
            icon: Icons.add_photo_alternate,
            style: MortButtonStyle.secondary,
            onPressed: session.syntheticProofAttached
                ? null
                : () =>
                      ref.read(reviewerSessionProvider).attachSyntheticProof(),
          ),
        ],
      ),
    );
  }
}

class _AdminBoundaryPanel extends StatelessWidget {
  const _AdminBoundaryPanel();

  @override
  Widget build(BuildContext context) {
    return const MortCard(
      color: MortColors.cardAlt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MortBadge(
            label: 'Read-only simulation',
            color: MortColors.warning,
            icon: Icons.lock,
          ),
          SizedBox(height: MortSpacing.sm),
          Text(
            'This is not a production administrator session.',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: MortSpacing.xs),
          Text(
            'Controls change local checkmarks only. Production users, cases, evidence, payments, flags, and settings are unreachable.',
          ),
        ],
      ),
    );
  }
}

void _openRole(BuildContext context, WidgetRef ref, ReviewerRole role) {
  ref.read(reviewerSessionProvider).selectRole(role);
  context.go(role.route);
}

void _exitReviewer(BuildContext context, WidgetRef ref) {
  ref.read(reviewerSessionProvider).exit();
  context.go('/auth/sign-in');
}

IconData _roleIcon(ReviewerRole role) => switch (role) {
  ReviewerRole.teen => Icons.school,
  ReviewerRole.adult => Icons.work,
  ReviewerRole.guardian => Icons.family_restroom,
  ReviewerRole.support => Icons.support_agent,
  ReviewerRole.admin => Icons.admin_panel_settings,
};

String _roleSummary(ReviewerRole role) => switch (role) {
  ReviewerRole.teen =>
    'Browse, apply, complete a synthetic job, use safety tools, and review payout status.',
  ReviewerRole.adult =>
    'Post a synthetic job, review applicants, coordinate work, and inspect demonstration receipts.',
  ReviewerRole.guardian =>
    'Explore optional Guardian Mode, safety notices, assistance, preferences, and unlinking.',
  ReviewerRole.support =>
    'Review synthetic cases, messages, attachments, escalation, resolution, and reopening.',
  ReviewerRole.admin =>
    'Inspect read-only simulated moderation, payment, audit, alert, and shutdown controls.',
};

List<_DemoGroup> _workflowGroups(ReviewerRole role) => switch (role) {
  ReviewerRole.teen => _teenGroups,
  ReviewerRole.adult => _adultGroups,
  ReviewerRole.guardian => _guardianGroups,
  ReviewerRole.support => _supportGroups,
  ReviewerRole.admin => _adminGroups,
};

class _DemoGroup {
  const _DemoGroup(this.title, this.description, this.items);

  final String title;
  final String description;
  final List<_DemoItem> items;
}

class _DemoItem {
  const _DemoItem(this.id, this.title, this.description);

  final String id;
  final String title;
  final String description;
}

const _teenGroups = <_DemoGroup>[
  _DemoGroup('Getting started', 'Synthetic teen account setup.', [
    _DemoItem(
      'onboarding',
      'Complete onboarding',
      'Age 16, teen role, and safety rules acknowledged.',
    ),
    _DemoItem(
      'profile',
      'Review profile and avatar',
      'Jordan, lawn care and pet help, synthetic avatar.',
    ),
    _DemoItem(
      'guardian',
      'Optional guardian connection',
      'Avery is shown as a synthetic linked guardian.',
    ),
  ]),
  _DemoGroup('Find and apply', 'A closed demonstration job feed.', [
    _DemoItem(
      'jobs',
      'Browse jobs',
      'Three synthetic nearby jobs are available.',
    ),
    _DemoItem(
      'filters',
      'Apply filters',
      'Weekend, outdoor, verified poster, and fixed-pay filters.',
    ),
    _DemoItem(
      'details',
      'Open job details',
      'Yard cleanup at a public-facing location, Saturday at 10 AM.',
    ),
    _DemoItem(
      'apply',
      'Submit application',
      'Synthetic availability and short proposal recorded locally.',
    ),
    _DemoItem(
      'accepted',
      'View accepted job',
      'Application accepted by Green Corner Market demo account.',
    ),
  ]),
  _DemoGroup('Do the work', 'Interactive local progress and proof state.', [
    _DemoItem(
      'active',
      'Open active job',
      'Agreed scope and contact-safe schedule displayed.',
    ),
    _DemoItem(
      'progress',
      'Complete progress checklist',
      'Arrival, safety check, cleanup, and poster review.',
    ),
    _DemoItem(
      'completion-request',
      'Request completion',
      'Synthetic completion request placed locally.',
    ),
  ]),
  _DemoGroup('After the job', 'Synthetic support and account controls.', [
    _DemoItem(
      'messages',
      'Open job messaging',
      'Contact details and unsafe content remain blocked.',
    ),
    _DemoItem(
      'support',
      'Open support',
      'Create a synthetic general-help case.',
    ),
    _DemoItem(
      'dispute',
      'Open dispute',
      'Review a synthetic scope-change dispute.',
    ),
    _DemoItem(
      'safety',
      'Use Safety Ping and block/report',
      'Safety controls are always available without payment.',
    ),
    _DemoItem(
      'notifications',
      'Review notifications',
      'Acceptance, schedule, safety, and payout demo notices.',
    ),
    _DemoItem(
      'settings',
      'Review settings',
      'Privacy, notification, accessibility, and session controls.',
    ),
    _DemoItem(
      'delete-account',
      'Read account deletion explanation',
      'Production deletion would require reauthentication and server cleanup; no action occurs here.',
    ),
  ]),
];

const _adultGroups = <_DemoGroup>[
  _DemoGroup('Business setup', 'Synthetic adult and business profile state.', [
    _DemoItem(
      'onboarding',
      'Complete adult onboarding',
      'Adult role and business purpose confirmed.',
    ),
    _DemoItem(
      'profile',
      'Review business profile',
      'Green Corner Market synthetic profile.',
    ),
    _DemoItem(
      'verification',
      'Review verification status',
      'Provider verification is shown as demonstration-only approved.',
    ),
    _DemoItem(
      'payment-method',
      'Review saved payment method',
      'A non-card synthetic payment method is marked ready.',
    ),
  ]),
  _DemoGroup('Hire safely', 'Local-only job and applicant workflow.', [
    _DemoItem(
      'post-job',
      'Post a job',
      'Create a synthetic yard cleanup listing.',
    ),
    _DemoItem(
      'applicants',
      'Review applicants',
      'Compare three synthetic applicants and safety signals.',
    ),
    _DemoItem(
      'accept',
      'Accept applicant',
      'Jordan is selected without contacting production.',
    ),
    _DemoItem(
      'schedule',
      'Set schedule',
      'Saturday at 10 AM with a public arrival point.',
    ),
    _DemoItem(
      'scope',
      'Review scope change',
      'Add bagging leaves with synthetic mutual approval.',
    ),
    _DemoItem(
      'completion',
      'Review completion',
      'Synthetic checklist and proof card ready for review.',
    ),
  ]),
  _DemoGroup(
    'Closeout and help',
    'Simulated operations with no financial calls.',
    [
      _DemoItem(
        'cancel',
        'Preview cancellation',
        'Shows policy outcome without canceling a real job.',
      ),
      _DemoItem(
        'partial',
        'Preview partial compensation',
        'Synthetic partial-compensation state only.',
      ),
      _DemoItem(
        'receipts',
        'Open receipts',
        'Demonstration receipt contains no Stripe identifiers.',
      ),
      _DemoItem(
        'messages',
        'Open messaging',
        'Synthetic participant messages with safety scanning.',
      ),
      _DemoItem(
        'disputes',
        'Open disputes',
        'Synthetic dispute timeline and evidence summary.',
      ),
      _DemoItem(
        'support',
        'Open support',
        'Synthetic support request and reply.',
      ),
      _DemoItem(
        'notifications',
        'Review notifications',
        'Applicant, schedule, proof, and payment demo notices.',
      ),
      _DemoItem(
        'settings',
        'Review settings',
        'Business, privacy, notification, and account controls.',
      ),
    ],
  ),
];

const _guardianGroups = <_DemoGroup>[
  _DemoGroup(
    'Optional Guardian Mode',
    'Guardian Mode is optional and does not grant account ownership.',
    [
      _DemoItem(
        'onboarding',
        'Complete optional onboarding',
        'Review supervision boundaries and consent copy.',
      ),
      _DemoItem(
        'link-request',
        'Review teen-link request',
        'Synthetic request from Jordan is available.',
      ),
      _DemoItem(
        'summary',
        'Open linked-teen summary',
        'Schedule and coarse safety status, without private messages.',
      ),
      _DemoItem(
        'safety',
        'Review safety notifications',
        'Synthetic Safety Ping and overdue check-in examples.',
      ),
      _DemoItem(
        'payout',
        'Review payout assistance',
        'Guidance status only; no banking or payout access.',
      ),
      _DemoItem(
        'dispute',
        'Review dispute assistance',
        'Help Jordan understand the synthetic case timeline.',
      ),
      _DemoItem(
        'support',
        'Contact support',
        'Open a synthetic guardian-assistance case.',
      ),
      _DemoItem(
        'preferences',
        'Set notification preferences',
        'Toggle schedule, safety, and payout-help notices locally.',
      ),
      _DemoItem(
        'unlink',
        'Preview unlinking',
        'Explains effects and changes only synthetic session state.',
      ),
    ],
  ),
];

const _supportGroups = <_DemoGroup>[
  _DemoGroup(
    'Support workspace',
    'All cases, people, and evidence below are synthetic.',
    [
      _DemoItem(
        'queue',
        'Open support queue',
        'General, payment-help, dispute, and safety-critical examples.',
      ),
      _DemoItem(
        'case',
        'Review case details',
        'Synthetic case MORT-DEMO-1042.',
      ),
      _DemoItem(
        'messages',
        'Send user-visible message',
        'Adds a local completion check only.',
      ),
      _DemoItem(
        'attachments',
        'Review attachments',
        'Generated proof summaries; no Storage download.',
      ),
      _DemoItem(
        'escalate',
        'Escalate case',
        'Simulates assignment to safety operations.',
      ),
      _DemoItem(
        'status',
        'Change case status',
        'Simulates open, waiting, escalated, and resolved.',
      ),
      _DemoItem(
        'resolve',
        'Resolve case',
        'Records a local simulated resolution.',
      ),
      _DemoItem('reopen', 'Reopen case', 'Reopens only the synthetic case.'),
      _DemoItem(
        'safety-critical',
        'Review safety-critical presentation',
        'Shows urgent guidance and emergency-service boundary without real incident data.',
      ),
    ],
  ),
];

const _adminGroups = <_DemoGroup>[
  _DemoGroup('Read-only operations', 'Every control is simulated and local.', [
    _DemoItem(
      'support-queue',
      'Review support queue',
      'Synthetic queue summaries only.',
    ),
    _DemoItem(
      'dispute-queue',
      'Review dispute queue',
      'Synthetic cases and status labels.',
    ),
    _DemoItem(
      'evidence',
      'Open evidence viewer',
      'Generated evidence cards; no production bucket access.',
    ),
    _DemoItem(
      'payment-timeline',
      'Review payment timeline',
      'Synthetic provider-neutral events.',
    ),
    _DemoItem(
      'adjudication',
      'Preview adjudication form',
      'No decision is submitted.',
    ),
    _DemoItem(
      'appeals',
      'Review appeals',
      'Synthetic appeal history and rationale.',
    ),
    _DemoItem(
      'restriction',
      'Preview account restriction',
      'No user or session is modified.',
    ),
    _DemoItem(
      'audit',
      'Review audit log',
      'Local synthetic actor and action records.',
    ),
    _DemoItem(
      'alerts',
      'Review operational alerts',
      'Synthetic PIN abuse and service health alerts.',
    ),
    _DemoItem(
      'shutdown',
      'Preview marketplace shutdown',
      'No feature flag or marketplace state changes.',
    ),
    _DemoItem(
      'ai-disable',
      'Preview AI disable',
      'No provider or server configuration changes.',
    ),
    _DemoItem(
      'payment-disable',
      'Preview payment disable',
      'No Stripe or payment configuration changes.',
    ),
  ]),
];
