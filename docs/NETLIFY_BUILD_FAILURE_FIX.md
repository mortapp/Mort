# Netlify Build Failure Fix

Date: 2026-07-11

## Failure

Netlify found the root Expo package, installed its pnpm dependencies, ran no build command, and then tried to publish `flutter_mort/build/web`. That directory did not exist in the fresh build checkout.

## Fix

- `netlify.toml` now sets `flutter_mort` as the base directory.
- Netlify runs `bash ../scripts/netlify-build.sh` explicitly.
- The publish directory is `build/web`, relative to the Flutter base.
- The script installs and caches Flutter 3.41.2 when running on Netlify.
- Only the public Supabase URL and anon key are passed as Dart defines.
- Purchases and ads remain disabled for the web preview.
- The script verifies the required PWA output before the publish stage.
- The script stops if `SUPABASE_SERVICE_ROLE_KEY` is present.

## Required Netlify Variables

Add these with Builds scope:

```text
EXPO_PUBLIC_SUPABASE_URL
EXPO_PUBLIC_SUPABASE_ANON_KEY
```

Do not add private Supabase, RevenueCat, database, or webhook secrets.

## Fast Manual Alternative

Upload `mort-netlify-drop-ready.zip` through Netlify Drop. It contains only the compiled `build/web` contents and does not need a Netlify build command. Do not upload the clean source ZIP through Netlify Drop.
