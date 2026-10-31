# MORT Mobile UI/UX Implementation Notes

## Intent

The canonical product requirements are copied into [the 2026-10-12 mobile UI/UX specification](../specs/2026-10-12-mort-mobile-ui-ux-design.md). The [implementation roadmap](../plans/2026-10-12-mort-uiux-program-roadmap.md) is retained as supplied design context. The visual preview under `build/ui-preview` is supporting evidence, not the source of truth.

This checkout's release app is the Flutter project under `flutter_mort` (see the repository's current release configuration and README). The attached roadmap describes Expo as its active stack; that statement does not match this checkout. Apply the approved product and visual requirements to the active Flutter release app without reviving the legacy Expo reference client.

The target surface is the restrained monochrome design in the canonical spec: off-white and white in light mode, near-black and charcoal in dark mode, fine neutral borders, black/white primary actions, and muted gray secondary text. Remove decorative star/space artwork and glass/gradient treatments from ordinary app surfaces. Preserve semantic status colors and functional rating stars.

## Goals

- Keep light mode primary and dark mode fully supported.
- Remove decorative star fields, constellations, aurora, and meteor effects from normal app surfaces, including startup and legacy scaffold surfaces.
- Use flat, theme-aware shared cards and actions so the app follows the same visual language across roles and feature areas.
- Preserve canonical teen (`Home · Explore · Inbox · Profile`) and adult/business (`Home · Explore · + · Inbox · Profile`) navigation.
- Keep Home jobs-first and reserve search for Explore.
- Preserve existing screen content, routes, accessibility preferences, role checks, backend gates, and safety copy.
- Keep the supplied preview images unchanged as examples; use the canonical specification for requirements.

## Non-goals and constraints

- Do not copy the preview's synthetic job data or its disabled-write mock behavior into production code.
- Do not change marketplace, job publishing, payment, identity, or document-collection controls.
- Keep functional rating stars and other safety/verification icons; remove only decorative space/star artwork.
- Preserve the optional flat dark appearance setting while removing its atmospheric artwork.

## Implementation choice

Retain existing routes, role checks, user workflows, and safety behavior. Use the shared Flutter theme as the source of colors, flatten shared card/action components in both themes, and keep the atmosphere renderer unreachable from normal composition and app navigation.

## Validation

Check focused static analysis and build the signed closed-test AAB with the existing release profile and safety gates. This implementation record does not claim every flow in the much broader product specification is complete; remaining feature work follows the roadmap's dependency order.
