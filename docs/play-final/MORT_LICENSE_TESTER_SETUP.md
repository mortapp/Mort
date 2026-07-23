# Google Play License Tester Setup

1. In Play Console, add dedicated Google accounts under **Settings > License testing**.
2. Add the same accounts to the internal or closed-test tester list and accept the opt-in URL.
3. Install MORT from Google Play, not by sideloading, for billing tests.
4. Confirm the device Play Store uses the tester account and that the application ID is `com.mortapp.mobile`.
5. Exercise successful, declined, canceled, pending, refunded, revoked, restored, reinstalled, duplicate-token, and account-switch scenarios.
6. Verify server entitlement state after each provider transition; never infer entitlement solely from a Flutter purchase callback.
7. Remove synthetic review grants and test accounts before any public rollout.

License-test timing and renewal behavior are controlled by Google and can differ from production. Record Play order IDs only in restricted test evidence; do not place purchase tokens in screenshots or logs.
