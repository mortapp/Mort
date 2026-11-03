# Production crash reporting and legal configuration

Checked 2026-10-28. Applies only to the Flutter MORT app and Supabase project `jxbnrkasktbhtiujkhay`.

## Sentry

The existing Sentry Flutter provider receives `SENTRY_DSN` from the production build process environment through the temporary Dart define file. The shared builder requires a valid HTTPS client ingestion DSN when crash reporting is enabled. Never use a Sentry auth token as a client define. DSN values are not included in the build manifest or diagnostics. Sentry strips message contents, requests, identities, and unsafe breadcrumbs through the existing event sanitizer.

The owner credential folder contains the client ingestion DSN, and the GitHub `Production` environment has `SENTRY_DSN` configured. GitHub was inspected by secret/variable names only; no secret values were read or printed. A non-PII production smoke event sent to the configured Sentry ingestion endpoint was accepted with HTTP 200. This verifies ingestion acceptance; it does not claim that a release build or on-device crash capture has been verified.

Firebase dependencies, config fields, and the Flutter runtime path were removed at the owner's direction. No alternate push service exists in this Flutter app. Production profiles keep remote push disabled; requesting it fails configuration validation. Sentry supplies crash reporting only. In-app notifications remain independent of remote delivery.

## Exact Terms approval evidence

The owner explicitly approved `MORT-LEGAL-2026-V1` in this session. The local source is `C:/Users/micha/Downloads/MORT Master Terms of Service & Defense Framework.pdf`, three pages, with Document Ref `MORT-LEGAL-2026-V1` and effective date October 2026. PDF glyph spacing extracts `M ORT-LEGAL-2026-V1`.

SHA-256 of the exact PDF bytes: `0883f26bf2f6762ba4f924968bfbee9ed0235b1f9c0c30ab8c871a25cfab7e99`.

The production profile's Terms, privacy, community guidelines, and safety rules retain `owner-approval-required` until exact approved content is published and bound to the served clickwrap version/hash. The Terms PDF does not evidence separate approved versions for those documents.

This configuration does not publish legal content or create a backend legal version. Exact bytes must still be bound to the published clickwrap version/hash. The supplied Terms describe Stripe processing, required pre-activation guardian consent, end-to-end messaging, and acceptance by logging in. These claims require reconciliation with the actual app/backend behavior before publication. Stripe and real-document intake remain disabled. Owner approval of this PDF does not prove those product capabilities exist.
