# MORT 1,891 Expansion Archive Policy

Final packaging is performed by `scripts/package-1891-expansion.ps1`.

The master archive includes source, tests, lockfiles, Supabase migrations/functions, scripts, and documentation. It excludes environment files, dependency caches, build outputs, logs, database backups, Git metadata, platform dependency output, private keys, and prior archives.

The web archive contains only files from `flutter_mort/build/web`, with `index.html`, `manifest.json`, `flutter_bootstrap.js`, `main.dart.js`, `assets`, and `icons` at its root.

The Swift archive contains `swift_mort` source/project/tests/scripts plus Swift/iPhone documentation only. It excludes environment files, Pods, DerivedData, build products, and secrets.

Every archive must pass:

- forbidden path/extension inspection
- private-key/access-token pattern inspection
- exact current environment secret-value inspection without printing values
- archive-entry count and byte size
- SHA-256 calculation
- byte-for-byte comparison of every archive entry to its workspace source

The public Supabase anon key and RevenueCat public/test SDK key are client configuration, not server secrets. Service-role, database, Supabase access, RevenueCat secret, webhook, push-invoke, AI, hosting, and Apple private credentials are forbidden.
