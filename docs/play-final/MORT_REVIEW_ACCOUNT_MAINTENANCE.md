# MORT Review Account Maintenance

Credentials live only in protected User-scope environment variables. Never commit, print, package, screenshot, or email passwords.

- Create/reset fixture: `node scripts/create-play-review-tenant.mjs` or `node scripts/reset-play-review-tenant.mjs` after loading protected environment values.
- Validate: `node scripts/validate-play-review-tenant.mjs`.
- Remove only when review is over: `node scripts/remove-play-review-tenant.mjs`.
- Rotate a credential immediately if exposed, then reset and revalidate.
- Keep email/password login enabled without OTP, phone, ID, location, or invitation dependencies.
- Revalidate after migrations, RLS edits, release-mode changes, or account restrictions.
- Do not use real names, schools, addresses, income, incidents, or messages.
