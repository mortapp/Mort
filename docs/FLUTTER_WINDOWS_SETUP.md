# Flutter Windows Setup

## Verified On This Machine

- Flutter is installed.
- Dart is installed.
- Flutter project can resolve packages, analyze, test, and build web on Windows.

## iOS Note

Windows can edit Flutter iOS files but cannot fully build/sign/run the iPhone native app locally. Use a Mac/Xcode path or cloud build/TestFlight path.

## Useful Commands

```powershell
cd C:\Users\micha\Mort\flutter_mort
flutter pub get
flutter analyze
flutter test
flutter build web
```

To run with Supabase public config:

```powershell
flutter run -d chrome --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```
