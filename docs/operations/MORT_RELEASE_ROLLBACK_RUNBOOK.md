# MORT Release Rollback Runbook

## Mobile

1. Stop rollout in Play Console/App Store Connect; do not delete evidence.
2. Disable the affected server-authoritative capability or set maintenance mode.
3. Keep previously installed clients fail closed through minimum-version and
   release-profile controls.
4. Rebuild from the last verified source/artifact hash with a new version code.
   Never reuse a Play/App Store build number.
5. Run signed artifact, RLS, Auth/session, marketplace, messaging, report/block,
   Safety Ping, account deletion, and accessibility regressions before rollout.

## Web

1. Freeze deployment and preserve the failed deploy ID/hash.
2. Repoint the host to the last verified immutable deployment.
3. Purge CDN cache only after rollback content is available.
4. Verify auth callbacks, account deletion, legal routes, role guards, CSP, and
   hosted Supabase target.

## Backend

Database rollback is not a blind down migration. Close the affected feature,
back up first, create an additive repair migration, run linked lint/dry-run, and
exercise complete multi-user isolation. Destructive restore requires explicit
owner approval and an isolated recovery procedure.

