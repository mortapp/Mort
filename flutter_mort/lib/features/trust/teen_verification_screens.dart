import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/config/app_config.dart';
import '../../data/repositories/providers.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../services/native_permissions_service.dart';

class TeenVerificationOptionsScreen extends StatelessWidget {
  const TeenVerificationOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) => MortScreen(
    children: [
      const MortHeader(
        eyebrow: 'Teen trust options',
        title: 'Choose an evidence route',
        subtitle:
            'A current middle-school or high-school ID review is recommended when available, but it is not mandatory.',
      ),
      const MortSafetyBanner(
        message:
            'This screen uses synthetic examples only. It does not establish legal identity or guarantee safety.',
      ),
      const SizedBox(height: MortSpacing.md),
      const _VerificationOption(
        title: 'Current school ID review',
        badge: 'Recommended',
        description:
            'Middle school, junior high, high school, secondary school, or a vocational secondary program. Visual review can support the label “School document reviewed”; it does not prove current enrollment, attendance, legal identity, age, or account ownership.',
        icon: Icons.school_outlined,
      ),
      const SizedBox(height: MortSpacing.sm),
      const _VerificationOption(
        title: 'Verified school email',
        description:
            'Where an approved school domain is available, a confirmed account email may support “School affiliation confirmed.”',
        icon: Icons.alternate_email,
      ),
      const SizedBox(height: MortSpacing.sm),
      const _VerificationOption(
        title: 'Partner or youth-program attestation',
        description:
            'An approved organization may provide a current, auditable affiliation signal without giving that organization access to private job activity.',
        icon: Icons.groups_outlined,
      ),
      const SizedBox(height: MortSpacing.sm),
      const _VerificationOption(
        title: 'Government or youth-program ID',
        description:
            'A future reviewed route. MORT is not accepting real government, school, or youth-program documents in this release.',
        icon: Icons.badge_outlined,
      ),
      const SizedBox(height: MortSpacing.sm),
      const _VerificationOption(
        title: 'Manual exception or no-document review',
        description:
            'For homeschool, online-school, transitional, dual-enrollment, or other eligible teens without a traditional school ID. Access requires a reviewed policy decision.',
        icon: Icons.support_agent,
      ),
      const SizedBox(height: MortSpacing.md),
      MortButton(
        label: 'Start MORT Verify',
        icon: Icons.verified_user_outlined,
        onPressed: () => context.go('/trust/teen-verification/verify'),
      ),
      const SizedBox(height: MortSpacing.sm),
      MortButton(
        label: 'Request a manual route',
        icon: Icons.support_agent,
        style: MortButtonStyle.secondary,
        onPressed: () => context.go('/support'),
      ),
    ],
  );
}

class _VerificationOption extends StatelessWidget {
  const _VerificationOption({
    required this.title,
    required this.description,
    required this.icon,
    this.badge,
  });

  final String title;
  final String description;
  final IconData icon;
  final String? badge;

  @override
  Widget build(BuildContext context) => MortCard(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: MortColors.accent),
        const SizedBox(width: MortSpacing.sm),
        Expanded(
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
                  if (badge != null) MortBadge(label: badge!),
                ],
              ),
              const SizedBox(height: MortSpacing.xs),
              Text(description),
            ],
          ),
        ),
      ],
    ),
  );
}

class TeenVerificationCapturePreparationScreen extends StatefulWidget {
  const TeenVerificationCapturePreparationScreen({super.key});

  @override
  State<TeenVerificationCapturePreparationScreen> createState() =>
      _TeenVerificationCapturePreparationScreenState();
}

class _TeenVerificationCapturePreparationScreenState
    extends State<TeenVerificationCapturePreparationScreen> {
  final _permissions = const NativePermissionsService();
  String? _permissionMessage;
  bool _requesting = false;

  Future<void> _requestCameraAfterExplicitAction() async {
    if (!AppConfig.identityVerificationEnabled || _requesting) return;
    setState(() => _requesting = true);
    final result = await _permissions.requestCamera();
    if (!mounted) return;
    setState(() {
      _requesting = false;
      _permissionMessage = result.isGranted
          ? 'Camera permission granted. Only an approved capture session may continue.'
          : result.isPermanentlyDenied
          ? 'Camera permission is blocked. Use Photo Picker or open device Settings later.'
          : 'Camera permission was not granted. Photo Picker remains available when a reviewed capture route is enabled.';
    });
  }

  @override
  Widget build(BuildContext context) => MortScreen(
    children: [
      const MortHeader(
        eyebrow: 'Before capture',
        title: 'Document capture and privacy',
        subtitle:
            'MORT requests camera access only after you choose a permitted document route and tap Use camera.',
      ),
      const MortCard(
        child: Text(
          'MORT uses your camera to capture the document or photo you choose to submit. Do not include unrelated documents or sensitive information. Images require private storage, size and dimension checks, metadata stripping, random object names, and a user-bound server record.',
        ),
      ),
      const SizedBox(height: MortSpacing.md),
      const MortCard(
        child: Text(
          'Future capture checks may warn about blur, glare, cutoff, or low resolution. “Document quality passed,” “School document reviewed,” “Age evidence reviewed,” and “Live-presence challenge completed” are limited signals. They do not mean authoritative identity confirmed.',
        ),
      ),
      const SizedBox(height: MortSpacing.md),
      MortButton(
        label: AppConfig.identityVerificationEnabled
            ? 'Use camera'
            : 'Use camera - Real collection disabled',
        icon: Icons.camera_alt_outlined,
        busy: _requesting,
        onPressed: AppConfig.identityVerificationEnabled
            ? _requestCameraAfterExplicitAction
            : null,
      ),
      const SizedBox(height: MortSpacing.sm),
      MortButton(
        label: 'Photo Picker - unavailable for real IDs',
        icon: Icons.photo_library_outlined,
        style: MortButtonStyle.disabled,
      ),
      if (_permissionMessage != null) ...[
        const SizedBox(height: MortSpacing.md),
        Text(_permissionMessage!),
      ],
      if (!AppConfig.identityVerificationEnabled) ...[
        const SizedBox(height: MortSpacing.md),
        const MortSafetyBanner(
          message:
              'This release collects no real ID or face media. Synthetic QA is controlled by server-only test routes.',
        ),
      ],
    ],
  );
}

class MortVerifyTeenScreen extends ConsumerStatefulWidget {
  const MortVerifyTeenScreen({super.key});

  @override
  ConsumerState<MortVerifyTeenScreen> createState() =>
      _MortVerifyTeenScreenState();
}

class _MortVerifyTeenScreenState extends ConsumerState<MortVerifyTeenScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _picker = ImagePicker();

  Map<String, dynamic>? _status;
  String? _sessionId;
  String? _message;
  bool _busy = false;
  bool _frontUploaded = false;
  bool _backUploaded = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final status = await ref.read(mortVerifyRepositoryProvider).getStatus();
      if (!mounted) return;
      setState(() {
        _status = status;
        final session = status['session'];
        if (session is Map) {
          _sessionId = session['id'] as String?;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _message = 'MORT Verify status could not be loaded.');
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start() => _run(() async {
    final result = await ref
        .read(mortVerifyRepositoryProvider)
        .start(_emailController.text);
    if (!mounted) return;
    setState(() {
      _sessionId = result['session_id'] as String?;
      _message =
          'Verification code sent to ${result['email_masked'] ?? 'your school email'}.';
    });
    await _refresh();
  });

  Future<void> _verifyCode() => _run(() async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    await ref
        .read(mortVerifyRepositoryProvider)
        .verifySchoolEmailCode(
          sessionId: sessionId,
          code: _codeController.text,
        );
    if (!mounted) return;
    setState(() => _message = 'School email confirmed. Add your school ID.');
    await _refresh();
  });

  Future<void> _capture(String side) => _run(() async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 95,
      requestFullMetadata: false,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    await ref
        .read(mortVerifyRepositoryProvider)
        .uploadSchoolId(
          sessionId: sessionId,
          side: side,
          source: Uint8List.fromList(bytes),
        );
    if (!mounted) return;
    setState(() {
      if (side == 'front') _frontUploaded = true;
      if (side == 'back') _backUploaded = true;
      _message = 'School ID ${side == 'front' ? 'front' : 'back'} received.';
    });
    await _refresh();
  });

  Future<void> _submit() => _run(() async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    await ref.read(mortVerifyRepositoryProvider).submit(sessionId);
    if (!mounted) return;
    setState(() {
      _message =
          'Submitted for review. School affiliation, student identity, and age are evaluated separately.';
    });
    await _refresh();
  });

  @override
  Widget build(BuildContext context) {
    final available = _status?['available'] == true;
    final session = _status?['session'];
    final sessionMap = session is Map
        ? Map<String, dynamic>.from(session)
        : const <String, dynamic>{};
    final state = sessionMap['status'] as String?;
    final emailVerified = sessionMap['school_email_verified'] == true;
    final ageVerified = sessionMap['age_verified'] == true;
    final schoolVerified = sessionMap['school_affiliation_verified'] == true;
    final studentIdentityVerified =
        sessionMap['student_identity_verified'] == true;

    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'MORT Verify',
          title: 'Verify school affiliation and age',
          subtitle:
              'MORT keeps school affiliation, student identity, and age as separate checks. A school email alone never proves your age.',
        ),
        const MortSafetyBanner(
          message:
              'Only submit your own current school ID. Raw verification media is private and retained only for the configured verification/retention period.',
        ),
        const SizedBox(height: MortSpacing.md),
        if (!available) ...[
          const MortCard(
            child: Text(
              'MORT Verify is installed but real submissions are currently disabled server-side. This prevents real school IDs from being collected before the verification program is approved.',
            ),
          ),
        ] else if (_sessionId == null) ...[
          MortTextField(
            controller: _emailController,
            label: 'School email',
            hint: 'name@school.org',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: MortSpacing.sm),
          MortButton(
            label: 'Send school verification code',
            icon: Icons.alternate_email,
            busy: _busy,
            onPressed: _busy ? null : _start,
          ),
        ] else ...[
          MortCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Session status: ${state ?? 'starting'}'),
                const SizedBox(height: MortSpacing.xs),
                Text('School email: ${emailVerified ? 'Verified' : 'Pending'}'),
                Text(
                  'School affiliation: ${schoolVerified ? 'Verified' : 'Pending'}',
                ),
                Text(
                  'Student identity: ${studentIdentityVerified ? 'Verified' : 'Pending'}',
                ),
                Text(
                  'Age: ${ageVerified ? (sessionMap['age_band'] ?? 'Verified') : 'Not yet verified'}',
                ),
              ],
            ),
          ),
          const SizedBox(height: MortSpacing.md),
          if (!emailVerified) ...[
            MortTextField(
              controller: _codeController,
              label: '8-digit verification code',
              hint: '00000000',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: MortSpacing.sm),
            MortButton(
              label: 'Verify school email',
              icon: Icons.mark_email_read_outlined,
              busy: _busy,
              onPressed: _busy ? null : _verifyCode,
            ),
          ] else if (state == 'school_id_required' ||
              state == 'document_pending') ...[
            MortButton(
              label: _frontUploaded
                  ? 'Retake school ID front'
                  : 'Capture school ID front',
              icon: Icons.badge_outlined,
              busy: _busy,
              onPressed: _busy ? null : () => _capture('front'),
            ),
            const SizedBox(height: MortSpacing.sm),
            MortButton(
              label: _backUploaded
                  ? 'Retake school ID back'
                  : 'Capture school ID back (if it has information)',
              icon: Icons.flip_to_back_outlined,
              style: MortButtonStyle.secondary,
              busy: _busy,
              onPressed: _busy ? null : () => _capture('back'),
            ),
            const SizedBox(height: MortSpacing.sm),
            MortButton(
              label: 'Submit for verification review',
              icon: Icons.send_outlined,
              busy: _busy,
              onPressed: _busy || !_frontUploaded ? null : _submit,
            ),
          ] else if (state == 'manual_review') ...[
            const MortCard(
              child: Text(
                'Your school email and school ID were submitted. A reviewer must verify the evidence before any age or student-identity assertion is granted.',
              ),
            ),
          ] else if (state == 'needs_age_evidence') ...[
            const MortCard(
              child: Text(
                'School affiliation was confirmed, but the submitted evidence did not independently prove your age. An approved age-evidence route is still required.',
              ),
            ),
          ] else if (state == 'verified') ...[
            const MortCard(
              child: Text(
                'MORT Verify completed. The app only exposes the verified assertions needed by the marketplace, not your raw school ID.',
              ),
            ),
          ],
        ],
        if (_message != null) ...[
          const SizedBox(height: MortSpacing.md),
          Text(_message!),
        ],
      ],
    );
  }
}
