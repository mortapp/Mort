# Auth Setup

MORT uses Supabase Auth only. No Clerk or secondary identity provider is used.

## Email/Password

In Supabase Dashboard:

1. Enable Email provider.
2. Enable email/password signups for MVP testing.
3. Decide whether email confirmation is required before TestFlight.
4. Keep anonymous sign-ins disabled.

The app currently implements sign-up and sign-in. Password reset UI is not implemented yet, so add it before public launch if password reset is required in-app.

## Redirect URLs

Add local/testing redirect URLs:

```text
mort://
exp://127.0.0.1:8081
http://localhost:8081
```

Add production/TestFlight redirect URLs once EAS project and domains are known:

```text
mort://
https://<your-production-domain>
```

The sign-up flow uses `Linking.createURL("/")`, so Expo development URLs may vary by device/network. Add the exact Expo URL shown by `npx expo start` during real-device testing if email confirmation is enabled.

## Profile Creation

The database trigger `handle_new_auth_user` creates an empty `profiles` row when Supabase Auth creates a user. The app then routes incomplete profiles to onboarding.

## Onboarding Completion

Onboarding writes display name, DOB, role, city, state, and `onboarding_completed = true`. The database enforces:

- under 13 cannot complete onboarding
- teen role requires age 13-17
- adult, guardian, and admin require age 18+
- completed profiles require display name, DOB, role, city, and two-letter state

## Role Selection

The app allows users to select only `teen`, `adult`, or `guardian`. Admin is intentionally excluded from onboarding.

## Admin Role

Admin cannot be self-selected. First admin promotion must happen through trusted SQL/dashboard after a real Supabase Auth user exists.
