-- Catalog the 25 repository legal drafts by exact file hash. They remain
-- non-published and cannot be accepted until a future attorney-reviewed
-- version supplies content, effective dates, and counsel approval evidence.

alter table public.job_contract_versions
  add constraint job_contract_versions_source_change_request_fk
  foreign key (source_change_request_id)
  references public.job_contract_change_requests(id)
  on delete restrict;

with catalog(document_key, title, document_category) as (
  values
    ('mort_acceptable_use_policy', 'MORT Acceptable Use Policy', 'conduct'),
    ('mort_adult_poster_agreement', 'MORT Adult Poster Agreement Draft', 'role_agreement'),
    ('mort_business_account_agreement', 'MORT Business Account Agreement Draft', 'role_agreement'),
    ('mort_closed_pilot_rules', 'MORT Closed Pilot Rules', 'pilot'),
    ('mort_community_and_safety_rules', 'MORT Community and Safety Rules', 'safety'),
    ('mort_data_retention_and_deletion', 'MORT Data Retention and Deletion Draft', 'privacy'),
    ('mort_face_id_disclosure', 'MORT Face ID and Touch ID Disclosure', 'device_security'),
    ('mort_identity_review_disclosure', 'MORT Identity Review Disclosure', 'identity'),
    ('mort_incident_and_evidence_policy', 'MORT Incident and Evidence Policy', 'evidence'),
    ('mort_insurance_disclosure', 'MORT Insurance Disclosure Draft', 'risk'),
    ('mort_job_service_agreement', 'MORT Job Service Agreement Draft', 'job_contract'),
    ('mort_limitation_of_liability', 'MORT Limitation of Liability Draft', 'risk'),
    ('mort_liveness_check_disclosure', 'MORT Live-Presence Check Disclosure', 'identity'),
    ('mort_location_and_meeting_policy', 'MORT Location and Meeting Policy', 'safety'),
    ('mort_marketplace_risk_disclosure', 'MORT Marketplace Risk Disclosure', 'risk'),
    ('mort_moderation_and_appeals_policy', 'MORT Moderation and Appeals Policy', 'moderation'),
    ('mort_partner_organization_agreement', 'MORT Partner Organization Agreement Draft', 'role_agreement'),
    ('mort_payment_dispute_policy', 'MORT Payment Dispute Policy', 'payment'),
    ('mort_payment_obligation_agreement', 'MORT Payment Obligation Agreement Draft', 'payment'),
    ('mort_privacy_policy', 'MORT Privacy Policy Draft', 'privacy'),
    ('mort_prohibited_work_policy', 'MORT Prohibited Work Policy', 'safety'),
    ('mort_teen_plain_language_terms', 'MORT Teen Plain-Language Terms', 'plain_language'),
    ('mort_terms_of_service', 'MORT Terms of Service Draft', 'platform_terms'),
    ('mort_terms_of_use', 'MORT Terms of Use Draft', 'platform_terms'),
    ('mort_volunteer_and_tester_policy', 'MORT Volunteer and Tester Policy Draft', 'operations')
)
insert into public.legal_documents (
  document_key, title, document_category, publication_status,
  guardian_mode_independent
)
select document_key, title, document_category, 'draft_attorney_review', true
from catalog
on conflict (document_key) do update
set title = excluded.title,
    document_category = excluded.document_category,
    publication_status = 'draft_attorney_review',
    guardian_mode_independent = true;

update public.legal_documents
set plain_language_summary_key = 'mort_teen_plain_language_terms'
where document_key in ('mort_terms_of_service', 'mort_terms_of_use');

with versions(document_key, content_hash, content_path) as (
  values
    ('mort_acceptable_use_policy', '98e981e7bbf117c3eb0afb6d2384040d50f8317f36f2c842870a36a38a379245', 'docs/legal/MORT_ACCEPTABLE_USE_POLICY.md'),
    ('mort_adult_poster_agreement', '2774fddfe5ee727429a55a9f08a3832e25a835dbef1b4fffb106bdfa9a36d41a', 'docs/legal/MORT_ADULT_POSTER_AGREEMENT_DRAFT.md'),
    ('mort_business_account_agreement', '931055c59dc397daf4cdda5ee3e32708014918f7aa562e3620767bab28065546', 'docs/legal/MORT_BUSINESS_ACCOUNT_AGREEMENT_DRAFT.md'),
    ('mort_closed_pilot_rules', '1177aa8616a540641e17052d69fa6096803bf42d5f64e5a10b012bb23ddfa185', 'docs/legal/MORT_CLOSED_PILOT_RULES.md'),
    ('mort_community_and_safety_rules', '8b9b25849b949beadc26775fc2f80ee74f3d9258c1c108e845491678579656bd', 'docs/legal/MORT_COMMUNITY_AND_SAFETY_RULES.md'),
    ('mort_data_retention_and_deletion', '5a6a9d2d2a22e47d875ea4da46b9dc5c82837025b03e147811c519b3e39c7b40', 'docs/legal/MORT_DATA_RETENTION_AND_DELETION_DRAFT.md'),
    ('mort_face_id_disclosure', 'e1b7ddde4480393da3feb657bdb355adce6b84b0c034f9a1973d8ff87ff073ed', 'docs/legal/MORT_FACE_ID_DISCLOSURE.md'),
    ('mort_identity_review_disclosure', '76c84a12c3bc8cf1469c62ac19c15c9cc65b3a397949585714b9eceaafe32601', 'docs/legal/MORT_IDENTITY_REVIEW_DISCLOSURE.md'),
    ('mort_incident_and_evidence_policy', 'd6e969b10d63bec83c1bc98e8f8dc353f1cfe61823464f3fd6624cf1ae171780', 'docs/legal/MORT_INCIDENT_AND_EVIDENCE_POLICY.md'),
    ('mort_insurance_disclosure', '18838b88346efc3237ba731c0093c194984305da529739c0bde3e1f0465117b8', 'docs/legal/MORT_INSURANCE_DISCLOSURE_DRAFT.md'),
    ('mort_job_service_agreement', '6c9c09731f9190cc3a4a20924fd1f099a623cb9dfb22016b49b8030d80221c53', 'docs/legal/MORT_JOB_SERVICE_AGREEMENT_DRAFT.md'),
    ('mort_limitation_of_liability', '037dbe5fdb286b54b7348f1d9dfac2561a5b03b120c678f19e09ce3960493466', 'docs/legal/MORT_LIMITATION_OF_LIABILITY_DRAFT.md'),
    ('mort_liveness_check_disclosure', 'd2de14a56da19243efe20c8b856e4c6e40af8b3cfcd17758e61995dd516a80ca', 'docs/legal/MORT_LIVENESS_CHECK_DISCLOSURE.md'),
    ('mort_location_and_meeting_policy', 'f35e31c3b4a5143c6e2de5df85b779544f601d78dced60a7bd6be8d87a098990', 'docs/legal/MORT_LOCATION_AND_MEETING_POLICY.md'),
    ('mort_marketplace_risk_disclosure', 'c83b3f51a9ffc659cd912d22a258ec956f2e869de83ee30aa887e9196994e023', 'docs/legal/MORT_MARKETPLACE_RISK_DISCLOSURE.md'),
    ('mort_moderation_and_appeals_policy', 'd60b3e0f7b5f2c5886d76eb53b61e97873852e1d6c3617f4f1e5866b1b8f02ee', 'docs/legal/MORT_MODERATION_AND_APPEALS_POLICY.md'),
    ('mort_partner_organization_agreement', '701e3ecfb5ca234265efa191e90ee26cb735297f87cfc5d4b95e01b35f881e4b', 'docs/legal/MORT_PARTNER_ORGANIZATION_AGREEMENT_DRAFT.md'),
    ('mort_payment_dispute_policy', '535b579cab927dea5a237321a150851cfce555c35d568aa1eb6b43db617c0ac7', 'docs/legal/MORT_PAYMENT_DISPUTE_POLICY.md'),
    ('mort_payment_obligation_agreement', '2aae03eb4ae1f4c7f63f30d20910d80879f68c0bfc4338b7a4172e58e56a0601', 'docs/legal/MORT_PAYMENT_OBLIGATION_AGREEMENT_DRAFT.md'),
    ('mort_privacy_policy', '1fb1b55a54d64651f3a0457ec0cfb9cceb3dfa15112631db88eeceb7c7284d36', 'docs/legal/MORT_PRIVACY_POLICY_DRAFT.md'),
    ('mort_prohibited_work_policy', 'e9e685742c7b9563061ab10fc31ae4b7265cea242c96117dbf86a9146edd09e2', 'docs/legal/MORT_PROHIBITED_WORK_POLICY.md'),
    ('mort_teen_plain_language_terms', 'c199fb3a347471097d414b3d3ffa897558ebd55aae010ebd7632532c188c5d98', 'docs/legal/MORT_TEEN_PLAIN_LANGUAGE_TERMS.md'),
    ('mort_terms_of_service', 'cf6e419fd9c8a11823e768a1d65ab96ffcf33addd47e145cbaa23d7cbfe0b194', 'docs/legal/MORT_TERMS_OF_SERVICE_DRAFT.md'),
    ('mort_terms_of_use', '38592d9bd4e9f2abc9a31549860d396b24bde6105a2e87a1ecf31c93ba3200d3', 'docs/legal/MORT_TERMS_OF_USE_DRAFT.md'),
    ('mort_volunteer_and_tester_policy', 'ee123f14be28b5da60931abb786a9071e39292b58ddb634da549d31e0d83f6ca', 'docs/legal/MORT_VOLUNTEER_AND_TESTER_POLICY_DRAFT.md')
)
insert into public.legal_document_versions (
  document_id, version_label, content_hash, content_path,
  material_revision, publication_status, jurisdiction_policy,
  acceptance_ui_version
)
select
  document.id,
  '2026-07-19-attorney-draft-1',
  version.content_hash,
  version.content_path,
  true,
  'draft_attorney_review',
  'requires_jurisdiction_specific_attorney_review',
  'legal-clickwrap-v1'
from versions version
join public.legal_documents document on document.document_key = version.document_key
on conflict (document_id, version_label) do update
set content_hash = excluded.content_hash,
    content_path = excluded.content_path,
    publication_status = 'draft_attorney_review',
    effective_at = null,
    published_at = null,
    attorney_reviewed_at = null,
    approved_by_counsel_reference = null;

with role_requirements(document_key, role, age_band, required, priority) as (
  values
    ('mort_teen_plain_language_terms', 'teen'::public.user_role, 'all', true, 10),
    ('mort_terms_of_service', 'teen'::public.user_role, 'all', true, 20),
    ('mort_terms_of_use', 'teen'::public.user_role, 'all', true, 30),
    ('mort_privacy_policy', 'teen'::public.user_role, 'all', true, 40),
    ('mort_community_and_safety_rules', 'teen'::public.user_role, 'all', true, 50),
    ('mort_prohibited_work_policy', 'teen'::public.user_role, 'all', true, 60),
    ('mort_marketplace_risk_disclosure', 'teen'::public.user_role, 'all', true, 70),
    ('mort_closed_pilot_rules', 'teen'::public.user_role, 'all', true, 80),
    ('mort_terms_of_service', 'adult'::public.user_role, 'all', true, 10),
    ('mort_terms_of_use', 'adult'::public.user_role, 'all', true, 20),
    ('mort_privacy_policy', 'adult'::public.user_role, 'all', true, 30),
    ('mort_adult_poster_agreement', 'adult'::public.user_role, 'all', true, 40),
    ('mort_community_and_safety_rules', 'adult'::public.user_role, 'all', true, 50),
    ('mort_prohibited_work_policy', 'adult'::public.user_role, 'all', true, 60),
    ('mort_marketplace_risk_disclosure', 'adult'::public.user_role, 'all', true, 70),
    ('mort_closed_pilot_rules', 'adult'::public.user_role, 'all', true, 80),
    ('mort_terms_of_service', 'guardian'::public.user_role, 'all', true, 10),
    ('mort_terms_of_use', 'guardian'::public.user_role, 'all', true, 20),
    ('mort_privacy_policy', 'guardian'::public.user_role, 'all', true, 30),
    ('mort_community_and_safety_rules', 'guardian'::public.user_role, 'all', true, 40),
    ('mort_terms_of_service', 'admin'::public.user_role, 'all', true, 10),
    ('mort_terms_of_use', 'admin'::public.user_role, 'all', true, 20),
    ('mort_privacy_policy', 'admin'::public.user_role, 'all', true, 30),
    ('mort_volunteer_and_tester_policy', 'admin'::public.user_role, 'all', true, 40)
)
insert into public.legal_role_requirements (
  document_id, role, age_band, required, priority
)
select document.id, requirement.role, requirement.age_band, requirement.required, requirement.priority
from role_requirements requirement
join public.legal_documents document on document.document_key = requirement.document_key
on conflict (document_id, role, age_band) do update
set required = excluded.required,
    priority = excluded.priority;

insert into public.legal_jurisdiction_requirements (
  document_id, country_code, region_code, requirement_status,
  guardian_legal_consent_required, configured_separately_from_guardian_mode
)
select
  document.id, 'US', '*', 'legal_review_required', null, true
from public.legal_documents document
on conflict (document_id, country_code, region_code) do update
set requirement_status = 'legal_review_required',
    guardian_legal_consent_required = null,
    configured_separately_from_guardian_mode = true,
    legal_review_reference = null,
    effective_at = null;
