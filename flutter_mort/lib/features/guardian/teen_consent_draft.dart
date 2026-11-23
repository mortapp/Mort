import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/config/release_profile.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/repositories/providers.dart';
import '../../data/repositories/repository_base.dart';

const _draftOptIn = bool.fromEnvironment('MORT_TEEN_CONSENT_REPLICA_DRAFT');

bool allowTeenConsentReplicaDraft({
  required bool optedIn,
  required String stage,
  required MortReleaseProfile profile,
  required String backendUrl,
  required bool fixtureMode,
}) {
  final uri = Uri.tryParse(backendUrl);
  return optedIn &&
      stage == 'internal_test' &&
      profile == MortReleaseProfile.automatedTest &&
      !fixtureMode &&
      uri != null &&
      uri.scheme == 'https' &&
      uri.userInfo.isEmpty &&
      const {'localhost', '127.0.0.1', '::1', '10.0.2.2'}.contains(uri.host);
}

bool get teenConsentReplicaDraftEnabled => allowTeenConsentReplicaDraft(
  optedIn: _draftOptIn,
  stage: AppConfig.releaseStage,
  profile: AppConfig.releaseProfile,
  backendUrl: AppConfig.supabaseUrl,
  fixtureMode: AppConfig.browserStackQaMode,
);

enum TeenConsentState {
  required('required', 'No current consent request.'),
  awaitingTeenAssent(
    'awaiting_teen_assent',
    'Teen assent has not been recorded.',
  ),
  awaitingGuardianConsent(
    'awaiting_guardian_consent',
    'Guardian consent has not been recorded.',
  ),
  readyForStaffReview(
    'ready_for_staff_review',
    'Staff review is still required.',
  ),
  consentRecorded('consent_recorded', 'Consent recorded.'),
  expired('expired', 'This consent request expired.'),
  withdrawn('withdrawn', 'This consent request was withdrawn.'),
  invalidated('invalidated', 'This consent request is no longer valid.'),
  guardianNotEligible(
    'guardian_not_eligible',
    'Staff review of guardian eligibility is required.',
  );

  const TeenConsentState(this.wireValue, this.label);
  final String wireValue;
  final String label;
}

class TeenConsentStatus {
  const TeenConsentStatus(this.state, this.version);

  final TeenConsentState state;
  final int version;

  factory TeenConsentStatus.fromRpc(Object? response) {
    if (response is! Map ||
        response['ok'] != true ||
        response['contract_version'] is! int ||
        response['contract_version'] != 1) {
      throw const FormatException('Consent status contract unavailable.');
    }
    final version = response['consent_version'];
    if (version is! int || version < 1) {
      throw const FormatException('Consent version unavailable.');
    }
    final state = response['status'];
    for (final candidate in TeenConsentState.values) {
      if (candidate.wireValue == state) {
        // No request, guardian, case, or proof identifiers enter client state.
        return TeenConsentStatus(candidate, version);
      }
    }
    throw const FormatException('Consent state unavailable.');
  }
}

class TeenConsentReplicaRepository extends RepositoryBase {
  Future<TeenConsentStatus> fetchForCurrentTeen(String expectedUserId) async {
    if (!teenConsentReplicaDraftEnabled || requireUserId() != expectedUserId) {
      throw StateError('Consent replica is unavailable for this session.');
    }
    final response = await client.rpc('get_teen_guardian_consent_status_v1');
    if (requireUserId() != expectedUserId) {
      throw StateError('Consent replica session changed.');
    }
    return TeenConsentStatus.fromRpc(response);
  }
}

final teenConsentReplicaStatusProvider = FutureProvider.autoDispose
    .family<TeenConsentStatus, String>((ref, userId) {
      ref.watch(authStateProvider);
      return TeenConsentReplicaRepository().fetchForCurrentTeen(userId);
    });

/// Read-only draft. Deliberately no assent, consent, withdrawal or activation
/// actions until approved notices, participant discovery and lifecycle exist.
class TeenConsentReplicaStatusCard extends ConsumerWidget {
  const TeenConsentReplicaStatusCard({super.key, required this.currentUserId});

  final String currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = teenConsentReplicaStatusProvider(currentUserId);
    final value = ref.watch(provider);
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Guardian consent (QA replica)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: MortSpacing.xs),
          Semantics(
            liveRegion: true,
            child: switch (value) {
              AsyncData(value: final status) when !value.isLoading => Text(
                '${status.state.label} Consent version ${status.version}.',
              ),
              AsyncError() when !value.isLoading => const Text(
                'Consent status could not be confirmed.',
              ),
              _ => const Text('Checking consent status.'),
            },
          ),
          TextButton(
            onPressed: value.isLoading ? null : () => ref.invalidate(provider),
            child: const Text('Refresh consent status'),
          ),
        ],
      ),
    );
  }
}
