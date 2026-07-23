# Onboarding State Persistence Report

- Supabase Auth persists the session through `supabase_flutter`.
- Profile role, display name, DOB, city, state, and incomplete status persist in `profiles`.
- Payment preference persists in `payment_preferences` and `profiles.payment_preference`.
- Final acknowledgement persists `profiles.onboarding_completed=true`.
- Route guards resume an incomplete account at the onboarding hub and deny protected routes.
- Skills and availability screens currently do not claim persistence.

Runtime browser refresh and physical-iPhone relaunch persistence remain manual QA. The static auth-persistence script verifies initialization, retry, auth-state observation, and provider invalidation only.
