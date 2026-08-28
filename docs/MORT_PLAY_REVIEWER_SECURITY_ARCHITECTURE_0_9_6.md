# MORT Play Reviewer Security Architecture 0.9.6

Version: `0.9.6+96`  
Supabase project: `rakjydmgwwgtdislanbt`

## Session Boundary

Reviewer mode is a dedicated in-memory Riverpod `ChangeNotifier` session. It is not Supabase Auth, anonymous Auth, a production user, or a demo role stored in client metadata. It has no access token, refresh token, service-role key, user JWT, backend repository, Storage client, payment SDK, or persistence provider.

The exact reserved identifier is `play-review@mortapp.test`. Matching trims only ordinary outer ASCII whitespace, rejects non-ASCII input, and performs an exact case-sensitive comparison. Aliases, uppercase variants, other domains, internal whitespace, Unicode whitespace, and Unicode lookalikes do not activate review mode.

Review mode can start only when no production Auth user is present. Every `/review` route checks both the local reviewer state and absence of a production Supabase session. Production routes continue to require normal Auth and RLS. Exit and process restart erase the reviewer state.

## Synthetic Capabilities

Teen, Adult, Guardian, Support, and Admin experiences are driven by constant synthetic descriptions and local checkmark state. The proof workflow creates a local generated proof card. Demo PINs `123456` and `654321` are compared only in the local controller. Payment and admin actions rotate or toggle local state and are labeled as demonstrations.

The reviewer feature files do not import Supabase, repositories, Storage, Stripe, payment SDKs, or persistence. They cannot obtain production records or invoke a backend function.

## Server Reservation

Migration `20260726024327_reserve_play_reviewer_identifier.sql` installs a `BEFORE INSERT OR UPDATE OF email` trigger on `auth.users`. The trigger rejects the reserved normalized email and has no `anon` or `authenticated` execute grant. This blocks normal sign-up, OAuth creation, invitation, admin creation, and email reassignment for the reserved identifier.

The app also rejects the identifier in public sign-up before making an Auth request. Client validation is convenience only; the database trigger is the authoritative reservation.

## Verified Denials

`scripts/qa-play-reviewer-isolation.mjs` verifies the active trigger, no existing reserved Auth user, failed Auth Admin creation, ordinary email/password Auth continuity, no anonymous session, no anonymous profile/message/proof reads, rejection of both demo PINs at production RPCs, and denial of destructive runtime-admin controls.

This design provides isolated store-review access. It is not a production-readiness claim and does not replace Play review, physical-device testing, legal review, privacy review, or teen-safety review.
