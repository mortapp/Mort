# Production crash reporting and legal configuration

Checked 2026-10-27. Applies only to the Flutter MORT app and Supabase project `jxbnrkasktbhtiujkhay`.

## Sentry

The existing Sentry Flutter provider receives `SENTRY_DSN` from the production build process environment through the temporary Dart define file. The shared builder requires a valid HTTPS client ingestion DSN when crash reporting is enabled. Never use a Sentry auth token as a client define. DSN values are not included in the build manifest or diagnostics. Sentry still strips message contents, requests, identities, and unsafe breadcrumbs through the existing event sanitizer.

`SENTRY_DSN` is a build-time input embedded by `--dart-define-from-file`, then read by Flutter's `String.fromEnvironment` at startup. It is not fetched from Supabase or changeable remotely in an installed build. For a local production build, supply it in the invoking process environment; the Sentry helper does not load `.env.local`, `flutter_mort/.env.example`, or Windows user-scoped variables. In CI, the workflow maps the Production `SENTRY_DSN` secret to that process environment. Never put a DSN or auth-token value in this document.

If Sentry cannot initialize despite valid configuration, bootstrap rejects startup when crash reporting is required. This checks that the provider initialized; delivery to the actual Sentry project still needs separate device verification. No Sentry instrumentation was found in the inspected Supabase functions, so this path covers Flutter client crashes only.

GitHub metadata inspection (names only): repository secrets are `BROWSERSTACK_ACCESS_KEY` and `BROWSERSTACK_USERNAME`. The Production environment has the non-secret `SUPABASE_URL` variable; its secrets and other variables are empty. `SENTRY_DSN` and the protected signing/Supabase client secrets are missing from Production. No secret values were read, printed, or copied. A real project DSN and a device delivery check remain required.

Firebase dependencies, config fields, and the Flutter runtime path were removed at the owner's direction. No alternate push service exists in this Flutter app. Production profiles keep remote push disabled; requesting it fails configuration validation. Sentry supplies crash reporting only. In-app notifications remain independent of remote delivery.

## Exact Terms approval evidence

The owner explicitly approved `MORT-LEGAL-2026-V1` in this session. The local source is `C:/Users/micha/Downloads/MORT Master Terms of Service & Defense Framework.pdf`, three pages, with Document Ref `MORT-LEGAL-2026-V1` and effective date October 2026. PDF glyph spacing extracts `M ORT-LEGAL-2026-V1`.

SHA-256 of the exact PDF bytes: `0883f26bf2f6762ba4f924968bfbee9ed0235b1f9c0c30ab8c871a25cfab7e99`.

The production profile's Terms, privacy, community guidelines, and safety rules retain `owner-approval-required` until exact approved content is published and bound to the served clickwrap version/hash. The Terms PDF does not evidence separate approved versions for those documents.

This configuration does not publish legal content or create a backend legal version. Exact bytes must still be bound to the published clickwrap version/hash. The supplied Terms describe Stripe processing, required pre-activation guardian consent, end-to-end messaging, and acceptance by logging in. These claims require reconciliation with the actual app/backend behavior before publication. Stripe and real-document intake remain disabled. Owner approval of this PDF does not prove those product capabilities exist.
