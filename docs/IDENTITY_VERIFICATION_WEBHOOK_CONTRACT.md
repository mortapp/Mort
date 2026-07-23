# Identity Verification Webhook Contract

## Status

`identity-verification-webhook` is deployed as an inactive provider-neutral receiver. Hosted mode is disabled, no provider secret was installed, and no production provider is connected. Requests therefore fail closed before provider processing.

The function uses `verify_jwt=false` because an external vendor cannot present a Supabase user JWT. Authentication is instead the signed raw-body contract below. The database result RPC is restricted to `service_role`.

## Required Server Configuration

The following belong only in the Supabase Edge Function environment:

- `IDENTITY_VERIFICATION_MODE=production`
- `IDENTITY_VERIFICATION_PROVIDER`
- `IDENTITY_VERIFICATION_WEBHOOK_SECRET`
- Supabase-managed `SUPABASE_URL`
- Supabase-managed `SUPABASE_SERVICE_ROLE_KEY`

No values are stored in source, client configuration, `.env.local`, QA archives, or this document. Production mode must remain disabled until all readiness gates are approved.

## Request

Method: `POST`

Maximum raw body: 128 KiB.

Required headers:

- `x-mort-timestamp`: Unix epoch seconds
- `x-mort-event-id`: stable provider event ID, 8-200 characters
- `x-mort-signature`: 64-character hexadecimal HMAC, optionally prefixed with `v1=`

Canonical signature input:

```text
<timestamp>.<event-id>.<exact-raw-request-body>
```

Algorithm: HMAC-SHA256 using the server-only webhook secret. Comparison is constant-time after strict hexadecimal validation. The timestamp tolerance is five minutes.

Required JSON fields:

- `event_id`: must equal the header event ID
- `provider`: must equal the configured provider
- `environment`: must be `production`
- `account_id`: expected MORT account UUID
- `provider_reference`: inquiry/session reference
- `result_status`: `approved`, `rejected`, or `needs_review`
- `age_band`: `teen_13_17` or `adult_18_plus`
- `verification_level`: integer 0-4
- `expires_at`: required future timestamp for approved results

## Server Validation

The Edge Function verifies signature, timestamp, event ID, body shape, provider, production environment, account ID, provider reference, status, age band, level, expiry, and SHA-256 payload hash. The database then verifies hosted readiness, provider/session binding, user binding, event freshness, result semantics, idempotency, and replay uniqueness.

Unknown, unsigned, malformed, replayed, sandbox, stale, mismatched, or unconfigured events fail closed. The unique `(provider, event_id)` constraint supplies durable replay protection.

## Responses

- `200`: accepted exactly once
- `400`: malformed, mismatched, sandbox, stale, or unknown result
- `401`: missing or invalid signature
- `409`: replayed event
- `413`: oversized payload
- `503`: verification disabled or production provider not ready

Response bodies are minimal and never return identity evidence or secret material.

