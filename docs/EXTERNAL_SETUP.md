# External Setup Still Needed

- The old Supabase project `rakjydmgwwgtdislanbt` has been rebuilt and remotely verified for the current MORT backend baseline. See `docs/OLD_PROJECT_REBUILD_REPORT.md`.
- For any new staging/production project, apply the Supabase migration to the target project and run the same smoke/RLS checks before use.
- Deploy `send-push` Edge Function for any new project.
- Set `SEND_PUSH_INVOKE_SECRET` in Supabase/server environment, not in Expo.
- Keep service-role/server secrets in Supabase/server tooling only. Never put them in `.env.local`, Expo/mobile source, commits, or release zips.
- Configure Supabase Auth redirect URLs.
- Create first admin from trusted SQL/dashboard.
- Run Supabase advisors and resolve findings before launch.
- Configure EAS project ID and Apple signing credentials.
- Add final Terms, Privacy Policy, Community Rules, Safety Center, and support contact.
- Complete legal/privacy/teen safety/App Store review.
- Configure production monitoring, backups, abuse workflows, and moderation staffing.
- Complete real iPhone EAS preview/TestFlight push, camera/photo, auth, and role-flow testing before real users.
- Configure RevenueCat iOS public SDK key, products, entitlements, offerings, and sandbox purchase testing.
- Configure AdMob missing ad unit IDs, UMP/consent, app-ads.txt website hosting, and App Store ads/privacy disclosures.
