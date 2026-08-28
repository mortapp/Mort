import {
  assert,
  pass,
  reviewClient,
  serviceClient,
} from './play-release-qa-helpers.mjs';

const scope = 'qa-play-review-partner-actions';
const teen = await reviewClient('teen');
const adult = await reviewClient('adult');
const admin = serviceClient();
let inviteId;
let attestationId;

try {
  const { data: context, error: contextError } = await adult.client.rpc(
    'get_my_partner_staff_context',
  );
  assert(
    !contextError && context?.items?.length === 1,
    'Synthetic partner staff context is unavailable.',
  );
  const organizationId = context.items[0].organization_id;

  const deniedInvite = await teen.client.rpc('partner_create_pilot_invite', {
    p_organization_id: organizationId,
    p_program_id: null,
    p_expires_at: new Date(Date.now() + 7 * 86400000).toISOString(),
    p_max_uses: 1,
    p_purpose: 'pilot_enrollment',
  });
  assert(
    !deniedInvite.error && deniedInvite.data?.ok === false,
    'A non-partner participant created a partner invitation.',
  );

  const invite = await adult.client.rpc('partner_create_pilot_invite', {
    p_organization_id: organizationId,
    p_program_id: null,
    p_expires_at: new Date(Date.now() + 7 * 86400000).toISOString(),
    p_max_uses: 1,
    p_purpose: 'pilot_enrollment',
  });
  assert(
    !invite.error &&
      invite.data?.ok === true &&
      invite.data?.shown_once === true &&
      invite.data?.stored_as_hash_only === true,
    'Authorized scoped partner invitation creation failed.',
  );
  inviteId = invite.data.code_id;

  const listed = await adult.client.rpc('get_my_partner_invites', {
    p_organization_id: organizationId,
  });
  assert(
    !listed.error &&
      listed.data?.ok === true &&
      listed.data?.raw_codes_included === false &&
      listed.data.items?.some((item) => item.id === inviteId),
    'Partner invitation listing exposed a code or omitted the new invitation.',
  );

  const revokedInvite = await adult.client.rpc(
    'partner_revoke_pilot_invite',
    {
      p_code_id: inviteId,
      p_reason: 'Synthetic release QA cleanup.',
    },
  );
  assert(
    !revokedInvite.error &&
      revokedInvite.data?.ok === true &&
      revokedInvite.data?.status === 'revoked',
    'Partner invitation revocation failed.',
  );

  const deniedAttestation = await teen.client.rpc(
    'submit_partner_attestation',
    {
      p_subject_user_id: teen.user.id,
      p_organization_id: organizationId,
      p_fact_type: 'school_or_program_affiliation',
      p_expires_at: new Date(Date.now() + 30 * 86400000).toISOString(),
    },
  );
  assert(
    !deniedAttestation.error && deniedAttestation.data?.ok === false,
    'A participant created their own partner attestation.',
  );

  const attestation = await adult.client.rpc('submit_partner_attestation', {
    p_subject_user_id: teen.user.id,
    p_organization_id: organizationId,
    p_fact_type: 'school_or_program_affiliation',
    p_expires_at: new Date(Date.now() + 30 * 86400000).toISOString(),
  });
  assert(
    !attestation.error &&
      attestation.data?.ok === true &&
      attestation.data?.government_identity_verified === false &&
      attestation.data?.provider_identity_verified === false &&
      attestation.data?.grants_marketplace_access === false,
    'Limited partner attestation creation failed or overclaimed trust.',
  );
  attestationId = attestation.data.attestation_id;

  const ownAttestations = await teen.client.rpc(
    'get_my_partner_attestations',
  );
  assert(
    !ownAttestations.error &&
      ownAttestations.data?.attestations?.some(
        (item) => item.id === attestationId && item.status === 'active',
      ),
    'The participant could not inspect the limited attestation.',
  );

  const revokedAttestation = await adult.client.rpc(
    'revoke_partner_attestation',
    {
      p_attestation_id: attestationId,
      p_reason: 'Synthetic release QA cleanup.',
    },
  );
  assert(
    !revokedAttestation.error &&
      revokedAttestation.data?.ok === true &&
      revokedAttestation.data?.status === 'revoked' &&
      revokedAttestation.data?.only_associated_indicator_removed === true,
    'Partner attestation revocation failed.',
  );

  const afterRevocation = await teen.client.rpc(
    'get_my_partner_attestations',
  );
  assert(
    !afterRevocation.error &&
      afterRevocation.data?.attestations?.some(
        (item) => item.id === attestationId && item.status === 'revoked',
      ),
    'Revoked partner attestation state is unavailable to its subject.',
  );

  pass(
    scope,
    'partner invite and limited-attestation create/list/revoke paths passed; unauthorized participant attempts failed closed',
  );
} finally {
  if (attestationId) {
    await admin
      .from('partner_audit_events')
      .delete()
      .eq('resource_id', attestationId);
    await admin
      .from('trust_signal_events')
      .delete()
      .eq('source_reference', attestationId);
    await admin.from('partner_attestations').delete().eq('id', attestationId);
  }
  if (inviteId) {
    await admin
      .from('partner_audit_events')
      .delete()
      .eq('resource_id', inviteId);
    await admin.from('partner_invite_codes').delete().eq('id', inviteId);
  }
  await teen.client.auth.signOut();
  await adult.client.auth.signOut();
}
