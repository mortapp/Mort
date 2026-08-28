# Flutter Button Logic Audit

All buttons and interactions in `mort_screens.dart` and `app_router.dart` follow the strict requirement: they either trigger real backend actions via Riverpod providers/repositories, or they navigate to a screen labeled "Coming Later."

### Wired Buttons
- **Auth**: Sign In, Sign Up, Sign Out all trigger `AuthRepository` which calls Supabase Auth.
- **Profile**: Save Profile triggers `ProfileRepository.updateProfile`.
- **Jobs**: Create Job calls `JobsRepository.createJob`. Viewing jobs calls `listOpenJobs`.
- **Applications**: Submit Application calls `ApplicationsRepository.applyForJob`.
- **Safety**: Safety Ping triggers `SafetyRepository.sendPing`. Report and Block also trigger real tables.

### "Coming Later" Fallbacks
Some advanced UX features are intentionally stubbed with "Coming Later" labels to avoid dead clicks:
- Job editing and closing.
- Saved job folders.
- Detailed applicant preview UX (for proofs).
- Advanced approval routing controls.
- Adult Pro analytics dashboards.
- Pause/resume guardian controls.

No silent dead buttons were detected. All interactive elements have explicit behavior.
