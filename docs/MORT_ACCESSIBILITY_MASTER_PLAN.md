# MORT Accessibility Master Plan

Accessibility is a free participation requirement across auth, onboarding, discovery, jobs, applications, messaging, proof, safety, settings, support, and monetization.

## Baseline Requirements

- Semantic labels, hints, traits, headings, and error associations
- Dynamic Type and text zoom without clipped controls or hidden actions
- Non-color status, sufficient contrast, and dark/light appearance testing
- VoiceOver/TalkBack reading and focus order that matches task order
- Keyboard and switch-access equivalents where the platform supports them
- At least platform-standard touch targets and spacing
- Reduce Motion support and no essential timed animation
- Captions/transcripts or text alternatives for meaningful media
- Plain-language errors with preserved input, retry, cancel, and support paths
- Locale-safe dates, times, currency display, pluralization, and bidirectional layout planning
- Accessible camera/photo alternatives and upload progress/cancellation

## Workflow Verification

1. Complete signup, DOB gate, role setup, and first useful action at large text sizes.
2. Browse, filter, inspect, save, apply, and withdraw without color-only meaning.
3. Read/send messages, identify unread threads, report, block, and use Safety Ping with assistive technology.
4. Upload and review proof with clear privacy copy, focus restoration, and actionable errors.
5. Dismiss paywalls and ads, restore purchases, and reach free alternatives without traps.
6. Verify admin evidence and destructive actions with keyboard/focus support.

## Evidence Gates

Flutter widget tests and static analysis are necessary but insufficient. Swift source audit is necessary but insufficient. Before release, run Xcode Accessibility Inspector, VoiceOver, Dynamic Type extremes, Reduce Motion, Increase Contrast, color filters, Switch Control/Full Keyboard Access where applicable, and physical-device camera/notification interruption tests. Record defects by workflow, not only by screen.

Reference: [Apple accessibility guidance](https://developer.apple.com/design/human-interface-guidelines/accessibility/).
