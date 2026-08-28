# MORT 0.9.13 Accessibility and Performance Report

## Accessibility Evidence

- Focused redesign/accessibility suite: 7 passed.
- Full Flutter suite: 276 passed, 2 intentional provider skips.
- Native integration: 2 passed on API 36/x86_64.
- PIN semantics report progress without revealing digits.
- Reduced motion and visible focus are covered.
- PIN and money controls survive narrow 1.6x text layouts.
- Native safety acknowledgments remain reachable and disabled until all five
  acknowledgments are selected at 1.6x text.
- Profile/job field errors can target and focus their originating control.
- Public/auth emulator screens showed no clipped text or inaccessible inset.

## Performance Evidence

- Exact release cold launch after the final reinstall: 6,585 ms on the local
  API 36 Play Store emulator.
- Earlier clean launch: 10,877 ms while the fresh AVD was still stabilizing.
- Flutter release web build completed in 152.3 seconds; WebAssembly dry run
  succeeded.
- Release icons were tree-shaken by 97.9% to 99.7%.
- APK native libraries passed 16 KB alignment for all 18 libraries.

No release-mode frame timeline, memory peak, long-list trace, or physical-device
startup benchmark was captured. Therefore this report does not claim app-wide
jank or memory clearance. Repeated expensive-blur behavior remains covered by
source/widget design controls rather than a physical GPU profile.

## Remaining Manual Work

Run TalkBack order, 200% font/display size, reduced transparency/motion, keyboard
and rotation, job feed/chat scrolling, image decode/memory, and frame timing on
the exact artifact on low/mid/high physical Android devices.
