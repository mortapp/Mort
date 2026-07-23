import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/models/profile.dart';
import '../../data/models/trust_safety.dart';
import '../../data/repositories/providers.dart';
import '../../services/identity_verification_provider.dart';

class IdentityVerificationScreen extends ConsumerStatefulWidget {
  const IdentityVerificationScreen({super.key});

  @override
  ConsumerState<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState
    extends ConsumerState<IdentityVerificationScreen> {
  IdentityVerificationStatus? _status;
  String? _error;
  final _appealController = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _appealController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_status == null && _error == null) {
      return const MortLoading(label: 'Loading verification status');
    }
    return MortScreen(
      children: [
        MortHeader(
          eyebrow: 'PRIVATE TRUST CHECK',
          title: 'Identity verification',
          subtitle:
              'Public marketplace participation stays closed until secure production verification is available. Guardian Mode remains optional.',
          trailing: MortIconButton(
            icon: Icons.refresh,
            tooltip: 'Refresh status',
            onPressed: _busy ? null : _load,
          ),
        ),
        if (_error != null)
          _SafetyNotice(
            title: 'Verification unavailable',
            message: _error!,
            color: MortColors.danger,
          ),
        if (_status != null) ...[
          _statusCard(_status!),
          const SizedBox(height: MortSpacing.lg),
          _verificationModeState(_status!),
          if (_status!.verificationMode == 'production' &&
              {
                'verification_rejected',
                'verification_expired',
                'verification_suspended',
              }.contains(_status!.status) &&
              _status!.id != null)
            _appealForm(),
        ],
        const SizedBox(height: MortSpacing.lg),
        const _SafetyNotice(
          title: 'Verification is not a safety guarantee',
          message:
              'MORT is not collecting identity documents in disabled or sandbox mode. Reporting, blocking, Safety Ping, support, and emergency guidance stay available.',
          color: MortColors.safetyBlue,
        ),
      ],
    );
  }

  Widget _statusCard(IdentityVerificationStatus status) {
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Marketplace identity',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              MortBadge(
                label: status.productionVerified
                    ? 'production verified'
                    : status.environment == 'sandbox'
                    ? 'TEST MODE'
                    : status.status.replaceAll('_', ' '),
                color: status.productionVerified
                    ? MortColors.neon
                    : MortColors.warning,
              ),
            ],
          ),
          const SizedBox(height: MortSpacing.sm),
          Text(
            status.marketplaceEnabled
                ? 'Marketplace actions enabled'
                : 'Marketplace actions locked',
          ),
          Text(
            'Mode ${status.verificationMode} | Guardian Mode optional: ${status.guardianModeOptional ? 'Yes' : 'No'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (status.environment != null)
            Text(
              'Environment: ${status.environment}${status.environment == 'sandbox' ? ' (never production eligible)' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (status.expiresAt != null)
            Text(
              'Recheck by ${status.expiresAt}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  Widget _verificationModeState(IdentityVerificationStatus status) {
    if (status.verificationMode == 'disabled') {
      return const _SafetyNotice(
        title: 'Identity verification is not accepting public submissions yet.',
        message:
            'MORT is still preparing its secure verification system. Do not upload an ID or personal document.',
        color: MortColors.warning,
      );
    }
    if (status.verificationMode == 'sandbox') {
      if (!status.sandboxEligible) {
        return const _SafetyNotice(
          title: 'Sandbox restricted',
          message:
              'Test verification is available only to explicitly isolated QA accounts.',
          color: MortColors.warning,
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SafetyNotice(
            title: 'TEST MODE',
            message:
                'Test verification - do not use real documents. Sandbox results never grant production eligibility.',
            color: MortColors.warning,
          ),
          if (status.id == null || status.status == 'unverified') ...[
            const SizedBox(height: MortSpacing.md),
            MortButton(
              label: 'Start simulated verification',
              icon: Icons.science,
              busy: _busy,
              onPressed: _busy ? null : _startSandboxSession,
            ),
          ],
        ],
      );
    }
    if (!status.productionProviderAvailable) {
      return const _SafetyNotice(
        title: 'Production provider unavailable',
        message:
            'Production verification fails closed until an approved provider, signed webhook, legal approval, retention policy, and trained operations are ready.',
        color: MortColors.warning,
      );
    }
    return const _SafetyNotice(
      title: 'Provider session required',
      message:
          'Verification is available only through an approved provider session confirmed by MORT.',
      color: MortColors.safetyBlue,
    );
  }

  Widget _appealForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MortSectionTitle(
          title: 'Request another review',
          subtitle:
              'An appeal does not automatically restore marketplace access.',
        ),
        MortTextField(label: 'Appeal reason', controller: _appealController),
        const SizedBox(height: MortSpacing.sm),
        MortButton(
          label: 'Submit appeal',
          icon: Icons.replay,
          busy: _busy,
          onPressed: _appealController.text.trim().length < 20 ? null : _appeal,
        ),
      ],
    );
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _status = null;
    });
    try {
      final status = await ref
          .read(trustSafetyRepositoryProvider)
          .getIdentityStatus();
      if (!mounted) return;
      setState(() {
        _status = status;
      });
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    }
  }

  Future<void> _work(Future<void> Function() operation, String success) async {
    setState(() => _busy = true);
    try {
      await operation();
      if (!mounted) return;
      MortToast.show(context, success);
      await _load();
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startSandboxSession() async {
    final status = _status;
    if (status == null) return;
    final repository = ref.read(trustSafetyRepositoryProvider);
    final provider = providerForStatus(
      status,
      createSandboxSession: repository.createSandboxVerificationSession,
    );
    await _work(() async {
      final session = await provider.createSession();
      if (session.documentsAllowed) {
        throw StateError('Sandbox sessions must never allow documents.');
      }
    }, 'Sandbox session created. No documents were collected.');
  }

  Future<void> _appeal() async {
    final id = _status?.id;
    if (id == null) return;
    await _work(
      () => ref
          .read(trustSafetyRepositoryProvider)
          .appealIdentityVerification(
            verificationId: id,
            reason: _appealController.text,
          ),
      'Appeal submitted without automatically restoring access.',
    );
  }
}

class SafetyCasesScreen extends ConsumerStatefulWidget {
  const SafetyCasesScreen({super.key});

  @override
  ConsumerState<SafetyCasesScreen> createState() => _SafetyCasesScreenState();
}

class _SafetyCasesScreenState extends ConsumerState<SafetyCasesScreen> {
  List<SafetyIncidentSummary>? _cases;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'RESTRICTED STATUS',
          title: 'Safety cases',
          subtitle:
              'Only case status and approved public notes are shown here. Restricted evidence and internal notes stay isolated.',
        ),
        if (_cases == null && _error == null)
          const MortLoading(fullScreen: false),
        if (_error != null)
          _SafetyNotice(
            title: 'Cases unavailable',
            message: _error!,
            color: MortColors.danger,
          ),
        if (_cases != null && _cases!.isEmpty)
          const MortEmptyState(
            title: 'No safety cases',
            message:
                'Reports and preserved incidents you are allowed to see will appear here.',
          ),
        for (final incident in _cases ?? const <SafetyIncidentSummary>[]) ...[
          MortCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(incident.caseNumber)),
                    MortBadge(
                      label: incident.status.replaceAll('_', ' '),
                      color: MortColors.warning,
                    ),
                  ],
                ),
                const SizedBox(height: MortSpacing.sm),
                Text(
                  incident.category.replaceAll('_', ' '),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text('Severity: ${incident.severity}'),
                Text(
                  incident.publicStatusNote ??
                      'Your case is in the restricted safety workflow.',
                ),
                const SizedBox(height: MortSpacing.sm),
                MortButton(
                  label: 'Request appeal review',
                  icon: Icons.replay,
                  style: MortButtonStyle.secondary,
                  onPressed:
                      {'pending', 'reviewing'}.contains(incident.appealStatus)
                      ? null
                      : () => _appeal(incident),
                ),
              ],
            ),
          ),
          const SizedBox(height: MortSpacing.sm),
        ],
      ],
    );
  }

  Future<void> _load() async {
    try {
      final values = await ref
          .read(trustSafetyRepositoryProvider)
          .listMyIncidentCases();
      if (mounted) setState(() => _cases = values);
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    }
  }

  Future<void> _appeal(SafetyIncidentSummary incident) async {
    final controller = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Appeal ${incident.caseNumber}'),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Specific reason for another review',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (submit != true) return;
    try {
      await ref
          .read(trustSafetyRepositoryProvider)
          .submitIncidentAppeal(
            incidentId: incident.id,
            reason: controller.text,
          );
      if (mounted) MortToast.show(context, 'Appeal submitted.');
      await _load();
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      controller.dispose();
    }
  }
}

class SafetyCircleScreen extends ConsumerStatefulWidget {
  const SafetyCircleScreen({super.key});

  @override
  ConsumerState<SafetyCircleScreen> createState() => _SafetyCircleScreenState();
}

class _SafetyCircleScreenState extends ConsumerState<SafetyCircleScreen> {
  final _labelController = TextEditingController(text: 'Trusted contact');
  final _codeController = TextEditingController();
  List<SafetyCircleContact>? _contacts;
  bool _ping = true;
  bool _missedCheckin = true;
  bool _jobSummary = false;
  bool _jobStatus = false;
  bool _safetyPlan = false;
  bool _busy = false;

  UserRole? get _role => ref.read(currentProfileProvider).asData?.value?.role;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _labelController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'OPTIONAL AND CONSENTED',
          title: 'Safety Circle',
          subtitle:
              'Trusted contacts receive only permissions granted by the teen. They do not receive account control, raw ID evidence, or unrestricted messages.',
        ),
        if (_role == UserRole.teen) _teenInvite() else _acceptInvite(),
        const MortSectionTitle(title: 'Linked contacts'),
        if (_contacts == null) const MortLoading(fullScreen: false),
        if (_contacts?.isEmpty == true)
          const MortEmptyState(
            title: 'No contacts linked',
            message: 'Safety Circle is optional and can be set up later.',
          ),
        for (final contact in _contacts ?? const <SafetyCircleContact>[]) ...[
          MortCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        contact.relationshipLabel,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    MortBadge(label: contact.status),
                  ],
                ),
                const SizedBox(height: MortSpacing.sm),
                Text(
                  contact.permissions.entries
                      .where((entry) => entry.value)
                      .map((entry) => entry.key.replaceAll('_', ' '))
                      .join(' | '),
                ),
                const SizedBox(height: MortSpacing.sm),
                MortButton(
                  label: 'Unlink',
                  icon: Icons.link_off,
                  style: MortButtonStyle.danger,
                  busy: _busy,
                  onPressed: () => _unlink(contact.id),
                ),
              ],
            ),
          ),
          const SizedBox(height: MortSpacing.sm),
        ],
        const SizedBox(height: MortSpacing.md),
        const _SafetyNotice(
          title: 'Teen privacy remains in force',
          message:
              'Either person can unlink. Safety Circle does not introduce a global guardian requirement and never replaces emergency services.',
          color: MortColors.safetyBlue,
        ),
      ],
    );
  }

  Widget _teenInvite() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MortTextField(
          label: 'Relationship label',
          controller: _labelController,
        ),
        SwitchListTile(
          value: _ping,
          title: const Text('Safety Pings'),
          onChanged: (value) => setState(() => _ping = value),
        ),
        SwitchListTile(
          value: _missedCheckin,
          title: const Text('Missed check-ins'),
          onChanged: (value) => setState(() => _missedCheckin = value),
        ),
        SwitchListTile(
          value: _jobSummary,
          title: const Text('Limited job summary'),
          onChanged: (value) => setState(() => _jobSummary = value),
        ),
        SwitchListTile(
          value: _jobStatus,
          title: const Text('Job status changes'),
          onChanged: (value) => setState(() => _jobStatus = value),
        ),
        SwitchListTile(
          value: _safetyPlan,
          title: const Text('Limited Safety Plan'),
          onChanged: (value) => setState(() => _safetyPlan = value),
        ),
        MortButton(
          label: 'Create one-time invite',
          icon: Icons.person_add,
          busy: _busy,
          onPressed: _createInvite,
        ),
        if (_codeController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: MortSpacing.sm),
            child: SelectableText(
              'One-time code: ${_codeController.text}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
      ],
    );
  }

  Widget _acceptInvite() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MortTextField(
          label: 'One-time invitation code',
          controller: _codeController,
        ),
        const SizedBox(height: MortSpacing.sm),
        MortButton(
          label: 'Accept invitation',
          icon: Icons.group_add,
          busy: _busy,
          onPressed: _acceptInviteAction,
        ),
      ],
    );
  }

  Map<String, bool> get _permissions => {
    'receive_safety_ping': _ping,
    'receive_missed_checkin': _missedCheckin,
    'receive_job_summary': _jobSummary,
    'receive_job_status': _jobStatus,
    'receive_emergency_request': true,
    'view_limited_safety_plan': _safetyPlan,
    'receive_completion': _jobStatus,
  };

  Future<void> _load() async {
    try {
      final values = await ref
          .read(trustSafetyRepositoryProvider)
          .listSafetyCircle();
      if (mounted) setState(() => _contacts = values);
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    }
  }

  Future<void> _createInvite() async {
    setState(() => _busy = true);
    try {
      final code = await ref
          .read(trustSafetyRepositoryProvider)
          .createSafetyCircleInvite(
            relationship: _labelController.text,
            permissions: _permissions,
          );
      if (mounted) setState(() => _codeController.text = code);
      await _load();
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _acceptInviteAction() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(trustSafetyRepositoryProvider)
          .acceptSafetyCircleInvite(_codeController.text);
      _codeController.clear();
      await _load();
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unlink(String id) async {
    setState(() => _busy = true);
    try {
      await ref.read(trustSafetyRepositoryProvider).unlinkSafetyCircle(id);
      await _load();
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class JobSafetyWorkspaceScreen extends ConsumerStatefulWidget {
  const JobSafetyWorkspaceScreen({super.key, required this.applicationId});

  final String applicationId;

  @override
  ConsumerState<JobSafetyWorkspaceScreen> createState() =>
      _JobSafetyWorkspaceScreenState();
}

class _JobSafetyWorkspaceScreenState
    extends ConsumerState<JobSafetyWorkspaceScreen> {
  final _peopleController = TextEditingController();
  final _transportController = TextEditingController();
  final _addressController = TextEditingController();
  final _arrivalInstructionsController = TextEditingController();
  final _codeController = TextEditingController();
  final _coarseController = TextEditingController();
  final _cancelDetailsController = TextEditingController();
  JobSafetyAgreement? _agreement;
  List<AuthorizedLocationShare> _shares = const [];
  bool _publicMeeting = true;
  bool _daylight = true;
  bool _personMatches = true;
  bool _busy = false;
  String? _releasedAddress;
  String _cancelReason = 'unsafe_condition';

  UserRole? get _role => ref.read(currentProfileProvider).asData?.value?.role;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    for (final controller in [
      _peopleController,
      _transportController,
      _addressController,
      _arrivalInstructionsController,
      _codeController,
      _coarseController,
      _cancelDetailsController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'TWO-SIDED JOB SAFETY',
          title: 'Mutual Safety Agreement',
          subtitle:
              'Both participants confirm the same current terms. Material changes clear prior confirmations.',
        ),
        if (_agreement == null)
          const _SafetyNotice(
            title: 'Agreement not available yet',
            message:
                'The restricted agreement is created after the poster accepts an application.',
            color: MortColors.warning,
          )
        else ...[
          _agreementCard(_agreement!),
          _safeFirstMeeting(),
          _exactLocation(),
          _temporaryLocation(),
          _arrivalHandshake(),
          _safetyCancellation(),
        ],
        const SizedBox(height: MortSpacing.md),
        const _SafetyNotice(
          title: 'Right to leave',
          message:
              'Verification and arrival confirmation do not guarantee safety. Leave when the person, location, scope, or conditions differ. Contact emergency services for immediate danger.',
          color: MortColors.safetyBlue,
        ),
      ],
    );
  }

  Widget _agreementCard(JobSafetyAgreement agreement) {
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Version ${agreement.version}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              MortBadge(
                label: agreement.status.replaceAll('_', ' '),
                color: agreement.status == 'confirmed'
                    ? MortColors.neon
                    : MortColors.warning,
              ),
            ],
          ),
          const SizedBox(height: MortSpacing.sm),
          for (final key in [
            'job_title',
            'scope',
            'who_will_be_present',
            'physical_requirements',
          ])
            if (agreement.terms[key] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: MortSpacing.xs),
                child: Text(
                  '${key.replaceAll('_', ' ')}: ${agreement.terms[key]}',
                ),
              ),
          MortButton(
            label: 'Confirm this exact version',
            icon: Icons.verified_user,
            busy: _busy,
            onPressed: _confirmAgreement,
          ),
        ],
      ),
    );
  }

  Widget _safeFirstMeeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MortSectionTitle(
          title: 'Safe First Meeting',
          subtitle:
              'Record people present, visibility, daylight, transportation, and check-ins before work starts.',
        ),
        MortTextField(
          label: 'Who will be present',
          controller: _peopleController,
        ),
        const SizedBox(height: MortSpacing.sm),
        MortTextField(
          label: 'Transportation and exit plan',
          controller: _transportController,
        ),
        SwitchListTile(
          value: _publicMeeting,
          title: const Text('Public or clearly visible meeting'),
          onChanged: (value) => setState(() => _publicMeeting = value),
        ),
        SwitchListTile(
          value: _daylight,
          title: const Text('Daylight preferred'),
          onChanged: (value) => setState(() => _daylight = value),
        ),
        MortButton(
          label: 'Save plan and require reconfirmation',
          icon: Icons.fact_check,
          busy: _busy,
          onPressed: _savePlan,
        ),
      ],
    );
  }

  Widget _exactLocation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MortSectionTitle(
          title: 'Staged exact location',
          subtitle:
              'Only a general area is public. Exact location is released after acceptance and both confirmations.',
        ),
        if (_role == UserRole.adult) ...[
          MortTextField(
            label: 'Exact job address (private)',
            controller: _addressController,
          ),
          const SizedBox(height: MortSpacing.sm),
          MortTextField(
            label: 'Safe arrival instructions',
            controller: _arrivalInstructionsController,
          ),
          const SizedBox(height: MortSpacing.sm),
          MortButton(
            label: 'Save restricted location',
            icon: Icons.lock_outline,
            busy: _busy,
            onPressed: _addressController.text.trim().length < 5
                ? null
                : _saveLocation,
          ),
        ],
        const SizedBox(height: MortSpacing.sm),
        MortButton(
          label: 'Request location for current stage',
          icon: Icons.pin_drop,
          style: MortButtonStyle.secondary,
          busy: _busy,
          onPressed: _getLocation,
        ),
        if (_releasedAddress != null)
          Padding(
            padding: const EdgeInsets.only(top: MortSpacing.sm),
            child: SelectableText('Restricted address: $_releasedAddress'),
          ),
      ],
    );
  }

  Widget _temporaryLocation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MortSectionTitle(
          title: 'Temporary location sharing',
          subtitle:
              'Optional, explicit, visible, job-bound, and expires after two hours. Web preview shares a coarse area only.',
        ),
        MortTextField(label: 'Coarse area', controller: _coarseController),
        const SizedBox(height: MortSpacing.sm),
        MortButton(
          label: 'Share coarse area temporarily',
          icon: Icons.location_searching,
          busy: _busy,
          onPressed: _coarseController.text.trim().length < 3
              ? null
              : _startShare,
        ),
        for (final share in _shares) ...[
          const SizedBox(height: MortSpacing.sm),
          MortCard(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${share.mode.replaceAll('_', ' ')}: ${share.coarseLocation ?? 'active'}',
                  ),
                ),
                if (share.ownerId ==
                    ref.read(currentProfileProvider).asData?.value?.id)
                  TextButton(
                    onPressed: () => _stopShare(share.id),
                    child: const Text('Stop'),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _arrivalHandshake() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MortSectionTitle(
          title: 'Arrival handshake',
          subtitle:
              'The poster generates a short-lived code. The assigned teen confirms the code and person match. Codes are single-use.',
        ),
        if (_role == UserRole.adult)
          MortButton(
            label: 'Generate 10-minute arrival code',
            icon: Icons.qr_code,
            busy: _busy,
            onPressed: _agreement?.status == 'confirmed' ? _generateCode : null,
          )
        else ...[
          MortTextField(label: 'Arrival code', controller: _codeController),
          CheckboxListTile(
            value: _personMatches,
            title: const Text('The person matches the verified profile'),
            onChanged: (value) =>
                setState(() => _personMatches = value ?? false),
          ),
          MortButton(
            label: _personMatches
                ? 'Confirm arrival'
                : 'Report person mismatch',
            icon: _personMatches ? Icons.how_to_reg : Icons.report,
            style: _personMatches
                ? MortButtonStyle.primary
                : MortButtonStyle.danger,
            busy: _busy,
            onPressed: _codeController.text.trim().length < 6
                ? null
                : _confirmArrival,
          ),
        ],
        if (_role == UserRole.adult && _codeController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: MortSpacing.sm),
            child: SelectableText(
              'Single-use code: ${_codeController.text}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
      ],
    );
  }

  Widget _safetyCancellation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MortSectionTitle(
          title: 'Leave without retaliation',
          subtitle:
              'Safety cancellations do not automatically reduce reputation. Serious reasons open the restricted incident workflow.',
        ),
        DropdownButtonFormField<String>(
          initialValue: _cancelReason,
          decoration: const InputDecoration(labelText: 'Reason'),
          items:
              const {
                    'unsafe_condition': 'Unsafe condition',
                    'person_mismatch': 'Person mismatch',
                    'harassment': 'Harassment',
                    'location_changed': 'Location changed',
                    'scope_changed': 'Scope changed',
                    'emergency': 'Emergency',
                  }.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(),
          onChanged: (value) =>
              setState(() => _cancelReason = value ?? 'unsafe_condition'),
        ),
        const SizedBox(height: MortSpacing.sm),
        MortTextField(
          label: 'What changed?',
          controller: _cancelDetailsController,
        ),
        const SizedBox(height: MortSpacing.sm),
        MortButton(
          label: 'Cancel for this reason',
          icon: Icons.exit_to_app,
          style: MortButtonStyle.danger,
          busy: _busy,
          onPressed: _cancel,
        ),
      ],
    );
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(trustSafetyRepositoryProvider);
      final agreement = await repo.getSafetyAgreement(widget.applicationId);
      final shares = (await repo.listLocationShares())
          .where((share) => share.applicationId == widget.applicationId)
          .toList();
      if (mounted) {
        setState(() {
          _agreement = agreement;
          _shares = shares;
        });
      }
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    }
  }

  Future<void> _work(Future<void> Function() operation, String success) async {
    setState(() => _busy = true);
    try {
      await operation();
      if (mounted) MortToast.show(context, success);
      await _load();
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmAgreement() async {
    final agreement = _agreement!;
    await _work(
      () => ref
          .read(trustSafetyRepositoryProvider)
          .confirmSafetyAgreement(
            applicationId: agreement.applicationId,
            version: agreement.version,
          ),
      'Your independent confirmation was recorded.',
    );
  }

  Future<void> _savePlan() async {
    await _work(
      () => ref
          .read(trustSafetyRepositoryProvider)
          .saveSafetyPlan(
            applicationId: widget.applicationId,
            expectedPeople: _peopleController.text,
            publicMeeting: _publicMeeting,
            daylight: _daylight,
            transportationPlan: _transportController.text,
            checkinMinutes: 30,
          ),
      'Safety Plan saved. Both people must reconfirm.',
    );
  }

  Future<void> _saveLocation() async {
    await _work(
      () => ref
          .read(trustSafetyRepositoryProvider)
          .savePrivateJobLocation(
            jobId: _agreement!.jobId,
            exactAddress: _addressController.text,
            arrivalInstructions: _arrivalInstructionsController.text,
          ),
      'Restricted job location saved. Prior confirmations were cleared.',
    );
  }

  Future<void> _getLocation() async {
    setState(() => _busy = true);
    try {
      final value = await ref
          .read(trustSafetyRepositoryProvider)
          .getReleasedJobLocation(widget.applicationId);
      if (mounted) {
        setState(() => _releasedAddress = value['exact_address'] as String?);
      }
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startShare() async {
    await _work(() async {
      await ref
          .read(trustSafetyRepositoryProvider)
          .startCoarseLocationShare(
            agreement: _agreement!,
            coarseLocation: _coarseController.text,
          );
    }, 'Temporary coarse-area sharing started.');
  }

  Future<void> _stopShare(String id) async {
    await _work(
      () => ref.read(trustSafetyRepositoryProvider).stopLocationShare(id),
      'Temporary location sharing stopped.',
    );
  }

  Future<void> _generateCode() async {
    setState(() => _busy = true);
    try {
      final value = await ref
          .read(trustSafetyRepositoryProvider)
          .generateArrivalCode(widget.applicationId);
      if (mounted) {
        setState(() => _codeController.text = value['arrival_code'] as String);
      }
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmArrival() async {
    await _work(() async {
      await ref
          .read(trustSafetyRepositoryProvider)
          .confirmArrival(
            applicationId: widget.applicationId,
            code: _codeController.text,
            personMatches: _personMatches,
          );
    }, _personMatches ? 'Arrival confirmed.' : 'Person mismatch case created.');
  }

  Future<void> _cancel() async {
    await _work(
      () => ref
          .read(trustSafetyRepositoryProvider)
          .submitSafetyCancellation(
            applicationId: widget.applicationId,
            reason: _cancelReason,
            details: _cancelDetailsController.text,
          ),
      'Cancellation recorded with no automatic reputation penalty.',
    );
  }
}

class AccountSessionsScreen extends ConsumerStatefulWidget {
  const AccountSessionsScreen({super.key});

  @override
  ConsumerState<AccountSessionsScreen> createState() =>
      _AccountSessionsScreenState();
}

class _AccountSessionsScreenState extends ConsumerState<AccountSessionsScreen> {
  List<AccountSessionSummary>? _sessions;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'ACCOUNT SECURITY',
          title: 'Active sessions',
          subtitle:
              'Review privacy-safe session references and report devices you do not recognize.',
        ),
        if (_sessions == null) const MortLoading(fullScreen: false),
        for (final session in _sessions ?? const <AccountSessionSummary>[]) ...[
          MortCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(session.userAgent)),
                    if (session.isCurrent)
                      const MortBadge(label: 'Current', color: MortColors.neon),
                  ],
                ),
                Text('Session ${session.reference}'),
                Text('Assurance: ${session.assuranceLevel}'),
                const SizedBox(height: MortSpacing.sm),
                MortButton(
                  label: 'Report unfamiliar session',
                  icon: Icons.phonelink_erase,
                  style: MortButtonStyle.secondary,
                  onPressed: () => _report(session),
                ),
              ],
            ),
          ),
          const SizedBox(height: MortSpacing.sm),
        ],
      ],
    );
  }

  Future<void> _load() async {
    try {
      final values = await ref
          .read(trustSafetyRepositoryProvider)
          .listAccountSessions();
      if (mounted) setState(() => _sessions = values);
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    }
  }

  Future<void> _report(AccountSessionSummary session) async {
    try {
      await ref
          .read(trustSafetyRepositoryProvider)
          .reportAccountSession(session);
      if (mounted) {
        MortToast.show(
          context,
          'Security concern recorded. Reset your password if this is not yours.',
        );
      }
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    }
  }
}

class _SafetyNotice extends StatelessWidget {
  const _SafetyNotice({
    required this.title,
    required this.message,
    required this.color,
  });

  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return MortCard(
      color: color.withValues(alpha: 0.08),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: color),
          const SizedBox(width: MortSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: MortSpacing.xs),
                Text(message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
