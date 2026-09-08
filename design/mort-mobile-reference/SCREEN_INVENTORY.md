# MORT reference screen inventory

The interactive reference is available at `/mort-reference` and uses the left rail to switch between representative states.

## Covered in reference

- Boot/welcome: welcome, enter MORT, sign in, network readiness
- Teen: home, nearby jobs, job detail, safety center, inbox, progress/earnings, profile
- Guardian: linked teen overview, approval queue, safety tools, activity summary
- Admin: reports, verification queue, message signals, operations pulse
- Shared states: verified badges, payment preference disclaimer, clear-scope messaging, empty state, safety banner, responsive phone shell, bottom navigation

## Production inventory represented by the reference

Auth/onboarding: `/splash`, `/welcome`, `/auth/sign-in`, `/auth/sign-up`, `/auth/forgot-password`, `/onboarding`, `/account-status`.

Teen: `/teen/home`, `/teen/jobs`, `/teen/jobs/:id`, `/teen/saved`, `/teen/applications`, `/teen/applications/:id`, `/teen/proof/:applicationId`, `/teen/profile`, `/teen/portfolio`, `/teen/skills`, `/teen/availability`, `/teen/goals`, `/teen/hustle-academy`, `/teen/safety`.

Adult/business: `/adult/home`, `/adult/post-job`, `/adult/jobs`, `/adult/jobs/:id`, `/adult/applicants`, `/adult/applicants/:applicationId`, `/adult/proof-review/:applicationId`, `/adult/verification`, `/adult/profile`, `/adult/business`, `/adult/analytics`.

Guardian: `/guardian/home`, `/guardian/linked-teens`, `/guardian/approvals`, `/guardian/approvals/:applicationId`, `/guardian/permissions`, `/guardian/safety-pings`, `/guardian/activity`, `/guardian/emergency-contacts`.

Admin: `/admin/home`, `/admin/reports`, `/admin/reports/:id`, `/admin/verifications`, `/admin/verifications/:id`, `/admin/jobs`, `/admin/messages`, `/admin/safety-pings`, `/admin/users`, `/admin/monetization`, `/admin/support`, `/admin/action-logs`.

Messaging, notifications, settings/legal, support, and monetization remain represented as shared navigation destinations and documented states in the production route map.
