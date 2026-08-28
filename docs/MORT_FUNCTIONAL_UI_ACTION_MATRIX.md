# MORT Functional UI Action Matrix

Date: 2026-08-04
Branch: `feature/compact-onboarding-and-screen-polish`

## Summary

This matrix captures the implemented user flows, actions, and expected UI behavior for compact onboarding and job/safety interactions.

## Onboarding

- Step 1: welcome and role selection.
- Step 2: DOB entry with teen/adult/guardian routing.
- Step 3: profile basics capture.
- Step 4: approximate location and travel preferences.
- Step 5: interests and safety preferences.
- Final step: summary screen and backend completion.
- Legal acknowledgement is enforced before completion.

## Applications

- Role-aware application detail loading distinguishes teen, adult, and guardian routes.
- Application list and detail screens handle loading, error, and not-found states.
- Backend and RLS authorization boundaries are enforced for detail access.

## Job Feed

- Job feed state repairs for search, filter, sort, and refresh.
- Backend-authorized visibility ensures users only see permitted postings.
- Filter chips remain responsive and clear when no results are valid.
- Feed retains SafeArea and bottom-nav layout integrity.

## Saved Jobs

- Saved jobs are fetched through backend RPCs.
- Supports refresh, browse, and remove operations.
- Handles unavailable jobs with an explicit empty/broken state.
- Uses compact list layout on narrow screens.

## Safety Center

- Emergency action labeled `Call 911` with telephone intent.
- Safety Ping and Safety Circle features are available.
- Urgent support and disclaimer copy are present.
- Layout fixes preserve action visibility and spacing.

## Status

- Implementation complete for the audited UI and action matrix.
- Verified by analyzer and full Flutter test execution.
- Status: CODE-COMPLETE / PHYSICAL VERIFICATION REQUIRED.
