import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/models/trust_safety.dart';
import '../../data/repositories/providers.dart';
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
        Icon(icon, color: Theme.of(context).colorScheme.primary),
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
  final _permissions = const NativePermissionsService();
  late Future<IdentityVerificationStatus> _identityStatus;
  String? _permissionMessage;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    _identityStatus = ref
        .read(trustSafetyRepositoryProvider)
        .getIdentityStatus();
  }

  bool _canCapture(IdentityVerificationStatus status) =>
      status.submissionsEnabled &&
      status.productionProviderAvailable &&
      status.documentsCollectedByMort;

  Future<void> _requestCameraAfterExplicitAction() async {
    final status = await _identityStatus;
    if (!_canCapture(status) || _requesting) return;
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
  Widget build(
    BuildContext context,
  ) => FutureBuilder<IdentityVerificationStatus>(
    future: _identityStatus,
    builder: (context, snapshot) {
      final status = snapshot.data;
      final canCapture = status != null && _canCapture(status);
      return MortScreen(
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
          if (snapshot.connectionState == ConnectionState.waiting)
            const MortSkeletonCard()
          else if (snapshot.hasError)
            const MortSafetyBanner(
              message:
                  'Verification availability could not be confirmed. MORT is not accepting real identity documents right now.',
            )
          else if (!canCapture)
            const MortSafetyBanner(
              message:
                  'Production verification is not available yet. MORT is not accepting real identity documents.',
            )
          else
            MortButton(
              label: 'Use camera',
              icon: Icons.camera_alt_outlined,
              busy: _requesting,
              onPressed: _requesting ? null : _requestCameraAfterExplicitAction,
            ),
          if (_permissionMessage != null) ...[
            const SizedBox(height: MortSpacing.md),
            Text(_permissionMessage!),
          ],
          if (status != null && !_canCapture(status)) ...[
            const SizedBox(height: MortSpacing.sm),
            const MortCard(
              child: Text('Production verification is not available yet.'),
            ),
          ],
        ],
      );
    },
  );
}
