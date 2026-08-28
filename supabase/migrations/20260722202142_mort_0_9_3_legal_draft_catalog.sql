-- Inactive 0.9.3 legal-review catalog. Nothing in this migration publishes a
-- document, establishes an effective date, or creates a reacceptance request.

insert into public.legal_documents (
  document_key, title, document_category, publication_status
) values
  ('terms_of_service_0_9_3_draft', 'MORT Terms of Service Draft 0.9.3', 'terms', 'draft_attorney_review'),
  ('terms_of_use_0_9_3_draft', 'MORT Terms of Use Draft 0.9.3', 'terms', 'draft_attorney_review'),
  ('adult_poster_terms_0_9_3_draft', 'MORT Adult Poster Terms Draft 0.9.3', 'role_terms', 'draft_attorney_review'),
  ('teen_participant_terms_0_9_3_draft', 'MORT Teen Participant Terms Draft 0.9.3', 'role_terms', 'draft_attorney_review'),
  ('payment_cancellation_policy_0_9_3_draft', 'MORT Payment and Cancellation Policy Draft 0.9.3', 'payments', 'draft_attorney_review'),
  ('evidence_dispute_policy_0_9_3_draft', 'MORT Evidence and Dispute Policy Draft 0.9.3', 'safety_payments', 'draft_attorney_review'),
  ('ai_support_disclosure_0_9_3_draft', 'MORT AI Support Disclosure Draft 0.9.3', 'ai_support', 'draft_attorney_review'),
  ('support_privacy_retention_0_9_3_draft', 'MORT Support Privacy and Retention Draft 0.9.3', 'privacy', 'draft_attorney_review')
on conflict (document_key) do nothing;

insert into public.legal_document_versions (
  document_id, version_label, content_hash, content_path,
  publication_status, material_revision, requires_electronic_signature,
  language_code, jurisdiction_policy, acceptance_ui_version
)
select document.id, source.version_label, source.content_hash, source.content_path,
  'draft_attorney_review', true, false,
  'en-US', 'requires_jurisdiction_specific_attorney_review', 'legal-clickwrap-v1'
from (
  values
    ('terms_of_service_0_9_3_draft', '0.9.3-draft', '731586fd2472ee682ec8d0f35b067b85dd907acceaf0c632142517222f1dbe85', 'docs/legal/MORT_TERMS_OF_SERVICE_DRAFT_0_9_3.md'),
    ('terms_of_use_0_9_3_draft', '0.9.3-draft', 'b7a73850b2b668241048e026d130df13a1dbc5dd57d2f3dde1d50668d56074d3', 'docs/legal/MORT_TERMS_OF_USE_DRAFT_0_9_3.md'),
    ('adult_poster_terms_0_9_3_draft', '0.9.3-draft', '627eb729e9edd18ed8430454d71587855fac8e78f452121024c5fc389cd5d52c', 'docs/legal/MORT_ADULT_POSTER_TERMS_DRAFT_0_9_3.md'),
    ('teen_participant_terms_0_9_3_draft', '0.9.3-draft', '36b31949d14c2a9f59db8f25cdbbfbe3efa57f7e511dd5cb9fb7a15e0acbe133', 'docs/legal/MORT_TEEN_PARTICIPANT_TERMS_DRAFT_0_9_3.md'),
    ('payment_cancellation_policy_0_9_3_draft', '0.9.3-draft', 'ed7152f90997972a71033e8a3178cdcc9952ed656dcf455fe2953f4edde26798', 'docs/legal/MORT_PAYMENT_AND_CANCELLATION_POLICY_DRAFT_0_9_3.md'),
    ('evidence_dispute_policy_0_9_3_draft', '0.9.3-draft', '097e57409161c3d09b8afd52fb17778377686b6256027c30156cd5551a803a0b', 'docs/legal/MORT_EVIDENCE_AND_DISPUTE_POLICY_DRAFT_0_9_3.md'),
    ('ai_support_disclosure_0_9_3_draft', '0.9.3-draft', '457174f105c1cf0babcbb73d4ae45b9a9ea30fafbf0db552f559f56fe390e7f0', 'docs/legal/MORT_AI_SUPPORT_DISCLOSURE_DRAFT_0_9_3.md'),
    ('support_privacy_retention_0_9_3_draft', '0.9.3-draft', 'a01d5b5505f28921c4fbd8ed8fe4b5229545e47d8423fda7ad62f1dab6df4318', 'docs/legal/MORT_SUPPORT_PRIVACY_AND_RETENTION_DRAFT_0_9_3.md')
) as source(document_key, version_label, content_hash, content_path)
join public.legal_documents document on document.document_key = source.document_key
on conflict (document_id, version_label) do nothing;

-- Assert the safety boundary if this migration is ever edited later.
do $$
begin
  if exists (
    select 1 from public.legal_document_versions version
    join public.legal_documents document on document.id = version.document_id
    where document.document_key like '%_0_9_3_draft'
      and (version.publication_status <> 'draft_attorney_review'
           or version.effective_at is not null
           or version.published_at is not null
           or version.attorney_reviewed_at is not null
           or version.approved_by_counsel_reference is not null)
  ) then
    raise exception '0.9.3 legal drafts must remain inactive pending qualified review';
  end if;
end $$;
