import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/repositories/providers.dart';
import '../../data/repositories/uploads_repository.dart';

class TeenVerificationOptionsScreen extends StatelessWidget {
  const TeenVerificationOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) => MortScreen(
    children: [
      const MortHeader(
        eyebrow: 'Teen trust options',
        title: 'Choose evidence for review',
        subtitle:
            'Age and school-ID are separate staff-reviewed cases. Each decision is a limited signal and does not establish legal identity.',
      ),
      const MortSafetyBanner(
        message:
            'Private staff review is available only in an explicitly enabled app release. It does not establish legal identity or guarantee safety.',
      ),
      const SizedBox(height: MortSpacing.md),
      const _VerificationOption(
        title: 'Age and school-ID evidence',
        badge: 'Private staff review',
        description:
            'Submit separate documents for age evidence and school-ID review. Files are stored privately for authorized staff review. Neither result is authoritative identity confirmation.',
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
        label: 'Review capture and privacy steps',
        icon: Icons.camera_alt_outlined,
        onPressed: () => context.go('/trust/teen-verification/capture'),
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

class TeenVerificationCapturePreparationScreen extends ConsumerStatefulWidget {
  const TeenVerificationCapturePreparationScreen({super.key});

  @override
  ConsumerState<TeenVerificationCapturePreparationScreen> createState() =>
      _TeenVerificationCapturePreparationScreenState();
}

class _TeenVerificationCapturePreparationScreenState
    extends ConsumerState<TeenVerificationCapturePreparationScreen> {
  bool _busy = false;
  final Set<String> _submittedTypes = <String>{};
  String? _message;

  Future<void> _chooseAndSubmit(String verificationType) async {
    if (!AppConfig.identityVerificationEnabled ||
        _busy ||
        _submittedTypes.contains(verificationType)) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final prepared = UploadsRepository.prepareVerification(bytes);
      await ref
          .read(uploadsRepositoryProvider)
          .submitMyAgeEvidence(prepared, verificationType: verificationType);
      if (!mounted) return;
      setState(() {
        _submittedTypes.add(verificationType);
        _message =
            '${verificationType == 'age' ? 'Age evidence' : 'School-ID evidence'} received. Your case is waiting for staff review.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = _safeUploadError(error, verificationType));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => MortScreen(
    children: [
      const MortHeader(
        eyebrow: 'Before capture',
        title: 'Submit evidence privately',
        subtitle:
            'Choose a clear photo for the selected evidence type. The file is resized and stripped of embedded image metadata before private upload.',
      ),
      const MortCard(
        child: Text(
          'Submit only a document relevant to the selected age or school-ID case. Do not include unrelated pages or information. Your file is stored privately for authorized staff review.',
        ),
      ),
      const SizedBox(height: MortSpacing.md),
      const MortCard(
        child: Text(
          'A reviewer must examine the uploaded document, record a staff-review provider result, then approve the verification case. A successful upload is not verification approval or legal identity confirmation.',
        ),
      ),
      const SizedBox(height: MortSpacing.md),
      MortButton(
        label: !AppConfig.identityVerificationEnabled
            ? 'Age evidence upload disabled for this release'
            : _submittedTypes.contains('age')
            ? 'Age evidence submitted'
            : 'Submit age evidence photo',
        icon: Icons.photo_library_outlined,
        busy: _busy,
        onPressed: AppConfig.identityVerificationEnabled &&
                !_submittedTypes.contains('age')
            ? () => _chooseAndSubmit('age')
            : null,
      ),
      const SizedBox(height: MortSpacing.sm),
      MortButton(
        label: !AppConfig.identityVerificationEnabled
            ? 'School-ID upload disabled for this release'
            : _submittedTypes.contains('school_id')
            ? 'School-ID evidence submitted'
            : 'Submit school-ID photo',
        icon: Icons.badge_outlined,
        style: MortButtonStyle.secondary,
        busy: _busy,
        onPressed: AppConfig.identityVerificationEnabled &&
                !_submittedTypes.contains('school_id')
            ? () => _chooseAndSubmit('school_id')
            : null,
      ),
      if (_message != null) ...[
        const SizedBox(height: MortSpacing.md),
        Text(_message!),
      ],
      if (!AppConfig.identityVerificationEnabled) ...[
        const SizedBox(height: MortSpacing.md),
        const MortSafetyBanner(
          message:
              'Real document upload is disabled in this release. No file is collected; use the app release configured for the approved staff-review workflow.',
        ),
      ],
    ],
  );
}

String _safeUploadError(Object error, String verificationType) {
  final message = error.toString();
  if (message.contains('case_already_pending')) {
    return verificationType == 'age'
        ? 'Your age evidence is already waiting for staff review.'
        : 'Your school-ID evidence is already waiting for staff review.';
  }
  if (message.contains('too_many_submissions')) {
    return 'Too many recent attempts. Please try again later.';
  }
  if (message.contains('minimum_age_required')) {
    return 'This account does not meet MORT’s minimum age requirement.';
  }
  if (message.contains('school_email_required') ||
      message.contains('school_email_verification_required')) {
    final label = verificationType == 'age' ? 'age evidence' : 'school-ID evidence';
    return 'Complete the required school-email step before submitting $label.';
  }
  return 'We could not submit the evidence. Check your connection and try again.';
}
