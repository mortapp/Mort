# MORT Netlify Legal/Support Deployment

The package builds without private configuration, but the deploy script refuses public deployment until all required User-scope values exist.

Required: `MORT_PUBLIC_PUBLISHER_NAME`, `MORT_PUBLIC_SUPPORT_EMAIL`, `MORT_PUBLIC_PRIVACY_EMAIL`, `MORT_PUBLIC_CHILD_SAFETY_EMAIL`, `MORT_PUBLIC_WEBSITE_URL`, `MORT_PUBLIC_EFFECTIVE_DATE`, `NETLIFY_AUTH_TOKEN`, and `NETLIFY_SITE_ID`.

1. Adult owner and qualified reviewers approve the content and contacts.
2. Set the values at User scope; do not place tokens in files.
3. Run `.\scripts\deploy-netlify-legal-site.ps1`.
4. Set `MORT_VALIDATE_PUBLIC_BASE_URL=https://your-domain.example` in the current process.
5. Run `node scripts/validate-public-legal-site.mjs` and require HTTPS 200 for every route.
6. Verify mobile layout, account-deletion redirect URLs in Supabase Auth, contact mailboxes, and public access without sign-in.
7. Only then enter those HTTPS URLs in Play Console.

Current status: deployable package generated; publisher/contact configuration and hosted HTTPS evidence remain external blockers.
