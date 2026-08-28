# MORT Feature Deduplication Report

## Result

- Accepted registry count: 1891
- Unique normalized accepted titles: 1891
- Duplicate candidates removed before acceptance: 24
- Accepted cross-platform duplicates: 0

## Method

The generator uses one product record across SwiftUI, Flutter Web, and Supabase. The validator checks IDs, slugs, normalized titles, required descriptions, roles, quotas, statuses, paid-safety violations, and evidence for every implementation claim. Candidate button labels, visual variants, platform copies, fields, tests, and documentation are excluded from the accepted count.

## Removed Candidates

- `MORT-D-001` Separate dark-mode version of every feature: This is a presentation, platform, field, test, or micro-step duplicate rather than a distinct real-world capability.
- `MORT-D-002` Separate Swift copy of every shared capability: This is a presentation, platform, field, test, or micro-step duplicate rather than a distinct real-world capability.
- `MORT-D-003` Separate Flutter copy of every shared capability: This is a presentation, platform, field, test, or micro-step duplicate rather than a distinct real-world capability.
- `MORT-D-004` One feature for every job-category dropdown option: This is a presentation, platform, field, test, or micro-step duplicate rather than a distinct real-world capability.
- `MORT-D-005` One feature for every notification wording variation: This is a presentation, platform, field, test, or micro-step duplicate rather than a distinct real-world capability.
- `MORT-D-006` One feature for every unread-badge color: This is a presentation, platform, field, test, or micro-step duplicate rather than a distinct real-world capability.
- `MORT-D-007` One feature for every database column: This is a presentation, platform, field, test, or micro-step duplicate rather than a distinct real-world capability.
- `MORT-D-008` One feature for every analytics event: This is a presentation, platform, field, test, or micro-step duplicate rather than a distinct real-world capability.
- `MORT-D-009` One feature for every validation error string: This is a presentation, platform, field, test, or micro-step duplicate rather than a distinct real-world capability.
- `MORT-D-010` One feature for every loading spinner: This is a presentation, platform, field, test, or micro-step duplicate rather than a distinct real-world capability.
- `MORT-D-011` One feature for every empty-state illustration: This is a presentation, platform, field, test, or micro-step duplicate rather than a distinct real-world capability.
- `MORT-D-012` One feature for every button rename: This is a presentation, platform, field, test, or micro-step duplicate rather than a distinct real-world capability.
- `MORT-D-013` One feature for every icon swap: This is a presentation, platform, field, test, or micro-step duplicate rather than a distinct real-world capability.
- `MORT-D-014` One feature for every typography size: This is a presentation, platform, field, test, or micro-step duplicate rather than a distinct real-world capability.
- `MORT-D-015` One feature for every settings toggle label: This is a presentation, platform, field, test, or micro-step duplicate rather than a distinct real-world capability.
- `MORT-D-016` Duplicate report flow for each role: This is a presentation, platform, field, test, or micro-step duplicate rather than a distinct real-world capability.
- `MORT-D-017` Duplicate block flow for each role: This is a presentation, platform, field, test, or micro-step duplicate rather than a distinct real-world capability.
- `MORT-D-018` Duplicate Safety Ping flow for each role: This is a presentation, platform, field, test, or micro-step duplicate rather than a distinct real-world capability.
- `MORT-D-019` Duplicate saved-search flow for each platform: This is a presentation, platform, field, test, or micro-step duplicate rather than a distinct real-world capability.
- `MORT-D-020` Duplicate profile editor for each profile section: This is a presentation, platform, field, test, or micro-step duplicate rather than a distinct real-world capability.
- `MORT-D-021` Duplicate upload feature for each accepted file extension: This is a presentation, platform, field, test, or micro-step duplicate rather than a distinct real-world capability.
- `MORT-D-022` Duplicate retry feature for each HTTP status code: This is a presentation, platform, field, test, or micro-step duplicate rather than a distinct real-world capability.
- `MORT-D-023` Documentation page counted as a product capability: This is a presentation, platform, field, test, or micro-step duplicate rather than a distinct real-world capability.
- `MORT-D-024` Test case counted as a user capability: This is a presentation, platform, field, test, or micro-step duplicate rather than a distinct real-world capability.
