import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/repositories/providers.dart';
import '../../data/repositories/support_repository.dart';

const supportCategories = <String, String>{
  'account_sign_in': 'Account and sign-in',
  'profile_avatar': 'Profile or profile picture',
  'verification': 'Verification',
  'job_application': 'Job application',
  'start_finish_pin': 'Start or finish PIN',
  'job_cancellation': 'Job cancellation',
  'payment_compensation': 'Payment or compensation',
  'adult_refused_completion': 'Adult refused completion',
  'teen_abandonment': 'Teen abandonment report',
  'evidence_submission': 'Evidence submission',
  'report_block': 'Report or block',
  'privacy_deletion': 'Privacy or account deletion',
  'mort_plus_play_billing': 'MORT Plus and Play Billing',
  'other': 'Other',
};

const _supportTopics = <_SupportTopic>[
  _SupportTopic(
    'Account access',
    Icons.lock_person_outlined,
    '/support/new?category=account_sign_in',
  ),
  _SupportTopic(
    'Jobs and applications',
    Icons.work_outline,
    '/support/new?category=job_application',
  ),
  _SupportTopic(
    'Start and finish PINs',
    Icons.pin_outlined,
    '/support/new?category=start_finish_pin',
  ),
  _SupportTopic(
    'Safety and reports',
    Icons.health_and_safety_outlined,
    '/safety',
    safety: true,
  ),
  _SupportTopic(
    'Verification',
    Icons.verified_user_outlined,
    '/support/new?category=verification',
  ),
  _SupportTopic(
    'Guardian Mode',
    Icons.supervised_user_circle_outlined,
    '/settings/guardian-mode',
  ),
  _SupportTopic(
    'Payment questions',
    Icons.payments_outlined,
    '/support/new?category=payment_compensation',
  ),
  _SupportTopic(
    'App problem',
    Icons.mobile_friendly_outlined,
    '/support/new?category=other',
  ),
];

class _SupportTopic {
  const _SupportTopic(this.label, this.icon, this.route, {this.safety = false});

  final String label;
  final IconData icon;
  final String route;
  final bool safety;
}

class SupportHomeScreen extends ConsumerStatefulWidget {
  const SupportHomeScreen({super.key});

  @override
  ConsumerState<SupportHomeScreen> createState() => _SupportHomeScreenState();
}

class _SupportHomeScreenState extends ConsumerState<SupportHomeScreen> {
  Future<List<SupportTicket>>? _tickets;
  Future<SupportServiceStatus>? _serviceStatus;
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    if (ref.read(authRepositoryProvider).currentUser != null) _reload();
  }

  void _reload() {
    setState(() {
      _tickets = ref.read(supportRepositoryProvider).listTickets();
      _serviceStatus = ref.read(supportRepositoryProvider).getServiceStatus();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    return MortScreen(
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: MortBrandMark(size: 46),
        ),
        const SizedBox(height: MortSpacing.xs),
        MortHeader(
          eyebrow: 'Private support',
          title: 'MORT Support',
          subtitle:
              'Approved self-service help and private human-reviewed support cases.',
          trailing: user == null
              ? null
              : MortIconButton(
                  icon: Icons.add_comment_outlined,
                  tooltip: 'Open a new support case',
                  onPressed: () => context.go('/support/new'),
                ),
        ),
        const MortSafetyBanner(
          message:
              'MORT Support is not emergency, medical, or legal assistance. If anyone may be in immediate danger, contact local emergency services. MORT has not dispatched help.',
        ),
        if (_serviceStatus != null) ...[
          const SizedBox(height: MortSpacing.sm),
          FutureBuilder<SupportServiceStatus>(
            future: _serviceStatus,
            builder: (context, snapshot) {
              final status = snapshot.data;
              if (status == null) return const SizedBox.shrink();
              return MortCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.targetsAreCommitments
                          ? 'Published Support availability'
                          : 'Support staffing status',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: MortSpacing.xs),
                    Text('${status.hoursDisplay} (${status.timezone})'),
                    Text(
                      status.responseMessage,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
        const SizedBox(height: MortSpacing.md),
        MortActionRow(
          actions: [
            const MortAction(
              label: 'Chat with MORT Support',
              icon: Icons.assistant_outlined,
              route: '/support/chat',
            ),
            MortAction(
              label: 'Safety Center',
              icon: Icons.health_and_safety_outlined,
              route: '/safety',
              style: MortButtonStyle.danger,
            ),
            MortAction(
              label: 'Email fallback',
              icon: Icons.email_outlined,
              onPressed: () => _openSupportEmail(context, email: user?.email),
            ),
          ],
        ),
        const SizedBox(height: MortSpacing.md),
        MortTextField(
          label: 'Search support topics',
          controller: _search,
          onChanged: (value) =>
              setState(() => _query = value.trim().toLowerCase()),
        ),
        const SizedBox(height: MortSpacing.md),
        const MortSectionTitle(title: 'Help by topic'),
        for (final topic in _supportTopics.where(
          (topic) =>
              _query.isEmpty || topic.label.toLowerCase().contains(_query),
        )) ...[
          MortCard(
            onTap: () => context.go(topic.route),
            child: Row(
              children: [
                Icon(
                  topic.icon,
                  color: topic.safety
                      ? MortColors.danger
                      : MortColors.lightBlue,
                ),
                const SizedBox(width: MortSpacing.sm),
                Expanded(child: Text(topic.label)),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
          const SizedBox(height: MortSpacing.xs),
        ],
        MortCard(
          onTap: () => context.go('/jobs'),
          child: const Row(
            children: [
              Icon(Icons.history_outlined, color: MortColors.lightBlue),
              SizedBox(width: MortSpacing.sm),
              Expanded(child: Text('Recent job help')),
              Icon(Icons.chevron_right),
            ],
          ),
        ),
        const SizedBox(height: MortSpacing.md),
        if (user == null) ...[
          const MortEmptyState(
            title: 'Sign in for private support',
            message:
                'Case history, chat transcripts, account-aware status, and evidence are available only after sign-in.',
          ),
          const SizedBox(height: MortSpacing.md),
          MortButton(
            label: 'Sign in',
            icon: Icons.login,
            onPressed: () => context.go('/auth/sign-in'),
          ),
        ] else ...[
          MortButton(
            label: 'Contact a support person',
            icon: Icons.support_agent,
            onPressed: () => context.go('/support/new'),
          ),
          const SizedBox(height: MortSpacing.sm),
          MortButton(
            label: 'Open Support Assistant',
            icon: Icons.auto_awesome_outlined,
            style: MortButtonStyle.secondary,
            onPressed: () => context.go('/support/chat'),
          ),
          const SizedBox(height: MortSpacing.lg),
          const MortSectionTitle(title: 'Your support history'),
          FutureBuilder<List<SupportTicket>>(
            future: _tickets,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const MortLoading(
                  label: 'Loading support cases...',
                  fullScreen: false,
                );
              }
              if (snapshot.hasError) {
                return MortErrorState(
                  title: 'Support history unavailable',
                  message: userFacingError(snapshot.error),
                  action: MortButton(
                    label: 'Retry',
                    icon: Icons.refresh,
                    onPressed: _reload,
                  ),
                );
              }
              final tickets = snapshot.data ?? const [];
              if (tickets.isEmpty) {
                return const MortEmptyState(
                  title: 'No support cases yet',
                  message:
                      'MORT Guide can answer approved FAQs, or open a private case for human review.',
                );
              }
              return Column(
                children: [
                  for (final ticket in tickets) ...[
                    MortCard(
                      onTap: () => context.go('/support/ticket/${ticket.id}'),
                      child: Row(
                        children: [
                          const Icon(Icons.forum_outlined),
                          const SizedBox(width: MortSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ticket.subject,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: MortSpacing.xs),
                                Text(ticket.caseNumber),
                                Text(
                                  supportCategories[ticket.category] ?? 'Other',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          MortBadge(label: _label(ticket.status)),
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
      ],
    );
  }
}

class NewSupportConversationScreen extends ConsumerStatefulWidget {
  const NewSupportConversationScreen({
    super.key,
    this.relatedJobId,
    this.relatedApplicationId,
    this.relatedContractId,
    this.relatedDisputeId,
    this.initialCategory,
  });

  final String? relatedJobId;
  final String? relatedApplicationId;
  final String? relatedContractId;
  final String? relatedDisputeId;
  final String? initialCategory;

  @override
  ConsumerState<NewSupportConversationScreen> createState() =>
      _NewSupportConversationScreenState();
}

class _NewSupportConversationScreenState
    extends ConsumerState<NewSupportConversationScreen> {
  final _form = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  late String _category;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _category = supportCategories.containsKey(widget.initialCategory)
        ? widget.initialCategory!
        : 'other';
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final ticket = await ref
          .read(supportRepositoryProvider)
          .createConversation(
            category: _category,
            subject: _subject.text,
            message: _message.text,
            source: 'automated_support',
            relatedJobId: widget.relatedJobId,
            relatedApplicationId: widget.relatedApplicationId,
            relatedContractId: widget.relatedContractId,
            relatedDisputeId: widget.relatedDisputeId,
          );
      if (mounted) context.go('/support/ticket/${ticket.id}');
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => MortScreen(
    children: [
      const Center(child: MortBrandMark(size: 64, showWordmark: true)),
      const SizedBox(height: MortSpacing.md),
      const MortHeader(
        eyebrow: 'New private case',
        title: 'How can MORT help?',
        subtitle:
            'Ask one focused question. A human has not reviewed the case unless the case says otherwise.',
      ),
      const MortSafetyBanner(
        message:
            'Do not include passwords, verification codes, payment tokens, government IDs, exact addresses, or unrelated private messages.',
      ),
      const SizedBox(height: MortSpacing.md),
      Wrap(
        spacing: MortSpacing.sm,
        runSpacing: MortSpacing.sm,
        children: [
          for (final suggestion in const [
            ('profile_avatar', 'My picture will not update'),
            ('start_finish_pin', 'A job PIN is not working'),
            ('payment_compensation', 'Check payment status'),
            ('report_block', 'Report or block someone'),
          ])
            ActionChip(
              label: Text(suggestion.$2),
              onPressed: () => setState(() {
                _category = suggestion.$1;
                _subject.text = suggestion.$2;
              }),
            ),
        ],
      ),
      const SizedBox(height: MortSpacing.md),
      Form(
        key: _form,
        child: Column(
          children: [
            MortDropdown<String>(
              label: 'Support category',
              value: _category,
              items: supportCategories,
              onChanged: (value) =>
                  setState(() => _category = value ?? 'other'),
            ),
            const SizedBox(height: MortSpacing.sm),
            MortTextField(
              label: 'Case subject',
              controller: _subject,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              validator: (value) => MortValidators.requiredText(
                value,
                minimumLength: 4,
                maximumLength: 120,
              ),
            ),
            const SizedBox(height: MortSpacing.sm),
            MortTextArea(
              label: 'What happened?',
              hint: 'Share the relevant facts and what you need help with.',
              controller: _message,
              maxLines: 7,
              maxLength: 2000,
              validator: (value) => MortValidators.requiredText(
                value,
                minimumLength: 10,
                maximumLength: 2000,
              ),
            ),
            const SizedBox(height: MortSpacing.md),
            MortButton(
              label: 'Create private case',
              busyLabel: 'Creating case...',
              busy: _busy,
              icon: Icons.lock_outline,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    ],
  );
}

class SupportTicketScreen extends ConsumerStatefulWidget {
  const SupportTicketScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  ConsumerState<SupportTicketScreen> createState() =>
      _SupportTicketScreenState();
}

class _SupportTicketScreenState extends ConsumerState<SupportTicketScreen> {
  final _message = TextEditingController();
  late Future<SupportThread> _thread;
  bool _sending = false;
  bool _evidenceBusy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  void _reload() {
    _thread = ref.read(supportRepositoryProvider).getThread(widget.ticketId);
  }

  Future<void> _send([String? quickReply]) async {
    final body = (quickReply ?? _message.text).trim();
    if (_sending || body.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(supportRepositoryProvider)
          .postMessage(widget.ticketId, body);
      _message.clear();
      setState(_reload);
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _requestHuman() async {
    setState(() => _sending = true);
    try {
      await ref
          .read(supportRepositoryProvider)
          .requestHumanReview(widget.ticketId);
      setState(_reload);
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _reopen() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _SupportReasonDialog(
        title: 'Reopen this support case',
        actionLabel: 'Reopen case',
        minimumLength: 10,
      ),
    );
    if (reason == null || !mounted) return;
    setState(() => _sending = true);
    try {
      await ref.read(supportRepositoryProvider).reopen(widget.ticketId, reason);
      if (mounted) {
        MortToast.show(context, 'Support case reopened for review.');
        setState(_reload);
      }
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _appeal() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _SupportReasonDialog(
        title: 'Appeal this support outcome',
        actionLabel: 'Create appeal',
        minimumLength: 10,
        maxLength: 1000,
      ),
    );
    if (reason == null || !mounted) return;
    setState(() => _sending = true);
    try {
      final appeal = await ref
          .read(supportRepositoryProvider)
          .appeal(widget.ticketId, reason);
      if (mounted) context.go('/support/ticket/${appeal.id}');
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _addEvidence(SupportTicket ticket, ImageSource source) async {
    if (_evidenceBusy || ticket.relatedDisputeId == null) return;
    if (source == ImageSource.camera) {
      final continueToCamera = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Use camera for evidence'),
          content: const Text(
            'MORT uses your camera to capture the photo you choose to submit. Do not include unrelated documents, faces, exact addresses, full payment-card information, or other sensitive information.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Use camera'),
            ),
          ],
        ),
      );
      if (continueToCamera != true || !mounted) return;
    }
    setState(() => _evidenceBusy = true);
    try {
      final repository = ref.read(supportRepositoryProvider);
      final file = await repository.chooseEvidence(source: source);
      if (file == null) return;
      final draft = await repository.createEvidenceDraft(
        ticketId: ticket.id,
        disputeId: ticket.relatedDisputeId!,
        category: 'work_result',
        file: file,
        statement: 'User-submitted support evidence for ${ticket.caseNumber}',
      );
      if (!mounted) return;
      final submit = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Submit this private evidence?'),
          content: const Text(
            'The image was decoded, resized, stripped of metadata, re-encoded as JPEG, and registered as a private draft. Once submitted to the dispute, it may be preserved and may not be immediately removable.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Remove draft'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Submit for review'),
            ),
          ],
        ),
      );
      if (submit == true) {
        await repository.submitEvidence(draft.id);
      } else {
        await repository.removeDraftEvidence(draft);
      }
      if (mounted) {
        MortToast.show(
          context,
          submit == true
              ? 'Evidence submitted for private review. It may now be preserved.'
              : 'Unsubmitted evidence draft removed.',
        );
        setState(_reload);
      }
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _evidenceBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<SupportThread>(
    future: _thread,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const MortLoading(label: 'Opening private support case...');
      }
      if (snapshot.hasError || snapshot.data == null) {
        return MortScreen(
          children: [
            MortErrorState(
              title: 'Support case unavailable',
              message: userFacingError(snapshot.error),
              action: MortButton(
                label: 'Back to support',
                icon: Icons.arrow_back,
                onPressed: () => context.go('/support'),
              ),
            ),
          ],
        );
      }
      final thread = snapshot.data!;
      final ticket = thread.ticket;
      return MortScreen(
        children: [
          MortHeader(
            eyebrow: ticket.caseNumber,
            title: ticket.subject,
            subtitle:
                '${supportCategories[ticket.category] ?? 'Other'} - ${_label(ticket.status)}',
            trailing: MortBadge(label: _label(ticket.status)),
          ),
          MortCard(
            color: ticket.humanReviewed
                ? MortColors.safetyBlue.withValues(alpha: 0.12)
                : MortColors.warning.withValues(alpha: 0.12),
            child: Text(
              ticket.humanReviewed
                  ? 'A MORT support team member has reviewed this case.'
                  : 'A human has not reviewed this case yet. Automated help and case creation do not prove an investigation or payment result.',
            ),
          ),
          const SizedBox(height: MortSpacing.md),
          for (final item in thread.messages) ...[
            _SupportBubble(message: item),
            const SizedBox(height: MortSpacing.sm),
          ],
          if (_sending) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: MortBadge(label: 'Sending...', icon: Icons.more_horiz),
            ),
            const SizedBox(height: MortSpacing.sm),
          ],
          if (!ticket.isClosed) ...[
            Wrap(
              spacing: MortSpacing.sm,
              runSpacing: MortSpacing.sm,
              children: [
                for (final reply in const [
                  'I still need help with this.',
                  'The status has changed.',
                  'Please explain the next step.',
                ])
                  ActionChip(label: Text(reply), onPressed: () => _send(reply)),
              ],
            ),
            const SizedBox(height: MortSpacing.sm),
            MortTextArea(
              label: 'Reply to this case',
              controller: _message,
              maxLines: 4,
              maxLength: 2000,
            ),
            const SizedBox(height: MortSpacing.sm),
            MortButton(
              label: 'Send reply',
              icon: Icons.send_outlined,
              busy: _sending,
              onPressed: _sending ? null : _send,
            ),
          ],
          const SizedBox(height: MortSpacing.md),
          MortActionRow(
            actions: [
              MortAction(
                label: 'Request human review',
                icon: Icons.support_agent,
                enabled: !ticket.humanReviewed && !ticket.isClosed,
                busy: _sending,
                onPressed: _requestHuman,
              ),
              if (ticket.status == 'closed')
                MortAction(
                  label: 'Reopen case',
                  icon: Icons.lock_open_outlined,
                  busy: _sending,
                  onPressed: _reopen,
                ),
              if (ticket.isTerminal && !ticket.isAppeal)
                MortAction(
                  label: 'Appeal outcome',
                  icon: Icons.gavel_outlined,
                  busy: _sending,
                  onPressed: _appeal,
                ),
              if (ticket.canUploadEvidence)
                MortAction(
                  label: 'Choose evidence photo',
                  icon: Icons.add_photo_alternate_outlined,
                  busy: _evidenceBusy,
                  onPressed: () => _addEvidence(ticket, ImageSource.gallery),
                ),
              if (ticket.canUploadEvidence)
                MortAction(
                  label: 'Take evidence photo',
                  icon: Icons.camera_alt_outlined,
                  busy: _evidenceBusy,
                  onPressed: () => _addEvidence(ticket, ImageSource.camera),
                ),
              MortAction(
                label: 'Email fallback',
                icon: Icons.email_outlined,
                onPressed: () => _openSupportEmail(
                  context,
                  caseNumber: ticket.caseNumber,
                  email: ref.read(authRepositoryProvider).currentUser?.email,
                  jobId: ticket.relatedJobId,
                  applicationId: ticket.relatedApplicationId,
                  contractId: ticket.relatedContractId,
                ),
              ),
              MortAction(
                label: 'Safety Center',
                icon: Icons.health_and_safety_outlined,
                route: '/safety',
                style: MortButtonStyle.danger,
              ),
            ],
          ),
          if (ticket.canUploadEvidence) ...[
            const SizedBox(height: MortSpacing.sm),
            Text(
              '${ticket.safeAttachmentCount} of 8 safe image attachments submitted. Submitted dispute evidence may be preserved and may not be immediately removable.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      );
    },
  );
}

class _SupportBubble extends StatelessWidget {
  const _SupportBubble({required this.message});

  final SupportTicketMessage message;

  @override
  Widget build(BuildContext context) {
    final user = message.isUser;
    final label = message.isHumanStaff
        ? 'MORT Support'
        : message.senderKind == 'automated_support'
        ? 'Automated MORT help'
        : user
        ? 'You'
        : 'MORT';
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: MortCard(
          color: user ? MortColors.neonDeep : MortColors.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: user ? MortColors.text : MortColors.neon,
                ),
              ),
              const SizedBox(height: MortSpacing.xs),
              Text(message.body),
              if (message.safeAttachmentCount > 0) ...[
                const SizedBox(height: MortSpacing.xs),
                Text('${message.safeAttachmentCount} private attachment(s)'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AdminSupportQueueScreen extends ConsumerStatefulWidget {
  const AdminSupportQueueScreen({super.key});

  @override
  ConsumerState<AdminSupportQueueScreen> createState() =>
      _AdminSupportQueueScreenState();
}

class _AdminSupportQueueScreenState
    extends ConsumerState<AdminSupportQueueScreen> {
  String? _status;
  String _queuePreset = 'new';
  bool _unassignedOnly = false;
  late Future<List<SupportTicket>> _queue;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _queue = ref
        .read(supportRepositoryProvider)
        .listStaffQueue(status: _status, unassignedOnly: _unassignedOnly);
  }

  bool _matchesPreset(SupportTicket ticket) => switch (_queuePreset) {
    'new' => ticket.status == 'open',
    'waiting_support' => ticket.status == 'waiting_on_staff',
    'waiting_user' => ticket.status == 'waiting_on_user',
    'safety_urgent' => ticket.priority == 'urgent_safety',
    'verification' => ticket.category == 'verification',
    'dispute' => const {
      'payment_compensation',
      'adult_refused_completion',
      'teen_abandonment',
    }.contains(ticket.category),
    'evidence' => ticket.category == 'evidence_submission',
    'account_access' => ticket.category == 'account_sign_in',
    'technical' => const {
      'profile_avatar',
      'start_finish_pin',
      'other',
    }.contains(ticket.category),
    'ai_reported' => ticket.aiAssisted && ticket.priority != 'urgent_safety',
    'escalated' => ticket.aiAssisted && ticket.status == 'under_review',
    'resolved' => const {'resolved', 'closed'}.contains(ticket.status),
    _ => true,
  };

  void _applyFilter() => setState(_reload);

  @override
  Widget build(BuildContext context) => MortScreen(
    children: [
      const MortHeader(
        eyebrow: 'Authorized staff only',
        title: 'Support inbox',
        subtitle:
            'Private cases are ordered by priority and waiting time. Financial execution remains a separate permission.',
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final queue in const {
              'new': 'New',
              'waiting_support': 'Waiting for support',
              'waiting_user': 'Waiting for user',
              'safety_urgent': 'Safety urgent',
              'verification': 'Verification',
              'dispute': 'Dispute',
              'evidence': 'Evidence',
              'account_access': 'Account access',
              'technical': 'Technical',
              'ai_reported': 'AI-reported',
              'escalated': 'Escalated',
              'resolved': 'Resolved',
            }.entries)
              Padding(
                padding: const EdgeInsets.only(right: MortSpacing.xs),
                child: FilterChip(
                  label: Text(queue.value),
                  selected: _queuePreset == queue.key,
                  onSelected: (_) => setState(() => _queuePreset = queue.key),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: MortSpacing.sm),
      Row(
        children: [
          Expanded(
            child: MortDropdown<String>(
              label: 'Status filter',
              value: _status,
              items: const {
                'open': 'Open',
                'waiting_on_staff': 'Waiting on staff',
                'waiting_on_user': 'Waiting on user',
                'under_review': 'Under review',
                'resolved': 'Resolved',
                'closed': 'Closed',
              },
              onChanged: (value) {
                _status = value;
                _applyFilter();
              },
            ),
          ),
          const SizedBox(width: MortSpacing.sm),
          IconButton(
            tooltip: 'Clear status filter',
            onPressed: _status == null
                ? null
                : () {
                    _status = null;
                    _applyFilter();
                  },
            icon: const Icon(Icons.filter_alt_off_outlined),
          ),
        ],
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        value: _unassignedOnly,
        onChanged: (value) {
          _unassignedOnly = value;
          _applyFilter();
        },
        title: const Text('Unassigned cases only'),
      ),
      FutureBuilder<List<SupportTicket>>(
        future: _queue,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const MortLoading(
              label: 'Loading support inbox...',
              fullScreen: false,
            );
          }
          if (snapshot.hasError) {
            return MortErrorState(
              title: 'Support inbox unavailable',
              message: userFacingError(snapshot.error),
              action: MortButton(
                label: 'Retry',
                icon: Icons.refresh,
                onPressed: _applyFilter,
              ),
            );
          }
          final tickets = (snapshot.data ?? const [])
              .where(_matchesPreset)
              .toList(growable: false);
          if (tickets.isEmpty) {
            return const MortEmptyState(
              title: 'No matching cases',
              message: 'Change the queue filter or refresh later.',
            );
          }
          return Column(
            children: [
              for (final ticket in tickets) ...[
                MortCard(
                  onTap: () => context.go('/admin/support/ticket/${ticket.id}'),
                  child: Row(
                    children: [
                      const Icon(Icons.support_agent),
                      const SizedBox(width: MortSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ticket.subject,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${ticket.caseNumber} - ${supportCategories[ticket.category] ?? 'Other'}',
                            ),
                            Text(
                              'Priority: ${_label(ticket.priority)} - Waiting on: ${_label(ticket.waitingOnParty)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              ticket.assignedSupportUserId == null
                                  ? 'Unassigned - response goal ${formatDateTime(ticket.firstResponseDueAt)}'
                                  : 'Owned - response goal ${formatDateTime(ticket.firstResponseDueAt)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      MortBadge(label: _label(ticket.status)),
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

class AdminSupportTicketScreen extends ConsumerStatefulWidget {
  const AdminSupportTicketScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  ConsumerState<AdminSupportTicketScreen> createState() =>
      _AdminSupportTicketScreenState();
}

class _AdminSupportTicketScreenState
    extends ConsumerState<AdminSupportTicketScreen> {
  final _reply = TextEditingController();
  final _internalNote = TextEditingController();
  late Future<SupportThread> _thread;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _reply.dispose();
    _internalNote.dispose();
    super.dispose();
  }

  void _reload() {
    _thread = ref
        .read(supportRepositoryProvider)
        .getStaffThread(widget.ticketId);
  }

  Future<void> _postReply() async {
    final body = _reply.text.trim();
    if (_busy || body.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(supportRepositoryProvider)
          .postStaffReply(widget.ticketId, body);
      _reply.clear();
      if (mounted) {
        MortToast.show(context, 'Human-reviewed support reply posted.');
        setState(_reload);
      }
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _claim() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(supportRepositoryProvider)
          .claimStaffTicket(widget.ticketId);
      if (mounted) {
        MortToast.show(context, 'Support case assigned to you.');
        setState(_reload);
      }
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _release() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _SupportReasonDialog(
        title: 'Release this case',
        actionLabel: 'Release case',
        minimumLength: 8,
      ),
    );
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(supportRepositoryProvider)
          .releaseStaffTicket(widget.ticketId, reason);
      if (mounted) {
        MortToast.show(context, 'Support case returned to the queue.');
        setState(_reload);
      }
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addInternalNote() async {
    final body = _internalNote.text.trim();
    if (_busy || body.length < 3) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(supportRepositoryProvider)
          .addInternalNote(ticketId: widget.ticketId, body: body);
      _internalNote.clear();
      if (mounted) {
        MortToast.show(context, 'Private internal note added.');
        setState(_reload);
      }
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeStatus(String status) async {
    String? reason;
    if (status == 'resolved' || status == 'closed') {
      reason = await showDialog<String>(
        context: context,
        builder: (_) => _SupportStatusReasonDialog(status: status),
      );
      if (reason == null || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(supportRepositoryProvider)
          .changeStaffStatus(
            ticketId: widget.ticketId,
            status: status,
            resolutionCode: status == 'resolved'
                ? 'staff_review_complete'
                : null,
            reason: reason,
          );
      if (mounted) {
        MortToast.show(context, 'Support status updated with an audit event.');
        setState(_reload);
      }
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _previewEvidence(SupportEvidenceRecord evidence) async {
    setState(() => _busy = true);
    try {
      final url = await ref
          .read(supportRepositoryProvider)
          .signedEvidenceUrl(evidence.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          child: Padding(
            padding: const EdgeInsets.all(MortSpacing.sm),
            child: InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Padding(
                  padding: EdgeInsets.all(MortSpacing.lg),
                  child: Text('The expiring evidence preview could not load.'),
                ),
              ),
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<SupportThread>(
    future: _thread,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const MortLoading(label: 'Opening authorized support case...');
      }
      if (snapshot.hasError || snapshot.data == null) {
        return MortScreen(
          children: [
            MortErrorState(
              title: 'Support case unavailable',
              message: userFacingError(snapshot.error),
              action: MortButton(
                label: 'Back to inbox',
                icon: Icons.arrow_back,
                onPressed: () => context.go('/admin/support'),
              ),
            ),
          ],
        );
      }
      final thread = snapshot.data!;
      final currentUserId = ref.read(authRepositoryProvider).currentUser?.id;
      final ownedByCurrentUser =
          thread.ticket.assignedSupportUserId == currentUserId;
      return MortScreen(
        children: [
          MortHeader(
            eyebrow: thread.ticket.caseNumber,
            title: thread.ticket.subject,
            subtitle:
                '${supportCategories[thread.ticket.category] ?? 'Other'} - ${_label(thread.ticket.priority)} priority',
            trailing: MortBadge(label: _label(thread.ticket.status)),
          ),
          const MortSafetyBanner(
            message:
                'Reply only within assigned support scope. This screen cannot authorize a transfer, refund, identity finding, legal conclusion, or punitive action.',
          ),
          const SizedBox(height: MortSpacing.sm),
          MortCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  thread.ticket.assignedSupportUserId == null
                      ? 'Queue ownership: unassigned'
                      : ownedByCurrentUser
                      ? 'Queue ownership: assigned to you'
                      : 'Queue ownership: assigned to authorized staff',
                ),
                Text(
                  'Response goal: ${formatDateTime(thread.ticket.firstResponseDueAt)}. This is not a user-facing guarantee unless staffing policy is activated.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: MortSpacing.xs),
                Wrap(
                  spacing: MortSpacing.sm,
                  runSpacing: MortSpacing.sm,
                  children: [
                    if (thread.ticket.assignedSupportUserId == null)
                      MortButton(
                        label: 'Claim case',
                        icon: Icons.assignment_ind_outlined,
                        busy: _busy,
                        onPressed: _claim,
                      ),
                    if (ownedByCurrentUser)
                      MortButton(
                        label: 'Release case',
                        icon: Icons.assignment_return_outlined,
                        busy: _busy,
                        style: MortButtonStyle.secondary,
                        onPressed: _release,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: MortSpacing.md),
          for (final message in thread.messages) ...[
            _SupportBubble(message: message),
            const SizedBox(height: MortSpacing.sm),
          ],
          MortTextArea(
            label: 'Human support reply',
            controller: _reply,
            maxLines: 5,
            maxLength: 2000,
          ),
          const SizedBox(height: MortSpacing.sm),
          MortButton(
            label: 'Post human-reviewed reply',
            icon: Icons.send_outlined,
            busy: _busy,
            onPressed: _postReply,
          ),
          const SizedBox(height: MortSpacing.md),
          const MortSectionTitle(title: 'Private staff notes'),
          const Text(
            'Internal notes are never shown to the requester. Record factual handoff context only; do not paste credentials, exact addresses, or unnecessary evidence.',
          ),
          const SizedBox(height: MortSpacing.sm),
          for (final note in thread.internalNotes) ...[
            MortCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_label(note.noteKind)} - ${formatDateTime(note.createdAt)}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(note.body),
                ],
              ),
            ),
            const SizedBox(height: MortSpacing.xs),
          ],
          MortTextArea(
            label: 'Internal note',
            controller: _internalNote,
            maxLines: 4,
            maxLength: 2000,
          ),
          const SizedBox(height: MortSpacing.sm),
          MortButton(
            label: 'Add private note',
            icon: Icons.note_add_outlined,
            busy: _busy,
            onPressed: ownedByCurrentUser ? _addInternalNote : null,
          ),
          const SizedBox(height: MortSpacing.md),
          const MortSectionTitle(title: 'Controlled status'),
          MortActionRow(
            actions: [
              for (final status in const [
                'waiting_on_user',
                'waiting_on_staff',
                'under_review',
                'resolved',
                'closed',
              ])
                MortAction(
                  label: _label(status),
                  icon: status == 'closed'
                      ? Icons.lock_outline
                      : Icons.rule_outlined,
                  busy: _busy,
                  onPressed: () => _changeStatus(status),
                ),
            ],
          ),
          if (thread.evidence.isNotEmpty) ...[
            const SizedBox(height: MortSpacing.md),
            const MortSectionTitle(title: 'Private evidence manifest'),
            for (final evidence in thread.evidence) ...[
              MortCard(
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline),
                    const SizedBox(width: MortSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_label(evidence.category)),
                          Text(
                            '${_label(evidence.status)} - ${_label(evidence.reviewStatus)} - ${evidence.processedByteSize} bytes',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (evidence.preservationHold)
                            const Text('Preservation hold active'),
                        ],
                      ),
                    ),
                    MortIconButton(
                      icon: Icons.visibility_outlined,
                      tooltip: 'Open five-minute authorized preview',
                      onPressed: _busy
                          ? null
                          : () => _previewEvidence(evidence),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: MortSpacing.sm),
            ],
          ],
          if (thread.auditHistory.isNotEmpty) ...[
            const SizedBox(height: MortSpacing.md),
            const MortSectionTitle(title: 'Case audit history'),
            for (final event in thread.auditHistory.reversed.take(30))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history_outlined),
                title: Text(_label(event.eventType)),
                subtitle: Text(
                  '${formatDateTime(event.createdAt)}${event.toStatus == null ? '' : ' - ${_label(event.toStatus!)}'}',
                ),
              ),
          ],
        ],
      );
    },
  );
}

class _SupportStatusReasonDialog extends StatefulWidget {
  const _SupportStatusReasonDialog({required this.status});

  final String status;

  @override
  State<_SupportStatusReasonDialog> createState() =>
      _SupportStatusReasonDialogState();
}

class _SupportStatusReasonDialogState
    extends State<_SupportStatusReasonDialog> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('${_label(widget.status)} case'),
    content: TextField(
      controller: controller,
      minLines: 3,
      maxLines: 6,
      maxLength: 500,
      decoration: const InputDecoration(labelText: 'Factual reason'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          final reason = controller.text.trim();
          if (reason.length >= 3) Navigator.pop(context, reason);
        },
        child: Text(_label(widget.status)),
      ),
    ],
  );
}

class _SupportReasonDialog extends StatefulWidget {
  const _SupportReasonDialog({
    required this.title,
    required this.actionLabel,
    required this.minimumLength,
    this.maxLength = 500,
  });

  final String title;
  final String actionLabel;
  final int minimumLength;
  final int maxLength;

  @override
  State<_SupportReasonDialog> createState() => _SupportReasonDialogState();
}

class _SupportReasonDialogState extends State<_SupportReasonDialog> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: controller,
      minLines: 3,
      maxLines: 8,
      maxLength: widget.maxLength,
      decoration: const InputDecoration(labelText: 'Factual reason'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          final reason = controller.text.trim();
          if (reason.length >= widget.minimumLength) {
            Navigator.pop(context, reason);
          }
        },
        child: Text(widget.actionLabel),
      ),
    ],
  );
}

Future<void> _openSupportEmail(
  BuildContext context, {
  String? caseNumber,
  String? email,
  String? jobId,
  String? applicationId,
  String? contractId,
}) async {
  final subject = caseNumber == null
      ? 'MORT Support Request'
      : 'MORT Support Case $caseNumber';
  final body = [
    if (caseNumber != null) 'Case number: $caseNumber',
    if (email != null) 'Signed-in account email: $email',
    if (jobId != null) 'Job ID: $jobId',
    if (applicationId != null) 'Application ID: $applicationId',
    if (contractId != null) 'Contract ID: $contractId',
    '',
    'Describe the support request:',
    '',
    SupportRepository.savedPaymentWarning,
    '',
    'Email is a manual fallback. Sending this message does not prove MORT received or linked it to an in-app case.',
  ].join('\n');
  final uri = Uri(
    scheme: 'mailto',
    path: 'mortapp.help@gmail.com',
    queryParameters: {'subject': subject, 'body': body},
  );
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    MortToast.show(context, 'No email app is available on this device.');
  }
}

String _label(String value) => value
    .split('_')
    .map(
      (part) => part.isEmpty
          ? ''
          : '${part.substring(0, 1).toUpperCase()}${part.substring(1)}',
    )
    .join(' ');
