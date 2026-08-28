# MORT Play App Access Workbook

> Status: closed-test publication candidate dated 2026-07-20. Not legal approval, not a public launch, and not a production-readiness claim.

- Restricted access: yes; authentication required for core workflows.
- Review credentials: stored outside repository and entered manually in Play Console.
- Account type: synthetic test account with `is_test_account=true`.
- Data isolation: RLS prevents test accounts from reading ordinary production participant records; review jobs are marked test/synthetic.
- Login: email/password on first screen; no QR or MFA unless Play Console instructions are updated.
- Disabled features: public marketplace, real ID, payments, ads, IAP, escrow, background location.
- Account deletion: Settings → Account → Delete account; enter current password and type DELETE.
- External deletion: deployed `/account-deletion/` URL using email magic-link ownership verification.
