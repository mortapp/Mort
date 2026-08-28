# Payment Dispute Review Runbook

1. Confirm expiring `payment_reviewer` assignment and conflict status.
2. Review the accepted contract/version, both acceptances, funding event, job events, PIN events, proof, participant statements, provider timeline, and dispute hold.
3. Record factual findings, policy basis, recommendation, and limitations. Do not expose provider identifiers.
4. AI summaries may assist but cannot become the decision.
5. Prepare a bounded resolution through the server function; never type an amount/destination into a provider call.
6. A different `payment_operations` assignee must confirm execution.
7. Keep provider execution off when a provider dispute, missing evidence, role conflict, environment mismatch, or live-mode request exists.
8. Reconcile the verified webhook result and notify participants with neutral wording.
9. Preserve appeal and audit records.

No provider money movement is enabled in the closed-test environment.
