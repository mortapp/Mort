# MORT Supreme Release Checklist

Release scope: signed Android closed-test candidate `0.9.12+102`. This is not a
public-production approval.

- [x] Flutter format, analyze, and full tests pass.
- [x] Expo reference typecheck, lint, build, and Doctor pass.
- [x] Flutter web and 48-route Expo web exports pass.
- [x] Hosted 45-suite regression passes; transient transport retries recorded.
- [x] 158 migrations match; linked error lint clear; dry-run up to date.
- [x] Nine private buckets and 18 policies audited.
- [x] Signed APK/AAB verified against upload certificate; debug signing rejected.
- [x] Forbidden permissions/capabilities absent; 16 KB ZIP/ELF alignment passes.
- [x] Source, sensitive-file, and binary-artifact secret scans pass.
- [x] npm production audit reports no known vulnerability; dependency drift inventoried.
- [x] Metadata backup created; encrypted CI backup workflow added.
- [ ] Exact final APK passes stable emulator and physical Android matrix.
- [ ] Play Console confirms version code 102 is unused.
- [ ] Owner uploads to closed test and completes policy/declaration review.
- [ ] Production providers, staffing, legal, public web, and restore gates close.
- [ ] iPhone/Xcode/TestFlight/App Store work completes.

Go/no-go for a closed technical test is an owner decision after the unchecked
closed-test items. Public marketplace release remains blocked.
