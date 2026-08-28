# MORT Design System

## Brand era: ROSE GOLD 2.0 (canonical, current)

MORT's visual identity is **God Black, metallic Rose Gold, God White,
Silver, Baby Blue, Success Green, and God Pink** (a rare signature
accent) on a dark, glassy surface system. This is the second rose-gold
pass -- the original, simpler rose-gold/light-blue system described
lower in this doc's history was superseded on 2026-08-20 by this
richer palette at the owner's direction, refined once more the same
day ("God Black must dominate," a genuinely metallic gradient instead
of a flat fill, God White for wordmark/typography), and the black
surface family was darkened one further notch shortly after. A
same-night "Royal House" rebrand (Obsidian, Royal Blue, Imperial
Purple, Ruby, Antique Gold) also briefly replaced rose-gold entirely
and was reverted within the same session after the owner saw it on a
real device and rejected it -- no trace of it remains in `lib/`.

## Colors

All colors live in `flutter_mort/lib/core/theme/mort_colors.dart` as
`MortColors` static constants. Reference the named constant, not a raw
hex literal, so palette changes cascade automatically through the
shared widget layer (`mort_widgets.dart`, `mort_liquid_glass.dart`,
`mort_design_components.dart`) to every screen without per-screen
edits.

| Token | Hex | Use |
|---|---|---|
| `godBlack` | `#020205` | Deepest anchor -- background gradient's darkest point |
| `black` | `#07070A` | Primary app background (`bg`/`bgSecondary` alias) |
| `softBlack` | `#0C0C10` | Cards (`card` alias) |
| `raisedBlack` | `#121217` | Elevated surfaces, dialogs, sheets (`bgElevated`/`cardAlt` alias) |
| `godWhite` | `#FFFDF9` | Wordmark, strongest typography (`text` alias) |
| `softWhite` | `#DADCE2` | Secondary text (`textSoft` alias) |
| `silver` / `silverBright` / `silverDark` | `#C6CBD3` / `#E4E7EC` / `#747B86` | Neutral secondary accent; `silverDark` is `textMuted` |
| `roseGold` | `#D98C8C` | Primary brand / CTA identity |
| `roseGoldBright` (alias `roseGoldLight`) | `#F0AAA3` | Bright accent (medal/tier pills, headline accents) |
| `roseGoldHighlight` | `#FFD4CC` | Narrow specular highlight band in the metallic gradient only |
| `roseGoldDeep` (alias `roseGoldDark`) | `#8E4D56` | Gradient stops, chip-selected state |
| `roseGoldShadow` / `roseGoldVeryDark` | `#5A3037` / `#231014` | Dark edges of the metallic gradient -- what makes it read as polished metal instead of a flat fill |
| `babyBlueDeep` (alias `lightBlue`) | `#75C7F7` | Information, safety, location, verified state -- secondary to rose-gold |
| `babyBlue` / `babyBlueSoft` | `#A7DFFF` / `#D3F0FF` | Baby Blue gradient stops |
| `godPink` | `#FF4FA3` | Rare, high-energy signature accent -- deliberately not the primary; see `signatureGradient` |
| `godPinkSoft` | `#FF8AC5` | Premium/paywall accents (`premium` alias) -- keeps premium surfaces from tipping fully pink |
| `success` / `successDeep` / `successSoft` | `#35B779` / `#1E7A50` / `#85D9B1` | Completed/verified/positive states |
| `warning` | `#D59A42` | Warning states |
| `danger` / `dangerDeep` | `#D44A5C` / `#912E3B` | Danger/error states |
| `textDisabled` | `#52565E` | Disabled text |

`neon`/`neonDeep` are compatibility aliases for `roseGold`/`roseGoldDeep`
kept from an earlier redesign pass, for the same reason `roseGoldLight`/
`roseGoldDark`/`roseGoldMid` exist: screens written against the older
naming inherit palette changes without maintaining a second color
language.

**Google and Apple auth buttons are the one deliberate exception.**
`google_auth_screens.dart` and `apple_auth_screens.dart` use each
provider's own mandated brand colors (Google's `#1F1F1F`/`#F2F2F2`/
`#747775`; Apple's black HIG button), not MORT tokens -- those buttons
must stay visually recognizable as the real Google/Apple sign-in
affordance, not be "rebranded."

## Gradients (`mort_tokens.dart` -> `MortGradients`, mirrored in
`MortColors` as plain `List<Color>` for non-widget use)

- `metallic` (primary CTA): 7-stop rose-gold, dark edge -> deep -> core
  -> **narrow** bright highlight -> core -> deep -> dark edge. The
  highlight stops are tightly clustered around the midpoint
  deliberately -- a broad even blend reads as flat pink/salmon, not
  metal.
- `darkRoseGold`: `godBlack -> roseGoldShadow -> roseGold`
- `background`: `godBlack -> black -> softBlack`
- `silverMetallic`, `babyBlue`, `godPink`: single-family gradients for
  their respective accent's own glow/gradient needs
- `signature`: `roseGold -> godPink -> babyBlue` -- very selective use
  only, never the default CTA gradient

## Shape

`MortRadii` (`mort_tokens.dart`): small 10, medium 14, card 12, sheet
20, pill 999.

## Liquid glass -- real blur, not just translucency

`LiquidGlassContainer` (`core/widgets/mort_liquid_glass.dart`) supports
real backdrop blur (`liveBlur`, `ImageFilter.blur` at
`MortGlassTokens.blurSigma = 22.0`), gated by accessibility
(`reducedTransparency`, high contrast) and, on Android specifically, a
second `allowAndroidBlur` flag -- `BackdropFilter` is expensive enough
that it defaults off on Android unless a surface explicitly opts in,
to protect scroll performance on lower-end hardware.

Real blur is enabled (`allowAndroidBlur: true`) for the three chrome
surfaces that request it: `MortGlassHeader`, `MortGlassNavigationBar`,
and `MortGlassSheet` (bottom sheets/modals via `MortGlassCard(blur:
true)`). These render once per screen rather than repeating inside a
scrolling list, so real blur there doesn't risk the jank
`BackdropFilter` causes when instantiated many times at once.
`MortGlassCard` automatically passes `allowAndroidBlur: blur` through,
so any caller that opts into blur gets it for real on Android without
a new parameter -- scrolling card lists (job feed, messages, etc.)
never requested blur and remain flat translucency by design.

## Structural component patterns (not just color)

Beyond the token palette, a few reusable structural patterns were
introduced to fix real density/hierarchy problems found on a full
screen-by-screen audit, not to reskin already-correct layouts:

- **`MortQuickActionGrid`** (`mort_widgets.dart`): icon-in-circle over
  a short label, wrapping row -- the compact "top actions" pattern
  real marketplace/finance apps use (Klarna, Cash App), in place of a
  bank of full-width buttons competing with page content. Used for
  dashboard quick links, Safety Center's secondary tools, and Teen
  Profile's account links. Deliberately *not* used for `Settings` or
  the Adult/Guardian/Admin dashboards, whose grouped label+description
  list (`MortDashboardActionTile`) is the right pattern for an
  exhaustive list of distinct, described actions.
- **`MortProfileCompletionMeter`**: a real "Get Set Up" checklist
  (`Profile.completionChecklist`) rather than a bare percentage bar --
  each item is an actual missing profile field, inspired by Plum's
  "2 of 5 complete" setup nudge.
- **Job feed card meta-row**: distance/location/schedule/duration/
  transportation render as compact wrapping icon+text chips
  (`_JobCardMetaChip`) instead of five stacked full-width rows.
- **Message bubbles**: the safety-scanner badge only renders on
  flagged/blocked messages, not every clean message -- showing it
  unconditionally both cluttered the thread and diluted the signal for
  messages that actually needed attention.
- **`MortGlassHeader` back-button auto-detection**: mirrors
  `MortHeader`'s existing logic (shown whenever there's something to
  pop, or the location isn't a known shell root) instead of defaulting
  to `false` with no fallback. Settings and its five sub-screens
  previously had no visible way back except the system gesture; this
  was a real, sitewide bug, not a per-screen one, so the fix is in the
  shared widget rather than six call sites.

## Safety-critical rule

Safety overrides brand decoration. Emergency/danger controls, PIN
entry, and safety actions must remain immediately legible -- Call 911
in Safety Center is deliberately the one action on that screen with
no competing visual weight. Ads never appear on Safety, Emergency,
Report, Block, PIN, Identity, Evidence, Support, or Account Deletion
surfaces.

---

## History: the original rose-gold system (superseded 2026-08-20)

The first rose-gold pass used a simpler token set (`bg #0A0A0C`, `card
#17171A`, `roseGold #C89686`, `roseGoldLight #F1CAB4`, `lightBlue
#7FC4EA`) without the God Black/God White/Silver/God Pink families
above. See `docs/MORT_ROSE_GOLD_REDESIGN_REPORT.md` and
`docs/MORT_LIQUID_GLASS_UI_IMPLEMENTATION_REPORT.md` for that original
design work -- the liquid-glass mechanics and safety-critical rule
documented there are unchanged by the Rose Gold 2.0 palette swap, only
the color values moved.
