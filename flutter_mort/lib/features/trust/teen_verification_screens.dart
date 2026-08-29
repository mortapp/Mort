import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/config/app_config.dart';
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
        subtitle: 'A current middle-school or high-school ID review is recommended when available, but it is not mandatory.',
      ),
      const MortSafetyBanner(
        message: 'This screen uses synthetic examples only. It does not establish legal identity or guarantee safety.',
      ),
      const SizedBox(height: MortSpacing.md),
      const _VerificationOption(
        title: 'Current school ID review',
        badge: 'Recommended',
        description: 'Middle school, junior high, high school, secondary school, or a vocational secondary program. Visual review can support the label “School document reviewed”; it does not prove current enrollment, attendance, legal identity, age, or account ownership.',
        icon: Icons.school_outlined,
      ),
      const SizedBox(height: MortSpacing.sm),
      const _VerificationOption(
        title: 'Verified school email',
        description: 'Where an approved school domain is available, a confirmed account email may support “School affiliation confirmed.”',
        icon: Icons.alternate_email,
      ),
      const SizedBox(height: MortSpacing.sm),
      const _VerificationOption(
        title: 'Partner or youth-program attestation',
        description: 'An approved organization may provide a current, auditable affiliation signal without giving that organization access to private job activity.',
        icon: Icons.groups_outlined,
      ),
      const SizedBox(height: MortSpacing.sm),
      const _VerificationOption(
        title: 'Government or youth-program ID',
        description: 'A future reviewed route. MORT is not accepting real government, school, or youth-program documents in this release.',
        icon: Icons.badge_outlined,
      ),
      const SizedBox(height: MortSpacing.sm),
      const _VerificationOption(
        title: 'Manual exception or no-document review',
        description: 'For homeschool, online-school, transitional, dual-enrollment, or other eligible teens without a traditional school ID. Access requires a reviewed policy decision.',
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
        Icon(icon, color: MortColors.neon),
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
        subtitle: 'MORT requests camera access only after you choose a permitted document route and tap Use camera.',
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
          message: 'This release collects no real ID or face media. Synthetic QA is controlled by server-only test routes.',
        ),
      ],
    ],
  );
}
