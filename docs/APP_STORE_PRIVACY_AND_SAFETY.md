# App Store Privacy and Safety Notes

MORT is designed for minors and local work opportunities, so App Store review should be prepared with clear safety documentation.

## Data Collected

- Account identifiers: email address, Supabase Auth user id, display name, role.
- Age/safety data: date of birth, guardian connection state, safety ping timestamps.
- Marketplace content: jobs, applications, messages, reports, proof uploads, verification uploads.
- Device data: Expo push token, notification permission status, in-app notification delivery state.
- Optional payment preference labels only. No payment credentials, card data, escrow, or payout processing are collected.

## Permissions

- Notifications: application updates, guardian approval notices, safety reminders, moderation outcomes, and messages.
- Photo library: proof uploads, verification evidence, and report attachments.
- Camera: capturing proof, verification evidence, and report attachments.

## Minor Safety Controls

- Under-13 users are blocked from account creation in app onboarding.
- Teen accounts are restricted to age 13-17.
- Guardian supervision is supported through invite-based connections.
- Adults/businesses cannot post jobs until internally verified.
- Reports, blocking, and admin moderation are implemented.
- Messages are scanned by a server-side Supabase RPC before insert.
- MORT does not show real payment processing flows.
- Admin action logs record moderation status changes for accountability.

## External Requirements Before Production

- Complete a legal review for teen labor, parental consent, privacy, and marketplace rules in each launch jurisdiction.
- Complete Apple Kids Category / child-safety review decisions if positioning changes.
- Add production Terms of Service, Privacy Policy, Community Guidelines, and Safety Center URLs.
- Configure Supabase backups, log retention, and incident response.
- Configure EAS credentials and TestFlight metadata.
