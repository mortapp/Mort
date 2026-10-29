# MORT Legal and Android Release Handoff — 2026-10-28

## Scope

This is a verification handoff for the current MORT production work. It does not constitute legal approval, a publication event, or a signed Android release.

## Supabase legal catalog verification

The current connected Supabase project is `mort p` (`jxbnrkasktbhtiujkhay`). The uploaded `supabase-public.env` points to this same project. The repository's current `main` README still names the older backend `rakjydmgwwgtdislanbt`; do not silently treat the new project as a complete data migration or overwrite the old backend reference without reconciling the migration plan.

The current project already contains four legal document/version rows:

| Document key | Version label | Stored Markdown chars | Stored SHA-256 |
| --- | --- | ---: | --- |
| `master_terms_of_service` | `MORT-LEGAL-2026-V3` | 34,362 | `4de47f02c575cccaa90620336fdcaead0c8a23a9165e0b1955088b6994001273` |
| `privacy_policy` | `MORT-PRIVACY-2026-10` | 7,820 | `600eaaf57b3b496fcae70ef43e59c92a82ef4361525a8aba7a524e7789f92491` |
| `safety_rules` | `MORT-SAFETY-2026-10` | 6,744 | `13318930ae3430fba8855581c3367a8f6e0fbe776dc9936ba442ff651e64954b` |
| `community_guidelines` | `MORT-COMMUNITY-2026-10` | 6,027 | `1d82c9af557cac14ab98a3f00c7b8b087478ffe8fc7de8f93e51db926564b68c` |

Verified on 2026-10-28: for all four rows, the stored `content_hash` equals SHA-256 of the stored `content_markdown`. The supplied PDFs and Typst sources are present in the ChatGPT task workspace; this check verifies the integrity of the current database Markdown, not a byte-for-byte equivalence between each PDF/Typst source and the database Markdown.

All four document rows and versions are `draft_attorney_review`. For every version, `effective_at`, `published_at`, `attorney_reviewed_at`, and `approved_by_counsel_reference` are null. There are currently zero legal acceptances, zero legal acceptance audit events, and zero consent rows in this project. Do not fabricate attorney approval, publication, or acceptance records.

The database `content_path` values point to these intended source files:
- `docs/legal/source-of-truth/MORT_Master_Terms_V3.md`
- `docs/legal/source-of-truth/MORT_Privacy_Policy.md`
- `docs/legal/source-of-truth/MORT_Safety_Rules.md`
- `docs/legal/source-of-truth/MORT_Community_Guidelines.md`

Those paths were not found in the inspected repository branch. Because `mortapp/Mort` is public and these documents are still attorney-review drafts, do not publish the full draft text to the public repository merely to satisfy `content_path`. Use an approved private source/archive workflow, or add the public Markdown source only after authorized legal publication. Preserve the existing content and version hashes until an approved source comparison determines that a change is needed.

## Legal flow and access controls

The current SQL definitions establish that:
- `public.legal_documents` and `public.legal_document_versions` expose only published rows to authenticated users through RLS.
- `public.get_my_legal_requirements()` only returns published documents and effective published versions.
- `public.submit_legal_acceptance(...)` rejects versions that are not published and effective.
- `private.mort_user_has_current_legal_acceptances(uuid)` returns false if the actor has no required published documents, preventing the zero-published-document state from being treated as satisfied consent.
- `public.legal_role_requirements` has RLS enabled and no direct table policies; access is through the intended server-side contract.

This is fail-closed behavior. Do not bypass it. The documents need genuine counsel review and a controlled publication step before new users can accept them.

## Release-control snapshot

The current `public.mort_release_control` primary row reports:
- `release_mode = production_public`
- `public_marketplace_enabled = true`
- `real_document_collection = false`
- `maintenance_mode = false`

Reconcile this control state with the missing published legal versions and disabled real identity-document collection before claiming the complete public marketplace is release-ready. The public-marketplace flag alone is not evidence that legal, identity, payment, or safety gates have passed.

## Android signing and AAB

The uploaded credentials archive contains a candidate Android upload keystore, its public PEM certificate, a Windows DPAPI-protected credentials XML, and other credentials. No secrets or private key material may be committed to GitHub or pasted into chat.

Verified from the public certificate: SHA-256 fingerprint
`04:42:C2:21:38:B0:D6:23:F9:A6:F4:78:1A:44:2B:F4:A9:33:27:8F:AB:8E:85:76:74:4D:C1:FD:7C:33:4D:EF`.
The certificate embedded in the uploaded JKS matches the supplied PEM certificate. This does **not** prove that it matches the Google Play Console's current **Upload key certificate**; compare those SHA-256 fingerprints before signing or uploading.

The credentials XML is documented as Windows DPAPI-protected for the original Windows account. This execution environment is Linux, has no Flutter or Android SDK installed, and cannot decrypt that Windows-user-bound credential. The local repository clone also could not be fetched because network access is unavailable. Therefore no AAB was built or signed here.

The repository currently has `.github/workflows/mort-signed-closed-test.yml`, which is manually dispatched and targets the `closed-test-release` environment. It is not a production release workflow. Do not use it to claim a production AAB, and do not change its target to production without auditing its build scripts, environment secrets, and release gates.

## Required next actions

1. Reconcile whether `jxbnrkasktbhtiujkhay` is the production destination replacing `rakjydmgwwgtdislanbt`; preserve the staged migration and data transfer plan.
2. Have qualified counsel review the four supplied documents. Record the real approval reference and date only after approval.
3. Compare the upload certificate SHA-256 with Google Play Console's **Upload key certificate**.
4. On the original Windows account, decrypt the existing credential XML locally and configure the release workflow secrets securely. Do not output or commit the values.
5. Implement or select a reviewed production AAB workflow that targets the intended production backend, runs current tests, signs with the verified upload key, and emits a build manifest with commit SHA, package, version name/code, signing fingerprint, and AAB SHA-256.
6. Only after the release artifact and gates are verified, request final owner approval before uploading/publishing to Google Play.

## Verification boundary

No database rows were modified in this audit. No legal version was published. No release control was changed. No AAB was built. These are deliberate safeguards, not completed release work.


## Additional production security audit notes

Supabase Security Advisor was run against `jxbnrkasktbhtiujkhay` on 2026-10-28. It reported:
- 17 informational `rls_enabled_no_policy` findings. Most are in the non-exposed `private` schema; the two legal-related public tables are `legal_role_requirements` and `legal_acceptance_audit_events`, both intentionally lacking direct client policies in the inspected schema. Verify intended RPC-only access in RLS QA rather than adding broad table policies.
- 1 warning that `public.get_runtime_feature_status()` is a publicly executable SECURITY DEFINER function. It returns runtime-control booleans and reads the private Stripe control row. Review whether anonymous status access is intentional; do not blindly revoke it because app startup may depend on it.
- 44 warnings for authenticated-executable SECURITY DEFINER RPCs. These include server-authoritative onboarding, legal acceptance, guardian, job, and safety flows. Audit each function's caller binding, ownership checks, search path, and grants; do not blanket-revoke the RPCs without checking client dependencies.

These findings were not changed during this audit. The performance advisor also reports unused indexes; that is not sufficient evidence to remove indexes from an almost-empty/new project.
