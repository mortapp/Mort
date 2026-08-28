# MORT Flutter iOS Build Report

## Current evidence

Shared Flutter iOS source received the same local-auth, app-lock, encrypted-session, foreground-area, permission, deep-link, account-deletion-request, and manual fallback logic as Android. `Info.plist` contains camera, photo, Face ID, when-in-use location, notification wording, and the `mort` URL scheme.

## Not performed

- No macOS/Xcode build
- No CocoaPods or Swift Package dependency build verification on macOS
- No iOS Simulator run
- No physical iPhone permission or lifecycle test
- No TestFlight archive/upload
- No App Store Connect review

The existing SwiftUI reference app remains intact. Its compilation status was not changed or claimed in this Windows Android catch-up pass.

## Required next evidence

Run `flutter build ios --release --no-codesign` on macOS, then build/archive with the correct Apple team and bundle identifier. Test Face ID/passcode fallback, Keychain session migration, camera/photo selection, notification permission, foreground location, custom callback links, and app-lock background timing on a real iPhone.
