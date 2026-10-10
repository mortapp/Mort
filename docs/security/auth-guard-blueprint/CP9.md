# CP9 password parity — BLOCKED

RED findings:
- webAppProviderPoliciesMatch failed: provider fixture config has minimum12 but no required-character complexity field. No provider enforcement runtime parity is claimed.
- signupScreenShowsSameRules failed: copy omits maximum128. The signup file is one of the95 protected pre-existing paths. It remains untouched.

GREEN: confirmationCopyExplainsReplacement; the web challenge explicitly says the new password replaces the one entered at signup. Web policy and Flutter MortValidators source both have12/128 bounds and uppercase/lowercase/digit/symbol validation. This is source comparison, not provider evidence.

The approved definition is recorded in password-policy.json. It is a contract, not a claim that generated Flutter/provider configuration consumes it. Fully shared enforcement remains incomplete. The three named tests were executed:1passed2failed. Failed tests remain available as an explicit requirement gate, not part of the passing general unit count.

No Flutter analyze or focused Flutter runtime PASS claimed for this checkpoint. No protected Flutter edits, provider changes, product migrations or hosted changes. This checkpoint is blocked by preserved signup work and missing verified provider parity; continue independent CP10.
