# Monetization RPC response implementation plan

> Execute sequentially; AGENTS.md prohibits delegation.

**Goal:** Read the single authoritative row returned by the entitlement and ad RPCs.
**Architecture:** Preserve SQL RPC signatures and use Supabase's object-response transform. No client grants, catalog or paywall redesign.
**Spec:** MORT Master Execution Blueprint server-authoritative entitlement and privacy rules.

- [x] Inspect table-returning SQL definitions, repository consumers, and installed PostgREST `.single()` implementation.
- [x] Add `flutter_mort/test/monetization_repository_rpc_test.dart` with a synthetic loopback HTTP fixture, valid rows and missing-row errors.
- [x] Reproduce both list-to-map failures before modifying the client.
- [x] Update only `getMyEntitlements()` and `adEligibility()` in `flutter_mort/lib/data/repositories/monetization_repository.dart` to request `.single()`; focused regression tests pass.
- [x] Finish full Flutter analysis and regression, parity/safety tests, formatting, secret scan and sequential review before committing.
- [ ] Confirm unused version code after prior artifact delivery, then package only the approved ordinary closed-test profile with real Play billing and verify signing/integrity/alignment. Preserve existing artifacts and build 114.
