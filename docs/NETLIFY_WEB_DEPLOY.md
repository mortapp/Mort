# Netlify Web Deploy

This deploys the main Flutter app as the free iPhone web preview. The Expo project at the repository root is a reference app and is not the Netlify target.

## Git-Connected Deploy

The root `netlify.toml` supplies the complete build configuration:

```text
Base directory: flutter_mort
Build command: bash ../scripts/netlify-build.sh
Publish directory: build/web
Flutter version: 3.41.2
```

In Netlify, add these site environment variables with **Builds** scope:

```text
EXPO_PUBLIC_SUPABASE_URL
EXPO_PUBLIC_SUPABASE_ANON_KEY
```

Use the hosted Supabase URL and public anon key. Do not add `SUPABASE_SERVICE_ROLE_KEY`, a database password, a Supabase access token, or RevenueCat server secrets. The build script fails if a service-role key is present.

Commit and push `netlify.toml` and `scripts/netlify-build.sh`, then trigger **Deploy site**. The first build installs a pinned Flutter SDK in Netlify's dependency cache; later builds reuse it.

Do not replace the configured build command with `pnpm build`. That command builds the Expo reference app to `dist`, not the Flutter app configured for this preview.

## Build Locally

From `C:\Users\micha\Mort`:

```powershell
.\scripts\build-web-preview.ps1
```

The deployable folder is:

```text
C:\Users\micha\Mort\flutter_mort\build\web
```

## Drag-and-Drop Deploy

1. Go to `https://app.netlify.com/drop`.
2. Drag the `C:\Users\micha\Mort\flutter_mort\build\web` folder into the page, or upload `mort-netlify-drop-ready.zip`.
3. Wait for Netlify to publish the site.
4. Open the Netlify HTTPS URL on iPhone Safari.
5. Add the site to the Home Screen.

Do not upload a clean source ZIP to Netlify Drop. A source ZIP contains Flutter source and requires the Git-connected build path above. The deployment ZIP already has `index.html` and the compiled web assets at its root.

## Netlify CLI Deploy

```powershell
npm install -g netlify-cli
netlify login
netlify deploy --dir "C:\Users\micha\Mort\flutter_mort\build\web"
netlify deploy --prod --dir "C:\Users\micha\Mort\flutter_mort\build\web"
```

Use the preview URL for testing first. Use the production URL only when the preview looks right.

## Notes

- Deploy the contents of `build\web`, not the whole repository.
- Do not upload `.env`, `.env.local`, `.dart_tool`, `build` source artifacts outside the generated web folder, or secrets.
- The generated browser app contains the public Supabase anon key needed by Supabase Auth. It must not contain service_role, database passwords, access tokens, or webhook secrets.
- This is not native iPhone/TestFlight testing.
