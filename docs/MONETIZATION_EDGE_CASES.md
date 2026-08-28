# Monetization Edge Cases

- Missing SDK key or disabled IAP: show unavailable state; never unlock.
- Web preview: native RevenueCat UI remains disabled.
- Empty offering/package: show setup state and retain free path.
- Cancellation: report cancellation without an error or entitlement.
- Network/store error: show safe retry copy; retain free access.
- Expired/revoked entitlement: refresh CustomerInfo and backend cache before access.
- Duplicate webhook: remote event handling must remain idempotent.
- Username token and job boost: consume only server-granted credits.
- Account switch: RevenueCat logs out before Supabase sign-out and identifies the next Supabase UID.
