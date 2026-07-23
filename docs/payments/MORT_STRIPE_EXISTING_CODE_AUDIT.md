# Existing Stripe Code Audit

The audited implementation is in:

- `supabase/migrations/20260722032907_stripe_connect_sandbox_foundation.sql`
- `supabase/migrations/20260722034445_stripe_webhook_completion_rpc.sql`
- `supabase/functions/_shared/stripe.ts`
- `supabase/functions/stripe-*`
- `flutter_mort/lib/features/payments/stripe_marketplace_screens.dart`
- `flutter_mort/lib/features/payments/stripe_payment_sheet_service.dart`

Verified properties: no provider secret in Flutter; user identity comes from a validated Supabase JWT; amounts come from the accepted contract version; private financial tables expose only caller-safe RPC projections; provider writes require service role; webhook bodies are size-limited and signature-verified; event IDs and payload hashes are replay protected; test/live object references cannot mix; and Google Play entitlements are separate.

Provider-backed behavior is not verified because Stripe test keys and webhook secret are absent. The Edge Functions are intentionally not deployed in this state. This audit does not certify tax, employment, money-transmission, minor-account, payout, or consumer-credit compliance.
