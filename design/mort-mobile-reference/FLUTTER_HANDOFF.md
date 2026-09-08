# Flutter handoff

1. Create a `MortTheme` with the reference tokens and a dark-only color scheme.
2. Build a shared `MortScaffold` that applies `SafeArea`, 22px horizontal padding, a compact eyebrow/title header, and optional bottom navigation.
3. Use cards for all grouped content. Cards have a 1px graphite border and no elevation; the visual hierarchy comes from surface contrast and typography.
4. Keep safety actions primary and free. Guardian visibility, reporting, blocking, Safety Ping, message scanning, proof basics, and payment/verification disclaimers must remain available in every role.
5. Keep role-aware routes behind one shell: Teen, Adult, Guardian, and Admin use the same tokens, with different data and action sets.
6. Validate with iPhone-sized screenshots at 390x844 and with large text/accessibility settings. Every icon needs a semantic label and every action needs a minimum 44x44 hit target.
