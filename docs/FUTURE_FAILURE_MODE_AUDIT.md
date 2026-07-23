# Future Failure Mode Audit

- Startup/config failure: recoverable startup screen and retry.
- Stale/expired session: auth-state provider invalidates profile; friendly session errors exist.
- Missing/deleted profile: onboarding guard is shown.
- Restricted account: restriction wins before onboarding or role access.
- Missing RevenueCat data: free path and empty states remain available.
- Web native API call: IAP and ads are guarded off; proof explains native requirement.
- Duplicate submit: busy state blocks core action repeats; database uniqueness remains backup protection.
- Deleted job or unauthorized record: safe unavailable/error state.
- Upload interruption/type/size: still requires native picker implementation and QA.
- Unknown backend error: generic user-safe error, no backend detail echo.
- Browser loader failure: PWA retry button reloads the app.
- Slow/offline network: loading and retry states exist at startup; broader cached/offline data is not implemented.
