# MORT Screenshot Privacy Behavior Report

Date: 2026-08-04
Branch: `feature/compact-onboarding-and-screen-polish`

## Summary

Repaired screen security behavior to preserve screenshot privacy on sensitive routes while keeping ordinary app routes screenshotable.

## Security Repairs

- Fixed the screen security reference-counting implementation so nested acquire/release pairs behave correctly.
- Added a test-only platform adapter to validate secure-screen state without requiring a native device.
- Added release and reset helpers for debug/test environments.

## Screenshot Behavior

- Ordinary app routes remain screenshotable, including onboarding steps, teen job feed, applications list, saved jobs, and support routes.
- Sensitive routes remain protected based on their content and user role, including proof upload/review, admin controls, payment operations, account deletion, safety evidence export, and moderation flows.
- Support chat and support ticket screens are intentionally not blocked from screenshots to preserve pilot usability.

## Tests and Validation

- Added lifecycle and navigation tests for secure count behavior.
- Verified that protected route exit restores ordinary route screenshotability.
- Verified that failed navigation or route pop does not leave secure mode enabled.

## Status

- Implementation complete for screen security repairs.
- Verified by analyzer and full Flutter test execution.
- Status: CODE-COMPLETE / PHYSICAL VERIFICATION REQUIRED.
