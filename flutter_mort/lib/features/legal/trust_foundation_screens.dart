import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/repositories/providers.dart';
import '../../services/passkey_capability.dart';

class TrustFoundationsScreen extends ConsumerWidget {
  const TrustFoundationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Trust architecture',
          title: 'Precise signals, no identity theater',
          subtitle:
              'The first-party architecture is implemented for synthetic QA. Real provider verification and real ID collection are disabled.',
        ),
        FutureBuilder<Map<String, dynamic>>(
          future: ref
              .read(legalContractRepositoryProvider)
              .firstPartyTrustStatus(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const MortSkeletonCard();
            }
            if (snapshot.hasError) {
              return MortErrorState(
                title: 'Trust status unavailable',
                message: userFacingError(snapshot.error),
              );
            }
            final status = snapshot.data ?? const {};
            return MortCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusLine(
                    'Real document collection',
                    status['real_document_collection_enabled'] == true,
                  ),
                  _StatusLine(
                    'External web-reuse provider',
                    status['external_web_reuse_enabled'] == true,
                  ),
                  _StatusLine(
                    'Real live-presence collection',
                    status['real_live_presence_enabled'] == true,
                  ),
                  _StatusLine(
                    'Real appearance review',
                    status['real_appearance_review_enabled'] == true,
                  ),
                  _StatusLine(
                    'Public marketplace',
                    status['public_marketplace_open'] == true,
                  ),
                  const Divider(),
                  Text(
                    'Guardian Mode optional: ${status['guardian_mode_optional'] == true ? 'yes' : 'no'}',
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: MortSpacing.md),
        MortButton(
          label: 'Browser-safe capture preparation',
          icon: Icons.camera_alt_outlined,
          style: MortButtonStyle.secondary,
          onPressed: () => context.push('/trust/document-capture'),
        ),
        const SizedBox(height: MortSpacing.sm),
        MortButton(
          label: 'Liveness limits and accessibility',
          icon: Icons.accessibility_new,
          style: MortButtonStyle.secondary,
          onPressed: () => context.push('/trust/liveness'),
        ),
        const SizedBox(height: MortSpacing.sm),
        MortButton(
          label: 'Passkey and device-auth explanation',
          icon: Icons.phonelink_lock,
          style: MortButtonStyle.secondary,
          onPressed: () => context.push('/trust/device-auth'),
        ),
        const SizedBox(height: MortSpacing.md),
        const MortCard(
          color: MortColors.cardAlt,
          child: Text(
            'Document quality, OCR, barcode or MRZ parsing, a web-image no-match, visual review, a visible face, camera gestures, school email, phone OTP, and Apple Face ID do not independently establish authoritative legal identity.',
          ),
        ),
      ],
    );
  }
}

class BrowserSafeCapturePreparationScreen extends StatelessWidget {
  const BrowserSafeCapturePreparationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Capture preparation',
          title: 'Real identity capture is off',
          subtitle:
              'This screen explains future quality checks without opening the browser camera or file picker for identity documents.',
        ),
        MortCard(
          color: MortColors.cardAlt,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.block, color: MortColors.danger),
              const SizedBox(width: MortSpacing.sm),
              Expanded(
                child: Text(
                  kIsWeb
                      ? 'Web preview: do not photograph or upload a driver’s license, state ID, passport, school ID, selfie, or face video. A native app and all production readiness gates are required.'
                      : 'Real document collection remains disabled until every production readiness gate passes.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: MortSpacing.md),
        const _Checklist(
          items: [
            'Future quality checks may assess blur, glare, framing, edge visibility, resolution, and front/back completeness.',
            'A readable document does not prove the document is authentic or belongs to the account holder.',
            'No real ID should be sent to Google Search, Google Images, Google Lens, consumer group chat, or an unapproved processor.',
            'Provider contracts, consent, retention, deletion, breach response, trained reviewers, privacy review, and legal review are required first.',
          ],
        ),
        const SizedBox(height: MortSpacing.md),
        const MortButton(
          label: 'Native app required for future approved capture',
          icon: Icons.phone_iphone,
          style: MortButtonStyle.disabled,
        ),
      ],
    );
  }
}

class LivenessExplanationScreen extends StatelessWidget {
  const LivenessExplanationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MortScreen(
      children: [
        MortHeader(
          eyebrow: 'Live presence',
          title: 'Replay resistance is not identity proof',
          subtitle:
              'Real face video and camera gestures are unavailable in web preview. Synthetic QA is controlled and creates no identity level.',
        ),
        _Checklist(
          items: [
            'A future server-issued random sequence, nonce, expiration, and one-time binding can reduce basic replay risk.',
            'Blinking, head movement, speech, or camera presence cannot prove legal name, age, document ownership, or safety.',
            'No persistent face template should be created by this workflow.',
            'A failed or skipped gesture must not infer deception, disability, identity, or risk.',
          ],
        ),
        SizedBox(height: MortSpacing.md),
        MortCard(
          color: MortColors.cardAlt,
          child: Text(
            'Accessibility alternative: offer trained human review or another approved evidence route for movement, vision, speech, lighting, device, disability, culture, or trauma constraints, without penalizing the user.',
          ),
        ),
        SizedBox(height: MortSpacing.md),
        MortButton(
          label: 'Real liveness disabled',
          icon: Icons.videocam_off_outlined,
          style: MortButtonStyle.disabled,
        ),
      ],
    );
  }
}

class DeviceAuthExplanationScreen extends StatelessWidget {
  const DeviceAuthExplanationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Account protection',
          title: 'Passkeys and device authentication',
          subtitle:
              'This device can report passkey support. Face ID availability can only be confirmed in the native iPhone app.',
        ),
        FutureBuilder<PasskeyCapability>(
          future: detectPasskeyCapability(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const MortSkeletonCard();
            final capability = snapshot.data!;
            return MortCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusLine(
                    'WebAuthn browser API',
                    capability.browserApiAvailable,
                  ),
                  _StatusLine('Secure context', capability.secureContext),
                  _StatusLine(
                    'Platform authenticator reported',
                    capability.platformAuthenticatorAvailable,
                  ),
                  const Divider(),
                  Text(capability.detail),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: MortSpacing.md),
        const MortCard(
          color: MortColors.cardAlt,
          child: Text(
            'A passkey proves control of an account credential. Apple Face ID or Touch ID can unlock a local credential or native app action. Neither proves legal identity, age, address, school, document ownership, or personal safety. MORT receives no raw biometric data or template.',
          ),
        ),
        const SizedBox(height: MortSpacing.md),
        const MortButton(
          label: 'Server enrollment remains disabled',
          icon: Icons.key_off_outlined,
          style: MortButtonStyle.disabled,
        ),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine(this.label, this.enabled);

  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MortSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          MortBadge(
            label: enabled ? 'Enabled' : 'Disabled',
            color: enabled ? MortColors.neon : MortColors.warning,
          ),
        ],
      ),
    );
  }
}

class _Checklist extends StatelessWidget {
  const _Checklist({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: MortSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: MortColors.neon,
                    size: 18,
                  ),
                  const SizedBox(width: MortSpacing.xs),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
