# MORT Native iOS

`swift_mort` is the native iOS 17+ SwiftUI client for MORT. It shares the hosted Supabase backend with the retained Flutter web/PWA reference and the retained Expo reference app.

## Architecture

- SwiftUI, Observation, async/await, typed routes, and protocol-based repositories
- Official Supabase Swift client for Auth, PostgREST, RPC, Storage, Realtime, and Edge Functions
- RevenueCat iOS SDK and RevenueCatUI using a public iOS SDK key only
- Google Mobile Ads iOS SDK, disabled by default and blocked on sensitive screens
- APNs permission and registration architecture without writing tokens into the incompatible legacy Expo token column

## Client-safe configuration

On a Mac, copy `Config/Secrets.example.xcconfig` to `Config/Secrets.xcconfig` and fill in only:

- `MORT_SUPABASE_URL`
- `MORT_SUPABASE_ANON_KEY`
- `MORT_REVENUECAT_IOS_API_KEY`

Never add a Supabase service-role key, database password, Supabase access token, RevenueCat secret key, webhook secret, or AI provider secret. `Config/Secrets.xcconfig` is gitignored.

## Open on macOS

1. Open `MORT.xcodeproj` in Xcode 16 or newer.
2. Resolve Swift packages.
3. Select a signing team and confirm bundle identifier `com.mortapp.mobile`.
4. Add the Push Notifications and In-App Purchase capabilities in the Apple project as required.
5. Run unit tests before simulator or device QA.

The project was generated on Windows and has not been compiled by Xcode, run in an iOS simulator, installed on an iPhone, or sent to TestFlight.
