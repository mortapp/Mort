import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/models/account_trust.dart';
import '../../data/repositories/providers.dart';
import '../../data/services/supabase_service.dart';

class TeenVerificationOptionsScreen extends ConsumerStatefulWidget {
  const TeenVerificationOptionsScreen({super.key});

  @override
  ConsumerState<TeenVerificationOptionsScreen> createState() =>
      _TeenVerificationOptionsScreenState();
}

class _TeenVerificationOptionsScreenState
    extends ConsumerState<TeenVerificationOptionsScreen> {
  final _schoolEmail = TextEditingController();
  final _picker = ImagePicker();
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _schoolEmail.text = SupabaseService.client.auth.currentUser?.email ?? '';
  }

  @override
  void dispose() {
    _schoolEmail.dispose();
    super.dispose();
  }

  Future<TeenVerificationStatus> _ensureSession() async {
    var status = await ref.read(teenVerificationStatusProvider.future);
    if (status.hasSession) return status;
    await ref.read(accountTrustRepositoryProvider).startTeenVerification();
    ref.invalidate(teenVerificationStatusProvider);
    status = await ref.read(teenVerificationStatusProvider.future);
    return status;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _message = userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start() => _run(() async {
    await ref.read(accountTrustRepositoryProvider).startTeenVerification();
    ref.invalidate(teenVerificationStatusProvider);
    if (mounted) setState(() => _message = 'MORT Verify session started.');
  });

  Future<void> _verifySchoolEmail() => _run(() async {
    final status = await _ensureSession();
    final result = await ref
        .read(accountTrustRepositoryProvider)
        .requestSchoolAffiliation(_schoolEmail.text);
    await ref
        .read(accountTrustRepositoryProvider)
        .syncTeenSchoolAffiliation(status.sessionId!);
    ref.invalidate(teenVerificationStatusProvider);
    if (mounted) {
      setState(() {
        _message = result['affiliation_verified'] == true
            ? 'School email verified.'
            : (result['message'] as String? ??
                  'That school domain is waiting for restricted review.');
      });
    }
  });

  Future<void> _pickSchoolId(ImageSource source) => _run(() async {
    final status = await _ensureSession();
    if (!status.submissionsEnabled) {
      throw StateError(
        'School-ID collection is not enabled for this account or release.',
      );
    }
    final photo = await _picker.pickImage(
      source: source,
      imageQuality: 100,
      maxWidth: 4096,
      maxHeight: 4096,
    );
    if (photo == null) return;
    await ref
        .read(accountTrustRepositoryProvider)
        .uploadTeenSchoolId(
          sessionId: status.sessionId!,
          sourceBytes: await photo.readAsBytes(),
        );
    ref.invalidate(teenVerificationStatusProvider);
    if (mounted) {
      setState(
        () => _message =
            'School ID uploaded privately. It is not visible on your profile.',
      );
    }
  });

  Future<void> _submit() => _run(() async {
    await ref.read(accountTrustRepositoryProvider).submitTeenVerification();
    ref.invalidate(teenVerificationStatusProvider);
    if (mounted) {
      setState(
        () => _message =
            'Submitted for restricted review. Your raw school ID stays private.',
      );
    }
  });

  @override
  Widget build(BuildContext context) {
    final verification = ref.watch(teenVerificationStatusProvider);
    return verification.when(
      loading: () => const MortScreen(
        children: [Center(child: CircularProgressIndicator())],
      ),
      error: (error, _) => MortScreen(
        children: [
          const MortHeader(
            eyebrow: 'MORT Verify',
            title: 'Teen verification',
            subtitle: 'Verification status could not be loaded.',
          ),
          MortSafetyBanner(message: userFacingError(error)),
        ],
      ),
      data: (status) => _buildLoaded(context, status),
    );
  }

  Widget _buildLoaded(BuildContext context, TeenVerificationStatus status) {
    final collectionLabel = status.submissionsEnabled
        ? status.isSandbox
              ? 'Synthetic test collection enabled'
              : 'Verification collection enabled'
        : 'Collection not enabled';

    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'MORT Verify',
          title: 'Verify age and school affiliation',
          subtitle:
              'Teen verification requires a confirmed school email and a current school ID. Age is only marked verified when reviewed evidence actually supports the 13–17 age band.',
        ),
        MortSafetyBanner(
          message:
              '${collectionLabel}. School affiliation, age assurance, and identity are separate checks. Verification never guarantees safety.',
        ),
        const SizedBox(height: MortSpacing.md),
        _StatusCard(
          title: 'Age eligibility',
          value: status.ageStatus,
          detail: status.ageBand == null
              ? 'Start a session to establish the claimed age band from your account DOB.'
              : 'Claimed band: ${_humanize(status.ageBand!)}. Final age verification requires independent reviewed evidence.',
          verified: status.ageStatus == 'verified',
        ),
        const SizedBox(height: MortSpacing.sm),
        _StatusCard(
          title: 'School email',
          value: status.schoolEmailVerified ? 'verified' : 'required',
          detail:
              'Your confirmed MORT account email must use an approved school or program domain. Unknown domains go to restricted review.',
          verified: status.schoolEmailVerified,
        ),
        const SizedBox(height: MortSpacing.sm),
        _StatusCard(
          title: 'School ID',
          value: status.schoolIdStatus,
          detail:
              'A current school ID is required. MORT re-encodes the photo to remove ordinary image metadata, stores it in a private bucket, and never publishes it.',
          verified: status.schoolIdStatus == 'reviewed',
        ),
        const SizedBox(height: MortSpacing.sm),
        _StatusCard(
          title: 'Final result',
          value: status.status,
          detail: status.verified
              ? 'Age, school affiliation, and reviewed school-ID checks passed.'
              : 'No final verified result is granted until every required check passes.',
          verified: status.verified,
        ),
        const SizedBox(height: MortSpacing.md),
        if (!status.hasSession)
          MortButton(
            label: 'Start MORT Verify',
            icon: Icons.verified_user_outlined,
            busy: _busy,
            onPressed: status.submissionsEnabled ? _start : null,
          )
        else ...[
          MortTextField(
            label: 'School email',
            controller: _schoolEmail,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            enableSuggestions: false,
            enabled: !_busy && !status.schoolEmailVerified,
          ),
          const SizedBox(height: MortSpacing.sm),
          MortButton(
            label: status.schoolEmailVerified
                ? 'School email verified'
                : 'Verify school email',
            icon: Icons.alternate_email,
            busy: _busy,
            onPressed: status.schoolEmailVerified ? null : _verifySchoolEmail,
          ),
          const SizedBox(height: MortSpacing.sm),
          MortButton(
            label: 'Photograph school ID',
            icon: Icons.camera_alt_outlined,
            busy: _busy,
            onPressed: status.submissionsEnabled
                ? () => _pickSchoolId(ImageSource.camera)
                : null,
          ),
          const SizedBox(height: MortSpacing.sm),
          MortButton(
            label: 'Choose school-ID photo',
            icon: Icons.photo_library_outlined,
            style: MortButtonStyle.secondary,
            busy: _busy,
            onPressed: status.submissionsEnabled
                ? () => _pickSchoolId(ImageSource.gallery)
                : null,
          ),
          const SizedBox(height: MortSpacing.sm),
          MortButton(
            label: 'Submit for review',
            icon: Icons.policy_outlined,
            busy: _busy,
            onPressed:
                status.schoolEmailVerified &&
                    status.schoolIdStatus == 'submitted'
                ? _submit
                : null,
          ),
        ],
        if (_message != null) ...[
          const SizedBox(height: MortSpacing.md),
          MortCard(child: Text(_message!)),
        ],
        const SizedBox(height: MortSpacing.md),
        MortButton(
          label: 'Capture & privacy details',
          icon: Icons.privacy_tip_outlined,
          style: MortButtonStyle.secondary,
          onPressed: () => context.go('/trust/teen-verification/capture'),
        ),
        const SizedBox(height: MortSpacing.sm),
        MortButton(
          label: 'Get verification help',
          icon: Icons.support_agent,
          style: MortButtonStyle.secondary,
          onPressed: () => context.go('/support'),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.value,
    required this.detail,
    required this.verified,
  });

  final String title;
  final String value;
  final String detail;
  final bool verified;

  @override
  Widget build(BuildContext context) => MortCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            MortTrustBadge(label: _humanize(value), verified: verified),
          ],
        ),
        const SizedBox(height: MortSpacing.sm),
        Text(detail),
      ],
    ),
  );
}

class TeenVerificationCapturePreparationScreen extends StatelessWidget {
  const TeenVerificationCapturePreparationScreen({super.key});

  @override
  Widget build(BuildContext context) => MortScreen(
    children: const [
      MortHeader(
        eyebrow: 'MORT Verify privacy',
        title: 'Before you capture a school ID',
        subtitle:
            'Only submit your own current school ID. Do not include unrelated documents.',
      ),
      MortCard(
        child: Text(
          'Before upload, the app re-encodes the image as JPEG to remove ordinary image metadata and caps its dimensions. The server accepts it only into a private user/session path and stores restricted metadata separately.',
        ),
      ),
      SizedBox(height: MortSpacing.md),
      MortCard(
        child: Text(
          'A school ID and school email are not automatically treated as proof of exact age. If the school ID does not contain reliable age evidence, MORT keeps age status unresolved instead of guessing.',
        ),
      ),
      SizedBox(height: MortSpacing.md),
      MortSafetyBanner(
        message:
            'Raw school-ID images are never public profile data. Production collection remains server-gated until legal, privacy, and trained-reviewer controls are approved.',
      ),
    ],
  );
}

class TeenVerificationAdminReviewScreen extends ConsumerStatefulWidget {
  const TeenVerificationAdminReviewScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<TeenVerificationAdminReviewScreen> createState() =>
      _TeenVerificationAdminReviewScreenState();
}

class _TeenVerificationAdminReviewScreenState
    extends ConsumerState<TeenVerificationAdminReviewScreen> {
  final _caseId = TextEditingController();
  final _reason = TextEditingController();
  final _decisionCode = TextEditingController();
  bool _busy = false;
  bool _claimed = false;
  bool _schoolIdCurrent = false;
  bool _schoolMatch = false;
  bool _nameMatch = false;
  bool _dobPresent = false;
  bool _suspectedTamper = false;
  String _ageBand = '13_15';
  Uint8List? _documentBytes;
  String? _message;

  @override
  void dispose() {
    _caseId.dispose();
    _reason.dispose();
    _decisionCode.dispose();
    super.dispose();
  }

  bool get _contextReady =>
      _caseId.text.trim().length >= 4 && _reason.text.trim().length >= 12;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _message = userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _claim() => _run(() async {
    if (!_contextReady) {
      throw StateError('Enter a case ID and a specific access reason first.');
    }
    await ref
        .read(accountTrustRepositoryProvider)
        .claimTeenVerificationReview(
          sessionId: widget.sessionId,
          accessReason: _reason.text,
          caseId: _caseId.text,
        );
    if (mounted) {
      setState(() {
        _claimed = true;
        _message = 'Case claimed for 30 minutes.';
      });
    }
  });

  Future<void> _loadDocument() => _run(() async {
    if (!_claimed) {
      await ref
          .read(accountTrustRepositoryProvider)
          .claimTeenVerificationReview(
            sessionId: widget.sessionId,
            accessReason: _reason.text,
            caseId: _caseId.text,
          );
    }
    final bytes = await ref
        .read(accountTrustRepositoryProvider)
        .downloadTeenSchoolIdForReview(
          sessionId: widget.sessionId,
          accessReason: _reason.text,
          caseId: _caseId.text,
        );
    if (mounted) {
      setState(() {
        _claimed = true;
        _documentBytes = bytes;
        _message =
            'Private document loaded in memory under a short-lived audited grant.';
      });
    }
  });

  Future<void> _review(String action) => _run(() async {
    if (_documentBytes == null) {
      throw StateError('Open the private school ID before making a decision.');
    }
    if (_decisionCode.text.trim().length < 3) {
      throw StateError('Enter a decision code.');
    }
    final result = await ref
        .read(accountTrustRepositoryProvider)
        .reviewTeenVerification(
          sessionId: widget.sessionId,
          action: action,
          schoolIdCurrent: _schoolIdCurrent,
          schoolMatch: _schoolMatch,
          nameMatch: _nameMatch,
          schoolIdDobPresent: _dobPresent,
          observedAgeBand: _dobPresent ? _ageBand : null,
          suspectedTamper: _suspectedTamper,
          decisionCode: _decisionCode.text,
          accessReason: _reason.text,
          caseId: _caseId.text,
        );
    if (mounted) {
      setState(() {
        _documentBytes = null;
        _claimed = false;
        _message =
            'Saved review result: ${result['status']?.toString() ?? action}';
      });
      ref.invalidate(accountTrustProfileProvider);
    }
  });

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        MortHeader(
          eyebrow: 'Restricted reviewer',
          title: 'Teen verification review',
          subtitle:
              'Session ${widget.sessionId}. Raw school-ID access is assignment-bound, temporary, and audited.',
        ),
        MortTextField(label: 'Case ID', controller: _caseId),
        const SizedBox(height: MortSpacing.sm),
        MortTextArea(
          label: 'Access reason',
          controller: _reason,
          maxLength: 800,
        ),
        const SizedBox(height: MortSpacing.sm),
        MortButton(
          label: _claimed ? 'Case claimed' : 'Claim review case',
          icon: Icons.assignment_ind_outlined,
          busy: _busy,
          onPressed: _claimed ? null : _claim,
        ),
        const SizedBox(height: MortSpacing.sm),
        MortButton(
          label: 'Open private school ID',
          icon: Icons.badge_outlined,
          busy: _busy,
          onPressed: _contextReady ? _loadDocument : null,
        ),
        if (_documentBytes != null) ...[
          const SizedBox(height: MortSpacing.md),
          MortCard(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                _documentBytes!,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) =>
                    const Text('The school-ID image could not be rendered.'),
              ),
            ),
          ),
          const SizedBox(height: MortSpacing.sm),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _schoolIdCurrent,
            onChanged: (value) =>
                setState(() => _schoolIdCurrent = value ?? false),
            title: const Text('School ID is current'),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _schoolMatch,
            onChanged: (value) => setState(() => _schoolMatch = value ?? false),
            title: const Text('School matches verified affiliation'),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _nameMatch,
            onChanged: (value) => setState(() => _nameMatch = value ?? false),
            title: const Text('Name matches the account evidence'),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _dobPresent,
            onChanged: (value) => setState(() => _dobPresent = value ?? false),
            title: const Text(
              'School ID contains usable date-of-birth evidence',
            ),
          ),
          if (_dobPresent)
            MortDropdown<String>(
              label: 'Observed age band',
              value: _ageBand,
              items: const {'13_15': '13–15', '16_17': '16–17'},
              onChanged: (value) =>
                  setState(() => _ageBand = value ?? _ageBand),
            ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _suspectedTamper,
            onChanged: (value) =>
                setState(() => _suspectedTamper = value ?? false),
            title: const Text('Possible tampering or mismatch'),
          ),
          MortTextField(
            label: 'Decision code',
            hint: 'approved_school_id_dob_match',
            controller: _decisionCode,
          ),
          const SizedBox(height: MortSpacing.md),
          MortButton(
            label: 'Approve verified teen',
            icon: Icons.verified_outlined,
            busy: _busy,
            onPressed: () => _review('approve'),
          ),
          const SizedBox(height: MortSpacing.sm),
          MortButton(
            label: 'Age evidence still required',
            icon: Icons.hourglass_bottom_outlined,
            style: MortButtonStyle.secondary,
            busy: _busy,
            onPressed: () => _review('age_evidence_required'),
          ),
          const SizedBox(height: MortSpacing.sm),
          MortButton(
            label: 'Request new school-ID photo',
            icon: Icons.refresh_outlined,
            style: MortButtonStyle.secondary,
            busy: _busy,
            onPressed: () => _review('request_recapture'),
          ),
          const SizedBox(height: MortSpacing.sm),
          MortButton(
            label: 'Reject verification',
            icon: Icons.block_outlined,
            style: MortButtonStyle.secondary,
            busy: _busy,
            onPressed: () => _review('reject'),
          ),
        ],
        if (_message != null) ...[
          const SizedBox(height: MortSpacing.md),
          MortCard(child: Text(_message!)),
        ],
      ],
    );
  }
}

String _humanize(String value) => value.replaceAll('_', ' ');
