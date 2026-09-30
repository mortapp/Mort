# MORT classic UI design system

Source of truth: the existing Flutter `MortColors`, `MortTheme`, spacing, typography, motion, and shared `Mort*` components. This document describes their target state for the isolated redesign branch; code and screenshot evidence will be recorded as each phase lands.

| Token | Target |
| --- | --- |
| Primary background | `#FFFFFF` |
| Secondary surface | `#F7F7F7` |
| Subtle raised surface | `#FAFAFA` |
| Primary text / black CTA | `#111111` |
| Secondary text | approximately `#6A6A6A` |
| Hairline | very light neutral gray |
| Danger | restrained red, only for emergency/destructive/error meaning |
| Warning | amber |
| Success | green |
| Information/link | blue only where semantic |

Primary buttons have black fill, white text, minimum 52 logical pixel height, 12–14 pixel radius, and visible loading/disabled states. Secondary buttons are white or neutral with a subtle border. Cards are white with one hairline or nearly invisible shadow, 12–16 pixel radius. Inputs have white fill, neutral border, black focus border, clear labels/errors, correct keyboard, and minimum 52 pixel height. Screen titles are large and readable; content has a single obvious primary action.

The bottom bar is white, safe-area aware, with a top hairline. Inactive icons and labels are neutral gray. The active item uses black icon/label and a small light pill with a soft shadow (`0,2`, blur around `8–12`, roughly 8–10% black opacity). It must not glow or scale dramatically. Teen/adult destinations are Home, Jobs, Messages, Safety, Profile; guardian destinations are Home, Safety, Messages, Profile. A selected tab remains selected through back/deep-link navigation where the existing router permits.

Motion communicates state: approximately 150–250 ms transitions, short fades/sheets, and subtle press/selection feedback. `MediaQuery.disableAnimationsOf` suppresses nonessential motion. Safety, evidence, Verify, dispute, critical moderation, and account deletion surfaces have no ads, Pro upsell, companion overlays, or progression pressure.

Use a full-screen selector for large searchable sets, a bottom sheet for quick contextual choices, and a dialog for confirmation. Keep copy short and calm. Every action has screen-reader labeling, at least 48 logical pixel targets, large-text layout, keyboard-safe placement, and a useful empty/loading/error state. Store prices always come from RevenueCat/Google Play; no client amount controls billing.

## Reconciliation checklist

- Replace production atmospheric scaffold and glass card/bar with structural surfaces while preserving safe-area and back behavior.
- Consolidate duplicate navigation and button/input patterns into the existing component family.
- Preserve semantic colors and every route guard; inspect dark hardcoded colors before declaring each screen migrated.
- Record screenshots/goldens and mark each route in `MORT_CLASSIC_UI_SCREEN_INVENTORY.md` only after its behavior and visual review pass.
