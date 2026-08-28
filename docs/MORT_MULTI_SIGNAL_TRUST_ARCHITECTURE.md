# MORT Multi-Signal Trust Architecture

Status: implemented foundation on hosted Supabase project `rakjydmgwwgtdislanbt`; public marketplace closed.

## Design rule

MORT keeps seven concerns separate: account security, contact ownership, institution affiliation, business registration, digital government credentials, provider-backed identity, and enhanced adult screening. A signal is named for the check that actually occurred. No generic `Verified` badge exists, and no signal guarantees future behavior or safety.

The server is authoritative. Clients render `get_my_account_trust_profile` and ask `get_marketplace_trust_eligibility` before sensitive actions. Clients cannot write trust levels, approve signals, change environments, or promote sandbox evidence.

## Implemented layers

| Layer | Current state | What it means |
| --- | --- | --- |
| Account security | Email ownership, session monitoring, Swift device reauthentication; passkey-ready flag | Protects access only |
| Contact | Confirmed Auth email; phone unavailable in current hosted configuration | Control of a contact method only |
| Affiliation | Approved school domain and hashed partner-code flows | Relationship to an approved organization only |
| Business registration | Allowlisted official-source request and manual review | A public business record may match |
| Digital government credential | Replay-safe server architecture, disabled | No credential is currently accepted |
| Provider identity | Existing signed provider architecture, no provider connected | Not available to production users |
| Enhanced screening | Policy fields and level reserved, disabled | No screening is performed |

## Data and authorization

The additive migration `20260718150502_multi_signal_account_trust_foundation.sql` created versioned private policy plus RLS-protected trust, affiliation, registry, credential-event, appeal, security-preference, and audit tables. Every public RPC revokes anonymous execution, binds the acting user to `auth.uid()`, and uses an explicit `search_path`. Service-only credential and reauthentication event functions are not executable by mobile or web clients.

Trust indicators report what was checked, what was not checked, timestamps, expiry, environment, marketplace effect, and the no-safety-guarantee boundary. Public summaries exclude contact values, school names by default, residence, raw reports, raw evidence, and screening details.

## Marketplace boundary

The active `zero-budget-hosted-closed` policy keeps ordinary production accounts out of job publishing, applying, messaging, private-address release, job execution, proof, completion, reviews, and repeat-work actions. Isolated QA accounts may exercise sandbox flows. Guardian Mode is optional and does not change trust level; a particular job may independently require guardian approval.

## Upgrade path

Higher trust levels require a reviewed policy version, approved provider or platform credential integration, server validation, legal/privacy review, operational review staff, incident procedures, retention/deletion rules, and real-device QA. Enabling a client flag alone cannot grant access.
