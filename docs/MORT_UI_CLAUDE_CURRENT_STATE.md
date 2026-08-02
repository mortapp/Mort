# MORT UI Claude — Current State

Last updated: 2026-07-30 (`00_UI_RESUME_CONTROLLER.md` run)

## Status

UI micro-pass track initialized. Zero UI prompts executed beyond the resume
controller itself. No visual/theme work has started.

## Visual Direction (from 00_UI_RESUME_CONTROLLER.md, not yet applied)

Target: premium dark rose-gold, iOS-inspired liquid-glass, retaining MORT
branding. Palette, motion, and accessibility rules are fully specified in the
controller file and remain the source of truth until superseded by
`01_UI_INVENTORY_AND_TOKENS.md` output.

## What Exists Today

Unaudited by this track. `01_UI_INVENTORY_AND_TOKENS.md` is expected to
perform the first inventory of current screens, components, and design
tokens before any visual changes begin.

## What Does Not Exist Yet

- No design token file/theme extension confirmed in place.
- No confirmed rose-gold palette applied to any screen.
- No golden tests, widget tests, or navigation tests specific to the new UI
  direction.

## Regression Locks Inherited (protect these, not owned by this track)

- Flutter: 256 passed, 2 expected skips, 0 failed (Supreme baseline).
- Do not reopen payment architecture (Supreme Phase 12 complete).
- Do not enable payments, payouts, service fees, identity verification,
  external AI, remote push, crash reporting, ads, IAP, or the public
  marketplace.
- Do not change Supabase schemas, migrations, RLS, Edge Functions, financial
  logic, identity logic, authentication behavior, or chatbot behavior from
  this track.
