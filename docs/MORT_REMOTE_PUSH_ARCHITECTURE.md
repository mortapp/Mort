# MORT Remote Notifications

Updated: 2026-10-28

## Current behavior

Remote push delivery is disabled in the Flutter release profile. MORT uses its
authenticated in-app notification inbox. The app has no Firebase SDK or active
Firebase token provider, and the production Supabase project does not have a
push-sending Edge Function deployed.

The Firebase Cloud Messaging sender has been removed from the active Supabase
function source and deployment configuration. No provider credentials or
device tokens are required for the current app.

## Safety boundary

The client-side remote-push provider remains a disabled no-op. The release
configuration rejects attempts to enable remote push without a supported
provider. The Flutter app does not collect provider tokens or register devices.
Notification preferences do not imply that the device has registered for
remote delivery.

In-app notifications remain available through authenticated Supabase queries.
They do not depend on Firebase or another remote push provider.
