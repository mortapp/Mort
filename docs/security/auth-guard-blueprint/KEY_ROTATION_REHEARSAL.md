# Staging rotation rehearsal (not executed)

Run node scripts/auth-email-guard/key-rotation-plan.mjs OLD_KID NEW_KID to print a plan. It never reads keys, deploys, changes configuration or sends mail.

Owner approval for a synthetic staging project and its protected key manager is required. Install nonextractable HMAC-SHA256/AES-256 key pairs using protected configuration. Never put key material in command arguments, Git, reports or logs. Load exactly current and previous pairs. Set the previous retirement deadline once to twenty minutes after cutover. Do not extend it on restart or rollback.

Verify real provider ingress, previous pending code and encrypted outbox within overlap, new current issuance, unknown/missing kid denial, and retirement equality denial. Remove previous key only at retirement. A failure blocks cutover; restoring old database state must not restore retired key validity. Existing ring integration is BLOCKED, so this document does not authorize staging execution.
