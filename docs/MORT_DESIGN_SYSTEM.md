# MORT Design System

## Brand era: ROSE GOLD (canonical)

MORT's visual identity is rose-gold and light-blue on a dark, glassy
surface system. A same-night "Royal House" rebrand (Obsidian, Royal Blue,
Imperial Purple, Ruby, Antique Gold) briefly replaced this on 2026-08-20
and was reverted the same night after the owner saw it on a real device
and called it a mixed-color mess -- see
`docs/MORT_ROSE_GOLD_REDESIGN_REPORT.md` and
`docs/MORT_LIQUID_GLASS_UI_IMPLEMENTATION_REPORT.md` for the original,
still-canonical design work this system is built on.

## Colors

All colors live in `flutter_mort/lib/core/theme/mort_colors.dart` as
`MortColors` static constants. Reference the named constant, not a raw
hex literal, so palette changes cascade automatically.

| Token | Hex | Use |
|---|---|---|
| `bg` | `#0A0A0C` | Main app background |
| `bgSecondary` | `#101013` | Secondary background |
| `card` / `bgElevated` | `#17171A` | Cards, dialogs, elevated surfaces |
| `cardAlt` | `#222226` | Alternate elevated surface |
| `roseGold` | `#C89686` | Primary brand / CTA identity |
| `roseGoldLight` | `#F1CAB4` | Bright accent (medal/tier pills, headline accents) |
| `roseGoldDark` / `roseGoldMid` / `roseGoldDeep` | -- | Gradient stops, chip-selected state |
| `lightBlue` | `#7FC4EA` | Information, safety, location, verified state -- secondary to the rose-gold brand |
| `success` | `#33C48A` | Completed/verified/positive states |
| `warning` | `#FFC36A` | Warning states |
| `danger` | `#FF5A52` | Danger/error states |
| `premium` | `#C7A8FF` | Premium/paywall accents |
| `silver` | `#CBCED3` | Neutral secondary accent |
| `text` / `textSoft` / `textMuted` / `textDisabled` | -- | Text hierarchy |

`neon`/`neonDeep` are compatibility aliases for `roseGold`/`roseGoldDeep`
kept from an earlier redesign pass, for the same reason: existing screens
inherit palette changes without a second color language to maintain.

## Gradients (`mort_tokens.dart` -> `MortGradients`)

- `metallic` (primary): rose-gold family, 4-stop
- `background`: `bg -> bgSecondary -> #0C0B0E`
- `glass` / `infoGlass`: dark translucent surface gradients

## Shape

`MortRadii` (`mort_tokens.dart`): small 10, medium 14, card 20, sheet 28,
pill 999.

## Liquid glass -- real blur, not just translucency

`LiquidGlassContainer` (`core/widgets/mort_liquid_glass.dart`) supports
real backdrop blur (`liveBlur`, `ImageFilter.blur` at `MortGlassTokens.blurSigma
= 22.0`), gated by accessibility (`reducedTransparency`, high contrast)
and, on Android specifically, a second `allowAndroidBlur` flag --
`BackdropFilter` is expensive enough that it defaults off on Android
unless a surface explicitly opts in, to protect scroll performance on
lower-end hardware.

As of 2026-08-20, real blur is enabled (`allowAndroidBlur: true`) for the
three chrome surfaces that already requested it: `MortGlassHeader`,
`MortGlassNavigationBar`, and `MortGlassSheet` (bottom sheets/modals via
`MortGlassCard(blur: true)`). These render once per screen rather than
repeating inside a scrolling list, so real blur there doesn't risk the
jank `BackdropFilter` causes when instantiated many times at once.
`MortGlassCard` automatically passes `allowAndroidBlur: blur` through, so
any caller that opts into blur gets it for real on Android without a new
parameter -- scrolling card lists (job feed, messages, etc.) never
requested blur and remain flat translucency by design.

## Safety-critical rule

Safety overrides brand decoration. Emergency/danger controls, PIN entry,
and safety actions must remain immediately legible. Ads never appear on
Safety, Emergency, Report, Block, PIN, Identity, Evidence, Support, or
Account Deletion surfaces.
