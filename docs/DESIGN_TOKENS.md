# MORT — Design Tokens

**Version:** 1.0.0
**Status:** Source of Truth
**Owner:** CTO
**Last Updated:** 2025-06

---

## Table of Contents

1. [Design Principles](#1-design-principles)
2. [Color System](#2-color-system)
3. [Typography Scale](#3-typography-scale)
4. [Spacing Scale](#4-spacing-scale)
5. [Border Radius Scale](#5-border-radius-scale)
6. [Shadows & Elevation](#6-shadows--elevation)
7. [Iconography](#7-iconography)
8. [Motion System](#8-motion-system)
9. [Component Styling Rules](#9-component-styling-rules)
10. [Dark Mode Rules](#10-dark-mode-rules)
11. [Accessibility Requirements](#11-accessibility-requirements)
12. [Token File Structure](#12-token-file-structure)

---

## 1. Design Principles

| Principle | Implication |
|---|---|
| **Dark-first** | The app is designed in dark mode first. Light mode is a derived theme, not the default. |
| **Monochrome with one accent** | Black, white, and gray carry the UI. Color is reserved for status, XP, and active states only. |
| **Premium, not cluttered** | Generous whitespace, strong hierarchy, one primary action per screen. |
| **Fast and legible for teens** | Large tap targets, readable type at a glance, minimal cognitive load. |
| **Tokens over hardcoded values** | No raw hex codes, pixel values, or font sizes in widget code. Every value resolves from `theme/tokens.dart`. |
| **Consistency over novelty** | The component registry is the single source of visual truth. AI-generated screens must reuse registry components, not invent new styling patterns. |

---

## 2. Color System

### 2.1 Base Palette (Dark Theme — Default)

| Token | Hex | Usage |
|---|---|---|
| `color.background.primary` | `#0A0A0B` | App background, base canvas |
| `color.background.secondary` | `#121214` | Section backgrounds, alternating rows |
| `color.background.elevated` | `#1A1A1D` | Cards, sheets, modals |
| `color.background.overlay` | `#000000` @ 60% opacity | Modal scrims, dimming layers |
| `color.surface.card` | `#18181B` | `AppCard` default fill |
| `color.surface.cardHover` | `#202023` | Card pressed/hover state |
| `color.border.subtle` | `#2A2A2E` | Thin card borders, dividers |
| `color.border.default` | `#3A3A3F` | Input borders, default state |
| `color.border.focus` | `#5B8DEF` | Focused input border |
| `color.text.primary` | `#FFFFFF` | Headlines, primary content |
| `color.text.secondary` | `#A1A1AA` | Body copy, descriptions |
| `color.text.tertiary` | `#6B6B70` | Captions, timestamps, placeholders |
| `color.text.inverse` | `#0A0A0B` | Text on light/accent-filled surfaces |
| `color.text.disabled` | `#4B4B50` | Disabled labels |

### 2.2 Accent Colors

MORT uses **one primary accent** plus a small set of **status colors**. Accents are never used for large background fills — only for highlights, active states, badges, and small UI elements.

| Token | Hex | Usage |
|---|---|---|
| `color.accent.primary` | `#5B8DEF` | Primary buttons, links, focus states, active nav icon |
| `color.accent.xp` | `#A78BFA` | XP bar fill, level ring, XP badges (neon-leaning purple) |
| `color.accent.trust` | `#34D399` | Trust score ring (high trust), verified indicators |

### 2.3 Status Colors

| Token | Hex | Usage |
|---|---|---|
| `color.status.success` | `#22C55E` | Paid, confirmed, completed states |
| `color.status.warning` | `#F59E0B` | Pending, awaiting confirmation, service-fee-due |
| `color.status.danger` | `#EF4444` | Disputed, flagged, emergency, destructive actions |
| `color.status.info` | `#5B8DEF` | Informational badges, neutral pills |
| `color.status.neutral` | `#71717A` | Cancelled, expired, inactive states |

### 2.4 Trust Tier Colors

| Tier | Token | Hex | Score Range |
|---|---|---|---|
| Newcomer | `color.trust.newcomer` | `#71717A` | 0–39 |
| Reliable | `color.trust.reliable` | `#5B8DEF` | 40–64 |
| Trusted | `color.trust.trusted` | `#34D399` | 65–84 |
| Top Hustler | `color.trust.topHustler` | `#A78BFA` | 85–100 |

### 2.5 Semantic Job Status Colors

| Job Status | Token | Hex |
|---|---|---|
| `open` | `color.jobStatus.open` | `#5B8DEF` |
| `reserved` | `color.jobStatus.reserved` | `#F59E0B` |
| `active` | `color.jobStatus.active` | `#A78BFA` |
| `awaiting_proof` | `color.jobStatus.awaitingProof` | `#F59E0B` |
| `awaiting_adult_confirmation` | `color.jobStatus.awaitingConfirmation` | `#F59E0B` |
| `paid` | `color.jobStatus.paid` | `#22C55E` |
| `disputed` | `color.jobStatus.disputed` | `#EF4444` |
| `cancelled` | `color.jobStatus.cancelled` | `#71717A` |
| `flagged` | `color.jobStatus.flagged` | `#EF4444` |
| `expired` | `color.jobStatus.expired` | `#4B4B50` |

### 2.6 Gradients

| Token | Definition | Usage |
|---|---|---|
| `gradient.heroDark` | `linear-gradient(180deg, #121214 0%, #0A0A0B 100%)` | Welcome screen, hero banners |
| `gradient.xpGlow` | `radial-gradient(circle, #A78BFA 0%, transparent 70%)` | XP level-up animation glow |
| `gradient.cardSheen` | `linear-gradient(135deg, #1A1A1D 0%, #18181B 100%)` | Subtle card depth on elevated surfaces |
| `gradient.emergencyPulse` | `radial-gradient(circle, #EF4444 0%, #7F1D1D 100%)` | Emergency screen background pulse |

### 2.7 Color Usage Rules

- Never use `color.accent.primary` for large background fills — buttons, links, and small highlights only.
- `color.accent.xp` and `color.accent.trust` are reserved exclusively for XP/level and trust-related UI. Do not reuse for unrelated decorative purposes.
- Status colors map 1:1 to their semantic meaning across the entire app. `color.status.danger` always means destructive, disputed, or emergency — never decorative.
- Minimum two background layers must be visible in any nested card stack (`background.primary` → `surface.card` → nested `background.elevated`) to maintain depth without relying on shadows alone.

---

## 3. Typography Scale

### 3.1 Font Family

| Token | Value | Usage |
|---|---|---|
| `font.family.primary` | `Inter` (system fallback: `-apple-system, Roboto, sans-serif`) | All UI text |
| `font.family.mono` | `Roboto Mono` (system fallback: `monospace`) | Earnings figures, IDs, timestamps in detail views |

Inter is used for its strong legibility at small sizes on mobile and broad weight range, appropriate for a teen-facing, fast-reading interface.

### 3.2 Type Scale

| Token | Size (sp) | Line Height | Weight | Usage |
|---|---|---|---|---|
| `text.display` | 32 | 40 | 700 (Bold) | Hero headlines (Welcome, Recap) |
| `text.h1` | 28 | 36 | 700 (Bold) | Screen titles |
| `text.h2` | 22 | 28 | 600 (SemiBold) | Section headers |
| `text.h3` | 18 | 24 | 600 (SemiBold) | Card titles, sub-section headers |
| `text.bodyLarge` | 16 | 24 | 400 (Regular) | Primary body copy, job descriptions |
| `text.body` | 14 | 20 | 400 (Regular) | Default body copy, list items |
| `text.bodyEmphasis` | 14 | 20 | 600 (SemiBold) | Emphasized inline text, labels |
| `text.caption` | 12 | 16 | 400 (Regular) | Timestamps, helper text, metadata |
| `text.captionEmphasis` | 12 | 16 | 600 (SemiBold) | Status pill text, tags |
| `text.button` | 16 | 20 | 600 (SemiBold) | Button labels |
| `text.buttonSmall` | 14 | 18 | 600 (SemiBold) | Secondary/compact button labels |
| `text.overline` | 11 | 14 | 700 (Bold), uppercase, 0.5px letter-spacing | Section eyebrows, badges |

### 3.3 Minimum Sizes (Accessibility Floor)

- Body text must never render below **14sp**.
- Primary CTA button text must never render below **16sp**.
- No text token in the scale goes below `text.caption` (12sp); 12sp is reserved for non-critical metadata only and never used for actionable text.

### 3.4 Typography Usage Rules

- One `text.h1` per screen maximum — it is the screen title.
- Job prices always render in `text.h2` or larger with `font.family.mono` for digit alignment.
- Never use more than 3 type tokens on a single card component.
- Truncate with ellipsis at 2 lines for descriptions in card contexts; full text only on detail screens.

---

## 4. Spacing Scale

MORT uses a **4px base unit** spacing system. All padding, margin, and gap values resolve from this scale — no arbitrary pixel values in widget code.

| Token | Value (px) | Usage |
|---|---|---|
| `space.0` | 0 | Reset/no spacing |
| `space.1` | 4 | Icon-to-text gaps, tight inline spacing |
| `space.2` | 8 | Chip padding, small gaps between related elements |
| `space.3` | 12 | Default internal card padding (compact) |
| `space.4` | 16 | Standard internal padding, default gap between cards |
| `space.5` | 20 | Section internal padding |
| `space.6` | 24 | Standard screen horizontal margin |
| `space.8` | 32 | Section-to-section vertical spacing |
| `space.10` | 40 | Large section breaks |
| `space.12` | 48 | Hero spacing, empty state vertical padding |
| `space.16` | 64 | Maximum spacing — onboarding hero, full-screen empty states |

### 4.1 Layout Rules

- Screen horizontal margins: `space.6` (24px) on all standard screens.
- Card internal padding: `space.4` (16px) default, `space.3` (12px) for compact list cards (e.g. `EarningsTile`).
- Gap between stacked cards in a list: `space.3` (12px).
- Gap between a section header and its content: `space.4` (16px).
- Bottom safe-area padding on scrollable screens: `space.8` (32px) minimum above the bottom navigation bar or keyboard.
- Fixed bottom action bars (e.g. Emergency button, primary CTA bar): `space.4` (16px) padding on all sides, with `space.2` (8px) extra bottom padding to clear device safe-area insets.

---

## 5. Border Radius Scale

| Token | Value (px) | Usage |
|---|---|---|
| `radius.none` | 0 | Full-bleed images, edge-to-edge media |
| `radius.sm` | 8 | Chips, tags, small badges |
| `radius.md` | 12 | Default card radius, input fields |
| `radius.lg` | 16 | Elevated cards, modals, bottom sheets (top corners) |
| `radius.xl` | 24 | Hero cards, large feature cards (Weekly Recap) |
| `radius.full` | 9999 | Avatars, circular buttons, pills, `StatusPill`, FAB |

### 5.1 Radius Usage Rules

- `JobCard`, `AppCard`, `FeedPostCard` use `radius.md` (12px) by default.
- Bottom sheets (`Accept Job Modal`, `Report Sheet`, `Block Confirmation`) use `radius.lg` (16px) on top corners only, `radius.none` on bottom corners.
- All pills, badges, and tags (`StatusPill`, `TrustBadge`, `PayMethodTag`, `DistanceTag`) use `radius.full`.
- Avatars are always `radius.full`, regardless of size.
- Buttons use `radius.md` (12px), except FABs which use `radius.full`.

---

## 6. Shadows & Elevation

Because the UI is dark-first, shadows are subtle and primarily used to separate elevated surfaces (modals, sheets) from the base canvas rather than to simulate strong directional light. Borders (`color.border.subtle`) do more visual separation work than shadows in this system.

| Token | Definition | Usage |
|---|---|---|
| `shadow.none` | `none` | Flat surfaces, base cards on background |
| `shadow.xs` | `0px 1px 2px rgba(0,0,0,0.4)` | Subtle lift — list rows, chips on hover/press |
| `shadow.sm` | `0px 2px 8px rgba(0,0,0,0.45)` | Default elevated `AppCard`, `JobCard` |
| `shadow.md` | `0px 4px 16px rgba(0,0,0,0.5)` | Floating action buttons, dropdown menus |
| `shadow.lg` | `0px 8px 32px rgba(0,0,0,0.55)` | Modals, bottom sheets |
| `shadow.xl` | `0px 16px 48px rgba(0,0,0,0.6)` | Full-screen overlays (Emergency screen container, if elevated above base) |
| `shadow.glow.xp` | `0px 0px 24px rgba(167,139,250,0.5)` | XP level-up burst, active XP bar glow |
| `shadow.glow.danger` | `0px 0px 24px rgba(239,68,68,0.5)` | Emergency button pulse, critical alert emphasis |

### 6.1 Elevation Layering Order

```
z.base        = 0   → screen background
z.card        = 10  → AppCard, JobCard, FeedPostCard
z.stickyBar   = 20  → bottom action bars, sticky filter bars
z.navigation  = 30  → bottom navigation bar, app bar
z.dropdown    = 40  → dropdown menus, popovers
z.modal       = 50  → bottom sheets, Accept Job Modal, Report Sheet
z.overlay     = 60  → SafetyPingModal (non-dismissable overlay)
z.emergency   = 70  → Emergency screen (always renders above everything, including modals)
z.toast       = 80  → toast notifications (render above all, including emergency, since they may carry critical save-state feedback)
```

---

## 7. Iconography

### 7.1 Icon Library

MORT uses a single consistent icon set across the app — **Lucide Icons** (`lucide-react` in web/admin contexts via `lucide-react@0.383.0`; Flutter client uses the equivalent stroke-style icon set bundled as SVG assets matching Lucide's visual language) for consistent stroke weight and visual tone.

### 7.2 Icon Sizing

| Token | Size (px) | Usage |
|---|---|---|
| `icon.size.xs` | 12 | Inline icons within caption text |
| `icon.size.sm` | 16 | Inline icons within body text, chip icons |
| `icon.size.md` | 20 | Default icon size — list rows, input fields, buttons |
| `icon.size.lg` | 24 | App bar icons, navigation icons |
| `icon.size.xl` | 32 | Empty state illustrations (simple icon-based), FAB icons |
| `icon.size.hero` | 48 | Onboarding step icons, large status icons |

### 7.3 Icon Style Rules

- Stroke width: `1.5px` at all sizes for consistency (Lucide default).
- Icons are never filled solid except for: active/selected state in bottom navigation, and small status dots.
- Icon color always resolves from a text or status token — never a hardcoded color.
- Default icon color: `color.text.secondary`. Active/selected state: `color.accent.primary`. Destructive actions: `color.status.danger`.

### 7.4 Standard Icon Mapping

| Concept | Icon |
|---|---|
| Job / briefcase | `briefcase` |
| Earnings / wallet | `wallet` |
| Goals | `target` |
| Trust / shield | `shield-check` |
| XP / star | `star` or `zap` |
| Messages | `message-circle` |
| Groups | `users` |
| Notifications | `bell` |
| Settings | `settings` |
| Safety / emergency | `shield-alert` (standard), `alert-triangle` (emergency) |
| Verified | `badge-check` |
| Location / distance | `map-pin` |
| Camera / proof upload | `camera` |
| Report | `flag` |
| Block | `slash` |

---

## 8. Motion System

### 8.1 Motion Principles

- Motion is used sparingly, per UI generation rules in the build spec: motion confirms state changes and guides attention, never decorates.
- All animations are native Flutter animations (no heavy third-party animation libraries) tuned for low-end Android performance.
- Reduce-motion system setting must be respected — when enabled, all non-essential animations (XP bursts, page transitions beyond fade, card hover effects) are disabled or reduced to instant/opacity-only transitions.

### 8.2 Duration Tokens

| Token | Value (ms) | Usage |
|---|---|---|
| `motion.duration.instant` | 100 | Button press feedback, toggle switches |
| `motion.duration.fast` | 150 | Chip selection, tab switches |
| `motion.duration.default` | 250 | Page transitions, modal open/close, card expand |
| `motion.duration.slow` | 400 | Bottom sheet slide-up, XP bar fill animation |
| `motion.duration.celebratory` | 600 | XP level-up burst, goal-completed confetti, job completion receipt animation |

### 8.3 Easing Curves

| Token | Curve | Usage |
|---|---|---|
| `motion.easing.standard` | `cubic-bezier(0.4, 0.0, 0.2, 1)` | Default for most transitions |
| `motion.easing.decelerate` | `cubic-bezier(0.0, 0.0, 0.2, 1)` | Elements entering the screen (modals, sheets) |
| `motion.easing.accelerate` | `cubic-bezier(0.4, 0.0, 1, 1)` | Elements exiting the screen |
| `motion.easing.bounce` | `cubic-bezier(0.34, 1.56, 0.64, 1)` | XP bar fill, celebratory micro-interactions only |

### 8.4 Standard Motion Patterns

| Pattern | Definition |
|---|---|
| **Page transition** | Slide-from-right + fade, `motion.duration.default`, `motion.easing.standard` |
| **Modal / bottom sheet open** | Slide-up from bottom, `motion.duration.slow`, `motion.easing.decelerate` |
| **Modal / bottom sheet close** | Slide-down, `motion.duration.default`, `motion.easing.accelerate` |
| **Button press** | Scale to 0.97, `motion.duration.instant`, `motion.easing.standard` |
| **Card tap** | Scale to 0.98 + subtle opacity dip, `motion.duration.instant` |
| **XP bar fill** | Width animate, `motion.duration.slow`, `motion.easing.bounce` |
| **Toast entry/exit** | Slide-down from top + fade, `motion.duration.fast` |
| **SafetyPingModal entry** | Fade + scale from 0.95, `motion.duration.fast`, no decorative delay — safety UI must appear instantly |
| **Skeleton shimmer** | Continuous gradient sweep, 1200ms loop, linear easing |
| **Emergency screen entry** | Instant — no transition animation. Renders immediately with zero delay. |

### 8.5 Motion Restrictions

- The Emergency screen and SafetyPingModal never use decorative entrance animations beyond a minimal fade — speed of access overrides visual polish in safety-critical flows.
- No animation may block user interaction for longer than `motion.duration.slow` (400ms).
- Looping/ambient animations (e.g. XP glow pulse) must be GPU-friendly and capped at low frame-impact to preserve performance on low-end Android devices, per the architecture's performance constraints.

---

## 9. Component Styling Rules

This section defines the visual contract for each component in the registry. All components consume tokens defined above — no component may declare a raw color, size, or spacing value outside this token set.

### 9.1 AppButton

| Variant | Background | Text Color | Border | Radius | Height |
|---|---|---|---|---|---|
| Primary | `color.accent.primary` | `color.text.inverse` | none | `radius.md` | 52px |
| Secondary | `color.background.elevated` | `color.text.primary` | `1px color.border.default` | `radius.md` | 52px |
| Tertiary / Text | transparent | `color.accent.primary` | none | n/a | 44px |
| Destructive | `color.status.danger` | `color.text.primary` | none | `radius.md` | 52px |
| Disabled | `color.background.elevated` | `color.text.disabled` | `1px color.border.subtle` | `radius.md` | 52px |

- Minimum tap target: 44x44px (52px height satisfies this with margin).
- Full-width by default on mobile screens unless explicitly paired (e.g. Cancel/Confirm side-by-side).
- Press state: scale to 0.97 + background darken 8%.

### 9.2 AppCard

- Background: `color.surface.card`
- Border: `1px color.border.subtle`
- Radius: `radius.md`
- Padding: `space.4`
- Shadow: `shadow.sm`
- Pressed state (if tappable): background shifts to `color.surface.cardHover`, scale to 0.98

### 9.3 JobCard

- Inherits `AppCard` base styling
- Price rendered in `text.h3`, `font.family.mono`, `color.text.primary`
- `DistanceTag` and `PayMethodTag` anchored top-right
- `TrustBadge` for poster anchored bottom-left
- Max 2 lines for title (`text.bodyEmphasis`), ellipsis truncation
- Image/thumbnail (if present): `radius.sm`, 64x64px, left-anchored

### 9.4 TrustBadge

- Pill shape (`radius.full`)
- Background: trust tier color at 15% opacity
- Text/icon: full-opacity trust tier color
- Padding: `space.2` horizontal, `space.1` vertical
- Icon: `shield-check` at `icon.size.sm`
- Text: `text.captionEmphasis`

### 9.5 XPBar

- Track background: `color.background.elevated`
- Fill: `gradient` using `color.accent.xp` with `shadow.glow.xp` on the leading edge when actively filling
- Height: 8px
- Radius: `radius.full`
- Label (current/next level XP): `text.caption`, `color.text.tertiary`, positioned above the bar

### 9.6 LevelRing

- Circular progress indicator, 4px stroke
- Track: `color.background.elevated`
- Progress: `color.accent.xp`
- Center content: level number in `text.h2`, `font.family.mono`

### 9.7 EarningsTile

- Compact card variant: padding `space.3` instead of `space.4`
- Amount rendered `text.bodyEmphasis`, `font.family.mono`, color resolves from `payout_status` (paid = `color.status.success`, pending = `color.status.warning`, disputed = `color.status.danger`)
- `StatusPill` anchored right
- Divider below each tile: `1px color.border.subtle`, no card shadow (flat list row, not individually elevated)

### 9.8 GoalProgress

- Card variant with `radius.lg`
- Icon displayed at `icon.size.xl` or emoji equivalent, top-left
- Progress bar: same visual treatment as `XPBar` but uses `color.accent.primary` fill, not `color.accent.xp`
- Amount text: `text.h3`, `font.family.mono` ("$42 / $100")
- Pinned indicator: small pin icon, `color.text.tertiary`, top-right corner

### 9.9 SafetyPingModal

- Full-screen overlay, `color.background.overlay` backdrop at 85% opacity (darker than standard modal scrim — this is intentionally more opaque to focus attention)
- Content card: `color.background.elevated`, `radius.lg`, centered, `shadow.xl`
- Icon: `icon.size.hero`, `color.accent.trust` for the shield icon
- "I Need Help" button always uses Destructive `AppButton` variant
- No dismiss gesture (no tap-outside-to-close, no swipe-to-dismiss)

### 9.10 ChatBubble

- Sent (own messages): `color.accent.primary` background, `color.text.inverse` text, right-aligned, `radius.lg` with bottom-right corner reduced to `radius.sm`
- Received: `color.surface.card` background, `color.text.primary` text, left-aligned, `radius.lg` with bottom-left corner reduced to `radius.sm`
- Removed/flagged messages: `color.background.elevated` background, `color.text.tertiary` italic text, no tail corner adjustment
- Timestamp: `text.caption`, `color.text.tertiary`, below bubble
- Max width: 80% of screen width

### 9.11 FeedPostCard

- Inherits `AppCard` base
- Media (if present): full-bleed within card, `radius.sm` top corners only if text content follows below
- Post type badge: small pill, top-left over media or above content, uses `color.accent.xp` background at 15% opacity for "Hustle Win" / "Milestone" types
- Sponsored variant: identical layout + small "Sponsored" `text.overline` label, `color.text.tertiary`, top-right

### 9.12 VerifiedBadge

- Small icon-only badge: `badge-check` icon at `icon.size.sm`
- Color: `color.accent.trust`
- Positioned as an overlay on the bottom-right of an avatar, with a 2px `color.background.primary` ring to separate it from the avatar image

### 9.13 StatusPill

- Pill shape (`radius.full`)
- Background: status color at 15% opacity
- Text: status color at full opacity, `text.captionEmphasis`
- Padding: `space.2` horizontal, `space.1` vertical
- Color resolves from the relevant status enum (job status, payout status, moderation status, etc.) per the mappings in Section 2.5

### 9.14 EmptyState

- Centered vertically and horizontally within available space
- Illustration or icon: `icon.size.hero`, `color.text.tertiary`
- Headline: `text.h3`, `color.text.primary`
- Subtext: `text.body`, `color.text.secondary`
- Optional `AppButton` (Secondary variant) below subtext, `space.4` gap
- Vertical padding: `space.12`

### 9.15 SkeletonLoader

- Background: `color.background.elevated`
- Shimmer gradient: `color.surface.cardHover` sweeping at 1200ms loop (see Motion System 8.4)
- Matches the exact dimensions and radius of the component it is replacing (e.g. `JobCard` skeleton matches `JobCard` height and `radius.md`)

### 9.16 ProfileHeader

- Avatar: `radius.full`, sizes vary by context (48px in app bar, 96px on profile screen)
- Display name: `text.h2`
- Handle: `text.body`, `color.text.secondary`, prefixed with `@`
- Level badge: small `LevelRing` variant (32px) anchored bottom-right of avatar on profile screen context

### 9.17 DistanceTag / PayMethodTag / SavedHustleChip

- All three share the **chip** base style: `radius.sm`, `color.background.elevated` background, `1px color.border.subtle`, `space.2` horizontal padding, `space.1` vertical padding, `text.caption`
- Icon (if present) at `icon.size.xs`, `space.1` gap from text

### 9.18 ReviewStars

- 5-star row, filled stars use `color.accent.xp`, empty stars use `color.border.default`
- Star icon size: `icon.size.sm` in list/card contexts, `icon.size.md` on dedicated review/profile screens
- Numeric average displayed adjacent in `text.bodyEmphasis`, `font.family.mono`

### 9.19 ReportSheet / BlockConfirmation

- Both are bottom sheet overlays: `color.background.elevated`, `radius.lg` (top corners only), `shadow.lg`
- Drag handle indicator at top: 32x4px bar, `color.border.default`, `radius.full`
- Destructive primary action always uses Destructive `AppButton` variant

### 9.20 BottomActionBar

- Fixed to bottom of screen, `z.stickyBar`
- Background: `color.background.elevated` with `1px color.border.subtle` top border
- Padding: `space.4` all sides + safe-area inset
- Used for: primary CTA bars (Accept button context), Emergency button container

---

## 10. Dark Mode Rules

### 10.1 Dark Mode Is the Default

MORT ships dark-first. The base token values defined in Section 2 **are** the dark theme. There is no separate "enable dark mode" decision to make at the token level — dark is the baseline experience.

### 10.2 Light Mode (Secondary Theme)

A light theme is supported as a system-preference-following or user-toggleable alternative, generated by inverting the neutral scale while **preserving all accent, status, and trust colors unchanged** (these are tuned to work on both backgrounds).

| Token | Dark Value | Light Value |
|---|---|---|
| `color.background.primary` | `#0A0A0B` | `#FAFAFA` |
| `color.background.secondary` | `#121214` | `#F2F2F3` |
| `color.background.elevated` | `#1A1A1D` | `#FFFFFF` |
| `color.surface.card` | `#18181B` | `#FFFFFF` |
| `color.border.subtle` | `#2A2A2E` | `#E4E4E7` |
| `color.border.default` | `#3A3A3F` | `#D4D4D8` |
| `color.text.primary` | `#FFFFFF` | `#0A0A0B` |
| `color.text.secondary` | `#A1A1AA` | `#52525B` |
| `color.text.tertiary` | `#6B6B70` | `#71717A` |
| `color.text.inverse` | `#0A0A0B` | `#FFFFFF` |

Accent (`color.accent.*`), status (`color.status.*`), trust tier (`color.trust.*`), and job status (`color.jobStatus.*`) tokens remain **identical** in both themes — only neutrals and surfaces invert. This keeps status meaning consistent regardless of theme.

### 10.3 Shadow Adjustment in Light Mode

Shadows must be adjusted for light mode since dark-mode shadow opacities (designed against a near-black canvas) read as too harsh on light backgrounds.

| Token | Dark Mode | Light Mode |
|---|---|---|
| `shadow.sm` | `0px 2px 8px rgba(0,0,0,0.45)` | `0px 2px 8px rgba(0,0,0,0.08)` |
| `shadow.md` | `0px 4px 16px rgba(0,0,0,0.5)` | `0px 4px 16px rgba(0,0,0,0.10)` |
| `shadow.lg` | `0px 8px 32px rgba(0,0,0,0.55)` | `0px 8px 32px rgba(0,0,0,0.12)` |

Glow shadows (`shadow.glow.xp`, `shadow.glow.danger`) remain unchanged in both themes — they are accent-driven, not ambient.

### 10.4 Implementation Rule

Theming is implemented via a single `AppTheme` resolver in `theme/app_theme.dart` that reads a `Brightness` value and returns the appropriate token set. **No widget ever branches on `Theme.of(context).brightness` directly** — widgets only ever consume semantic tokens (e.g. `tokens.background.primary`), and the token resolver handles the brightness switch centrally. This guarantees no screen can drift out of sync with a theme change.

### 10.5 Default Behavior

- App defaults to dark mode on first launch regardless of system setting.
- A toggle in Settings allows: Dark (default), Light, System.
- Theme preference is persisted locally (not synced server-side — it's a device-level UI preference, not user data).

---

## 11. Accessibility Requirements

These requirements are binding minimums, not aspirational targets, per the Non-Functional Requirements in PRD.md Section 6.5.

### 11.1 Contrast Ratios

| Context | Minimum Ratio (WCAG) |
|---|---|
| Body text on background | 4.5:1 (AA) |
| Large text (`text.h1`–`text.h3`, 18sp+ bold or 24sp+ regular) | 3:1 (AA) |
| Interactive element borders / focus indicators | 3:1 (AA) |
| Status pill text on its 15%-opacity background | 4.5:1 (verified per status color against `color.background.primary` and against `color.background.elevated` for light mode) |

All token color pairs in Section 2 and Section 10 have been selected to clear these minimums against their intended backgrounds. Any new color introduced to the system must be contrast-checked against both dark and light backgrounds before being added to the token file.

### 11.2 Tap Targets

- Minimum tap target size: **44x44px**, per platform HIG/Material guidance, matching the Non-Functional Requirements baseline.
- This applies to all interactive elements: buttons, icon buttons, chips with tap actions, list rows, checkboxes, and the Emergency button (which exceeds minimum at 52px+ height).
- Adequate spacing (`space.2` minimum) between adjacent tap targets to prevent mis-taps — critical in dense screens like the Active Job check-in timeline.

### 11.3 Typography Floor

- No actionable text renders below 14sp (`text.body`), per Section 3.3.
- Users can increase system font scaling up to 130% without the layout breaking; components must use flexible/wrap layouts rather than fixed-height text containers wherever body or button text appears.

### 11.4 Screen Reader Support

- Every interactive element has a semantic label (Flutter `Semantics` widget or equivalent `semanticLabel` property) — icon-only buttons (e.g. Report flag icon, kebab menus) are never left unlabeled.
- `StatusPill`, `TrustBadge`, and `VerifiedBadge` expose their meaning as text to screen readers, not just color (e.g. a trust badge announces "Trusted, 72 trust score," not just a green dot).
- Images uploaded as job proof include an auto-generated or default alt description ("Before photo of completed job") for screen reader users reviewing job history.
- The Emergency screen's primary actions are the first focusable elements when the screen mounts, ensuring immediate screen-reader access in a crisis.

### 11.5 Color-Independent Meaning

No state in MORT is communicated by color alone:

- Job status: color + text label (`StatusPill` always renders text, never a bare color dot).
- Trust tier: color + tier name + numeric score.
- Message delivery/moderation state: color + icon + (where applicable) text ("This message was removed").
- Form validation errors: color + icon + inline error text, never a red border alone.

### 11.6 Motion & Reduced Motion

- All decorative or celebratory animations (XP bursts, confetti, glow pulses) must check the platform's reduce-motion accessibility setting and substitute a static or opacity-only equivalent when enabled, per Section 8.1.
- Essential state-change animations (e.g. screen transitions) may remain but should shorten toward `motion.duration.fast` when reduce-motion is active, rather than removing wayfinding feedback entirely.

### 11.7 Safety-Critical Accessibility

- The Emergency screen and SafetyPingModal are held to a higher accessibility bar than the rest of the app: all primary actions use Destructive/Primary `AppButton` styling at maximum tap-target size, high-contrast text, and are reachable without any scrolling on standard device sizes (iPhone SE class and up).
- "Call 911" must work correctly with screen readers, voice control, and switch-access input methods, since this is the single most safety-critical interaction in the product.

---

## 12. Token File Structure

All tokens defined in this document map 1:1 to a single Dart source file, per the Flutter App Architecture in ARCHITECTURE.md Section 3.

```
lib/theme/
├── tokens.dart          # All raw token values (colors, spacing, radii, shadows, durations)
├── text_styles.dart      # Resolved TextStyle objects per type scale token
├── app_theme.dart         # ThemeData construction; brightness-aware token resolution
└── shadows.dart           # BoxShadow / Elevation helper construction from shadow tokens
```

### 12.1 Naming Convention

Tokens use **dot notation in documentation** (e.g. `color.accent.primary`) which maps to **camelCase nested static access in Dart** (e.g. `AppTokens.color.accent.primary` or flattened `AppColors.accentPrimary`, per team convention — flattened static const fields are preferred in Dart for compile-time constant performance).

### 12.2 No Inline Values Rule

This is a hard rule enforced in code review and, where feasible, lint rules:

- No widget file may contain a raw `Color(0x...)`, raw `EdgeInsets.all(<number>)` with a magic number, or raw `BorderRadius.circular(<number>)`.
- All such values resolve from `AppTokens` / `AppColors` / `AppSpacing` / `AppRadius` constants defined in `theme/tokens.dart`.
- This rule exists specifically to keep the AI code-generation system (Section 19 of the build spec) consistent — every AI-generated screen pulls from the same finite token set rather than inventing new values per screen.

---

*This document is the source of truth for all MORT design tokens. Any new color, spacing value, type style, or component visual pattern must be added here before use in implementation. The component registry referenced throughout this document is implemented per the screen specifications in SCREEN_SPECS.md.*
