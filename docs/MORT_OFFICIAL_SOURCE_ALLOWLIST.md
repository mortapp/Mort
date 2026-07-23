# MORT Official Source Allowlist

The allowlist is deny-by-default and stored in `official_source_allowlist`. Client-provided URLs do not become trusted sources. A source must match category, hostname, jurisdiction, active state, and permitted review mode.

## Current entries

| Category | Jurisdiction | Host | Mode | Purpose |
| --- | --- | --- | --- | --- |
| Business registry | US-IN | `inbiz.in.gov` | Manual review only | Indiana business-record search |
| Business registry | US-IN | `bsd.sos.in.gov` | Manual review only | Indiana Secretary of State business services |

Automation is false for both entries. No people-search, data-broker, social-media, address-history, school-roster, or juvenile-record source is allowed. `mort.test` is a synthetic sandbox school domain, not a public-data source or a real institution.

## Addition checklist

Confirm official ownership, lawful purpose, stable terms/interface, field minimization, jurisdiction, review process, correction/appeal route, expiry/recheck interval, public-display restrictions, and legal/privacy approval. Add through a reviewed migration or privileged audited operation; never from mobile/web input.
