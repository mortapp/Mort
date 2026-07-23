# MORT Color and Accessibility Audit

## Verified

- Dark surfaces use light text and do not depend on color alone for status.
- Buttons meet the approximate 44x44 touch target; primary buttons are 52 pixels high.
- Icon buttons require tooltips.
- Forms use visible labels, focused borders, error text, autofill hints, and password visibility controls.
- The PWA loader uses `role=status`, `aria-live`, safe-area padding, and reduced-motion handling.
- Browser verification at 390x844 found no horizontal overflow.

## Remaining Manual Checks

- VoiceOver order and labels on a physical iPhone.
- Dynamic Type at large accessibility sizes.
- Keyboard focus order across every web route.
- Color contrast certification with final App Store screenshots and branding.
