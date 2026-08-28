# Netlify Final Deploy Guide

## Connected Repository

The repository configuration builds the Flutter app directly:

```text
Base directory: flutter_mort
Build command: bash ../scripts/netlify-build.sh
Publish directory: build/web
```

Set `EXPO_PUBLIC_SUPABASE_URL` and `EXPO_PUBLIC_SUPABASE_ANON_KEY` in Netlify with Builds scope before deploying. Do not configure private backend or RevenueCat server credentials in Netlify for this static web build.

## Drag and Drop

1. Unzip `mort-netlify-drop-ready.zip`.
2. Confirm `index.html` is at the extracted root.
3. Open `https://app.netlify.com/drop`.
4. Drag the extracted folder, not the zip and not its parent folder.
5. Open the generated HTTPS URL and verify `/manifest.json`.

## CLI

Set `NETLIFY_AUTH_TOKEN` and `NETLIFY_SITE_ID` in the user/process environment, install Netlify CLI, then run:

```powershell
cd C:\Users\micha\Mort
.\scripts\deploy-netlify.ps1
```

The script builds, validates `build/web/index.html`, and deploys without printing credentials. Netlify SPA rewrites are present in both `_redirects` and `netlify.toml`. No untested CSP is enabled.
