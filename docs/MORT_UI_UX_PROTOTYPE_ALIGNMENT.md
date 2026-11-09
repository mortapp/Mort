# MORT mobile UI/UX alignment

**Visual authority:** the supplied October 2026 interactive prototype, its screen captures, and prototype notes. This replaces the earlier dark glass/space visual direction in `docs/MORT_DESIGN_SYSTEM.md` for the active mobile product.

## Product target

`flutter_mort` is the production client. It is one Flutter implementation shared by Android and iOS. `swift_mort` and the Expo tree are reference-only and are not separate products to reskin. The prototype is visual and interaction guidance only: its fictional accounts, job data, PINs, payment outcomes, maps, and verification states must never be copied into production behavior.

## Visual system

- Black, white, and a ten-step neutral gray ramp form the interface palette.
- Green is reserved for released/positive money states; amber for held/pending states; red for emergency and destructive actions. Other state labels stay neutral.
- The default surface is light. A matching dark theme uses the same hierarchy and semantic colors.
- Use Instrument Sans for display/numeric emphasis and Inter for interface text, bundled locally so Android and iOS render the same typography offline.
- Use 1 px dividers, 16–20 px page gutters, 12–18 px card radii, and no content drop shadows or backdrop blur. Elevation belongs to sheets and dialogs.
- Motion is short and confirms a real state change. Respect system reduced-motion settings.
- Components include role-aware navigation, standard/compact/pinned job cards, sheet header/footer, money rows, task checklists, evidence grids, status strips, PIN pads, timelines, and audit rows.

## Product behavior to preserve

- Teen home prioritizes Up Next, quick jobs, then nearby work. Poster home prioritizes active work and applicants.
- Start and finish PINs remain server-backed, in-person confirmation flows. The teen must not be able to start work remotely.
- Completion remains gated by every required checklist item and server-confirmed completion; disabled actions state why.
- Payment amounts retain one consistent order and arithmetic wherever shown. Payment actions stay fail-closed while disabled.
- Verification badges identify people only when actual backend/provider evidence supports them.
- Emergency controls are unmistakable, accessible, and disclose what will be shared before confirmation. No private location is introduced into ordinary job/application responses.
- Moderation keeps case evidence, audit history, recommendation, and attributable decisions role-restricted.

## Cross-platform acceptance

- Use the same Flutter widget tree, tokens, and layouts on Android and iOS.
- Preserve platform safe areas, keyboard behavior, back gestures, native permission prompts, and OAuth callbacks.
- Validate representative 390 x 844 layouts and larger text without clipped actions, inaccessible controls, or privacy-sensitive overflow.
- Exercise teen, poster, Guardian, and moderator surfaces with the existing authorized repositories and role guards; no mock success state may replace a backend result.

## Migration approach

Replace the global visual tokens and shared chrome first, then migrate screen families from the prototype in dependency order: teen discovery/details; active job/safety/completion; poster home/posting/applicants; wallet/receipts; onboarding/profile/messaging; Guardian and moderation. Keep each screen's domain logic and navigation contract intact. The exact iOS build cannot be certified on this Windows host; shared Flutter widget tests and source checks establish UI parity only, not iOS archive/device acceptance.
