# Stripe Minor Onboarding

Minor connected-account support is disabled until Stripe confirms the account configuration, country, age rules, representative/guardian requirements, and payout eligibility in writing or current account documentation. MORT must not collect identity documents as a substitute for Stripe-hosted verification.

Sandbox QA may use Stripe-provided test data only. The UI must label states as provider setup/review, not MORT identity confirmation. If the provider requires an adult representative, the provider flow owns that relationship; MORT stores only status and no raw identity/bank data. An ineligible or restricted account cannot receive a transfer and must be routed to support without exposing provider details publicly.
