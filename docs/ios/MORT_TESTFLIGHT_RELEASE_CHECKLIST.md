# MORT TestFlight Release Checklist

Status: `CODE-COMPLETE / MANUAL VERIFICATION REQUIRED`.

- [ ] Active Apple Developer Program membership.
- [ ] App ID `com.mortapp.mobile` exists and owner Team is selected.
- [ ] App Store Connect app record exists with correct SKU and primary locale.
- [ ] Version `0.9.12`, build `102` is unused in App Store Connect.
- [ ] Closed-test public configuration supplied from protected build settings.
- [ ] No server/service/provider secrets in the archive or source maps.
- [ ] iOS archive builds from `Runner.xcworkspace` in Release mode.
- [ ] Archive validation passes with no privacy-manifest or signing error.
- [ ] dSYMs/symbols retained in protected release storage.
- [ ] Internal TestFlight group contains only approved adult testers.
- [ ] Test information says marketplace is closed and provider systems are disabled.
- [ ] Test account access is least privilege; credentials are entered only in App Store Connect.
- [ ] Export compliance, content rights, age rating, privacy nutrition labels, and encryption answers are owner-reviewed.
- [ ] Physical iPhone matrix in `MORT_MAC_BUILD_AND_TEST_TASK.md` passes.
- [ ] Crash-free startup, session restore, camera/photo, VoiceOver, and large-text evidence attached.
- [ ] Child-safety, moderation, support, legal, and privacy owners approve the closed-test scope.
- [ ] External testers are not enabled until Beta App Review approves the build.

Do not promote this build to public marketplace operation. Remote push, crash
reporting, identity verification, payments, staffed support/moderation, and
approved legal text are separate production gates.

