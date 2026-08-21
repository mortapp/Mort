# MORT Design System

## Brand era: ROYAL

MORT's visual identity is the Royal House system: Obsidian foundations,
Royal Blue, Imperial Purple, Ruby, Antique Gold (ceremonial only),
required Success Green, and Parchment/Ivory text. This retires the prior
rose-gold/modern-glass identity as of 2026-08-20.

**OLD (superseded)**: Rose Gold primary brand color, generic liquid-glass
translucency, 20-28px rounded corners.

**NEW (canonical)**: Royal Blue primary CTA/navigation identity, Imperial
Purple for rank/reputation/leaderboard, Ruby as accent ornament only,
Antique Gold reserved for genuinely ceremonial moments (rank, verified
prestige, leaderboard #1, section headings) -- never a full-surface fill.
6-16px radii; ornament comes from frames, lines, and dividers rather than
large rounding.

## Colors

All colors live in `flutter_mort/lib/core/theme/mort_colors.dart` as
`MortColors` static constants. Do not hardcode hex literals in feature
code -- reference the named constant so future palette changes cascade
automatically.

| Token | Hex | Use |
|---|---|---|
| `bg` | `#08070A` | Main app background (Obsidian) |
| `bgSecondary` | `#0D0A10` | Secondary background |
| `card` | `#12101A` | Cards, sheets, large surfaces |
| `cardAlt` / `bgElevated` | `#191522` | Raised cards, dialogs, floating content |
| `chamber` | `#211A2C` | Selective elevated royal surfaces |
| `royalBlue` family | `#172D70`-`#7896E8` | Primary CTA / navigation identity |
| `imperialPurple` family | `#43205F`-`#B08BCB` | Rank, reputation, leaderboard |
| `ruby` family | `#701B39`-`#E789A9` | Accent ornament, never a primary CTA |
| `antiqueGold` family | `#8E722D`-`#F0DFA3` | Ceremonial only |
| `success` family | `#1E6340`-`#8FD5AD` | Completed/verified/positive states (required, not removed) |
| `danger` / `warning` / `lightBlue` (info) | -- | Semantic states |
| `bronze` | `#A9754A` | Leaderboard rank 3 only |
| `silver` | `#BFB29D` | Leaderboard rank 2 only |
| `text` / `textSoft` / `textMuted` | Ivory/Parchment family | Text hierarchy |

`roseGold`/`roseGoldLight`/`roseGoldDark`/`roseGoldMid`/`roseGoldDeep`/
`neon`/`neonDeep` remain as **compatibility aliases** pointing at the
`royalBlue` family so the app never renders old rose-gold anywhere while
call sites are migrated to the direct new names over time. New code
should reference `royalBlue`/`imperialPurple`/`antiqueGold` directly, not
the aliases.

## Gradients (`mort_tokens.dart` -> `MortGradients`)

- `metallic` (primary): Royal Blue -> Imperial Purple
- `ceremonial`: Royal Blue -> Imperial Purple -> Ruby (rare, high-value moments)
- `goldFoil`: Antique Gold family (ceremonial use only)
- `success`: Success Green family
- `ruby`: Ruby family

## Shape

`MortRadii` (`mort_tokens.dart`): small 6, standard 10, card 12,
container 14, sheet/modal 16, pill 999. Avoid 24px+ rounding without a
functional reason -- royal styling relies on frames and dividers, not
large corner radii.

## Typography

`mort_typography.dart`. Display/ceremonial styles (page titles, dashboard
headers, leaderboard, auth hero, profile rank) use wider letter-spacing
and weight on the existing font rather than a dedicated display serif --
adding a new font dependency mid-rebrand carried build/licensing risk
that wasn't verified this pass. Body text stays the existing clean
sans-serif. A future pass may evaluate `google_fonts` (Cinzel/Cormorant
Garamond, both SIL-licensed) for a true ceremonial serif if desired.

## Components (reformed, not duplicated)

Per the rebrand directive: existing shared widgets were retinted, not
replaced with a parallel `MortRoyal*` family.

- `MortButton` / `MortPrimaryButton` / `MortSecondaryButton`
  (`core/widgets/mort_widgets.dart`): primary gradient is now Royal
  Blue -> Imperial Purple.
- `LiquidGlassContainer` / `MortGlassCard` / `MortGlassButton` /
  `MortGlassHeader` / `MortGlassNavigationBar`
  (`core/widgets/mort_liquid_glass.dart`): retinted to the royal
  night/obsidian family via the token cascade; blur/accessibility/
  reduced-transparency/Android-blur-gating logic unchanged.
- `MortStatusChip`, `MortTimeline`, `MortStatusPill`, `MortChip`,
  `MortJobStatusBadge`: reference `MortColors.success`/`.warning`/
  `.danger` symbolically, so all 13 known success/verified-state call
  sites across the app recolor automatically from the token change.
- Leaderboard rank 1/2/3 use real medal colors (`antiqueGold`/`silver`/
  `bronze`); all other ranks stay on the standard identity color.

## Safety-critical rule

Safety overrides brand decoration. Emergency/danger controls, PIN entry,
and safety actions must remain immediately legible and never compete
visually with ornament. Ads never appear on Safety, Emergency, Report,
Block, PIN, Identity, Evidence, Support, or Account Deletion surfaces.

## Rollout status (2026-08-20)

The token/theme layer is fully converted and verified (full test suite
green, `flutter analyze` 0 issues, confirmed correct on a real Android
device). Because the design system was already centralized before this
rebrand (`MortColors`/`MortGradients`/`MortShadows` consumed almost
everywhere), the token change alone cascades correctly across the large
majority of the app's ~90 screen-level widgets without individual edits.

Explicitly completed this pass beyond the token cascade: Leaderboard
medal colors; a real, severe onboarding bug fix (legal acceptance was
never actually being recorded by the reachable sign-up flow, likely
blocking real users from completing onboarding at all) plus the required
anti-grooming/anti-CSAE consent language.

Not done this pass, left for a follow-up: consolidating the legacy
11-screen onboarding chain into a literal 5-screen flow (the fix above
addresses correctness and required content on the existing screens
without changing screen count, since collapsing the flow safely requires
verifying additional RPC contracts not yet confirmed); renaming the
~30 files still referencing the `roseGold` compatibility alias to the
direct new token names (cosmetic/code-clarity only -- visuals are
already correct via the alias); a dedicated ceremonial display font.
