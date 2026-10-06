# MORT neutral UI across all screens

User direction: match the existing classic UI with white, black, gray, and
silver throughout the authoritative Flutter client, including MORT Pro.
This supersedes the older dark/blue visual direction in the master blueprint.

## Design and scope

- White page backgrounds and white or very light gray cards/sheets.
- Near-black headings, body text, icons, selected controls, and primary actions.
- White text on black primary actions; gray secondary text and silver borders.
- Selected paywall plans use light silver with a black outline/selected indicator.
- No navy, blue tint, colored bloom, or dark full-screen paywall.
- Status meaning stays in labels, icons, semantics, and explicit confirmations;
  neutral styling must not remove safety warnings or change their actions.
- Apply the palette to authentication, onboarding, worker/adult/business,
  guardian, safety/emergency, jobs, applications, messages, financial screens,
  receipts, progression, Companion Studio, settings, legal, support, and admin.
- Preserve provider prices, entitlements, plan selection, restore, legal links,
  Continue with Free, all route guards, and backend/payment activation flags.
- User correction: pets remain vibrant. Use a separate character palette for
  companions, Guide mascots, accessories, auras, and illustrated environments.
  Keep surrounding Studio pages, controls, cards, and paywall neutral.
- User photographs, identity documents, and third-party provider logos are
  content; do not recolor their underlying image data.
- Preserve signed 115/116/117 artifacts and original screenshot evidence.
  No Android packaging, version bump, upload, merge, or production rollout.

## Implementation sequence

1. Add palette-neutrality and foreground contrast checks, paywall surface/action
   checks, and a safety-panel readability regression. Confirm failures first.
2. Consolidate semantic background/text/action/status aliases into the classic
   neutral palette. Keep true black/white distinct from surface aliases.
3. Migrate paywall surfaces, text, selection, crown, and CTA to shared tokens.
4. Inspect mixed-role legacy tokens individually: emergency panel, attachment
   viewer, companion headings/environments, progression share cards, badge
   foregrounds, and custom-painted brand marks.
5. Neutralize remaining interface literal colors and progression SVG chrome; preserve
   rank identity through shapes/labels and preserve receipt status wording.
6. Run focused regressions, Flutter analysis and full tests, shared platform
   parity, source secret scan, and diff validation. Review the complete diff.
7. Capture the actual updated paywall and representative screens; rebuild only
   the local browser preview and check navigation/rendering in the browser.
8. Record coverage, test results, remaining device gates, and sequential
   Believer/Skeptic/Investor/Judge review. Commit the reviewed source changes.

Implementation and validation complete; see the release completion report.

## Review focus

- White text accidentally left on white surfaces.
- Disabled or secondary text without sufficient contrast.
- Premium selection/primary CTA contrast at large text sizes.
- Emergency actions retaining labels, confirmations, and full touch targets.
- Literal navy colors in custom painters, companion environments, and SVGs.
- No client prices or premium entitlement state changed by the visual migration.
