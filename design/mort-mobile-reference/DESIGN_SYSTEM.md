# MORT monochrome mobile reference

## Direction

MORT is a quiet, space-at-night marketplace. The interface is nearly black, low-glare, and precise: cool white typography, slate surfaces, thin graphite borders, and one pale-blue signal accent. The signature element is the double-chevron MORT mark, used as the boot and trust cue.

## Tokens

- Background: `#030507`
- Surface: `#0A0D11`
- Raised surface: `#10141A`
- Border: `#27303A`
- Primary text: `#F4F7FB`
- Muted text: `#89939F`
- Accent: `#DCE7F2`
- Type: system sans, 2 weights only (300/600)
- Body size: 13–14px, line height 20–21px
- Display: 25–45px, light weight, tight tracking
- Radius: 6px badges, 12px controls, 16px cards, 20px hero, 34px device frame
- Spacing: 8px base scale; screen inset 22px; cards 17–20px padding
- Motion: 180ms interaction, 420ms boot reveal; disable nonessential motion for reduced motion

## Interaction rules

All demo actions are inert or switch the reference screen. Safety Ping, reporting, blocking, guardian visibility, message scanning, and payment disclaimers remain visible and never appear behind a paid gate. Use semantic labels, 44px minimum touch targets, visible focus/pressed states, and do not rely on color alone for status.

## Flutter translation

Map tokens to `ThemeData.colorScheme` and keep the screen shell safe-area aware. Build `MortLogo`, `MortScaffold`, `MortCard`, `MortBadge`, `MortButton`, `MortBottomNav`, and `MortStatusCard` as shared widgets. Prefer `AnimatedSwitcher` for the boot/welcome transition, honoring `MediaQuery.disableAnimations`. Keep role mode in the shell, not duplicated inside each feature screen.
