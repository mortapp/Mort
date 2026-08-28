# Vercel Web Deploy

This deploys the free iPhone web preview only.

## Build Locally

From `C:\Users\micha\Mort`:

```powershell
.\scripts\build-web-preview.ps1
```

The deployable folder is:

```text
C:\Users\micha\Mort\flutter_mort\build\web
```

## Vercel CLI Deploy

```powershell
npm install -g vercel
vercel login
cd "C:\Users\micha\Mort\flutter_mort\build\web"
vercel
vercel --prod
```

When prompted, deploy the current directory as a static site. The current directory should be `build\web`.

## Vercel Project Deploy

If you connect a repository later, configure:

- Framework preset: Other
- Build command: `flutter build web --release --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY --dart-define=WEB_PREVIEW_MODE=true --dart-define=IAP_ENABLED=false --dart-define=ADS_ENABLED=false --dart-define=USE_TEST_ADS=true`
- Output directory: `flutter_mort/build/web`

## Notes

- Do not deploy the entire source tree as the public output.
- Do not include secrets in Vercel project files.
- Store only public browser values in Vercel build variables. Never store service_role or database passwords for the web app.
- This web preview is temporary until native iPhone/TestFlight testing is possible.
