# MORT AUTH GUARD BLUEPRINT, PART 2: AUDITS, PLAYBOOKS, TEMPLATES AND APPENDICES

Part 1 holds the immutable core, decisions and checkpoints CP0 to CP16. This part tells you **how** to audit yourself, how to use GitHub and Vercel safely, how to edit this blueprint without cheating, and gives you the templates and catalogs you need.

Sections tagged **[IMMUTABLE]** are covered by `blueprint.lock`. Sections tagged **[MUTABLE]** may be edited with a logged reason.

---

## 1. HOW TO TREAT THIS PART [MUTABLE]

Use the section numbers Part 1 refers to: section 2 (self-audit), 2.4 (four-role review), 2.5 (adversarial pass), section 3 (GitHub), section 4 (Vercel), Appendix A (gates), Appendix B (ledger schema), Appendix D (final report), Appendix H (staging package).

---

## 2. SELF-AUDIT PROTOCOL [IMMUTABLE]

You audit yourself after **every** checkpoint. The audit is not a summary of what you did. It is an attempt to find what is wrong with it. An audit that finds nothing is suspicious: check that you actually looked.

### 2.1 The checkpoint audit (run all ten checks, record each result in the ledger)

| # | Check | How |
|---|---|---|
| A1 | Scope | `git diff --stat` and `git status --short`. Every changed path is on the checkpoint's allow list. No path from `left-alone.txt` changed. |
| A2 | Lock | Run `verify-blueprint-lock.mjs`. It must pass. |
| A3 | Test-first | For each new test, show the failing run that preceded the implementation. If you cannot, mark the test untrusted and prove it by temporarily breaking the behavior. |
| A4 | Positive controls | List every denial assertion and its paired positive control. A denial without a control is not a pass. |
| A5 | Threshold integrity | Search the diff for changed numbers: timeouts, limits, 30, 600, 300, 60, 5, 64, 2, the matrix hash. Any change needs an owner approval reference. |
| A6 | Secrets and PII | Run the secret scan on the **exact tree**. Grep the new evidence and logs for the generated fixture secrets and for the shape of an email address. Report booleans. |
| A7 | Defaults | Confirm every new control is off by default, with the flag-off suite unchanged. |
| A8 | Evidence provenance | Every PASS has an evidence file with the exact SHA, a log-audit boolean, a cleanup boolean and a recorded hash. |
| A9 | Claims | Re-read your own checkpoint report. Strike any sentence you cannot back with an evidence file. |
| A10 | Authority | Confirm nothing hosted, production, DNS, mail or protected-branch related happened. List every external command you ran. |

If any check fails: fix it, re-run the checkpoint's suites, and re-audit. Record the failed audit and the fix in the ledger. Do not delete the record of a failed audit.

### 2.2 The claim audit (every checkpoint and again at the end)
Pick **three** PASS entries at random from the ledger, including at least one from an earlier checkpoint. Re-run the exact assertion on the current tree. If any now fails, the earlier PASS was wrong or something regressed: record it as a finding, mark the gate FAIL, and fix before continuing.

### 2.3 The drift audit
Compare the current tree to the baseline manifest. Report: new files, modified files, deleted files, and any change in files that other checkpoints depend on. A checkpoint that changes code owned by an earlier checkpoint must re-run that checkpoint's suites.

### 2.4 The four-role review (CP16, and at the end of CP6, CP12 and CP15)
Perform these sequentially, yourself, as separate passes with separate written outputs. The prompts are in Appendix I.
1. **Believer:** what evidence supports each claim, and what is the strongest case that the work is correct?
2. **Skeptic:** how would you break it? Try, in the fixture, at least three bypass or race ideas not already covered by the matrix. Run them.
3. **Investor/operations:** what breaks in operation: mail quotas, availability, rollback, restore, on-call burden, cost, and what a user sees when something fails?
4. **Judge:** weigh the three. Only conclusions backed by evidence stand. A failing provider or security assertion is never overruled by a successful build or a static opinion.

### 2.5 The adversarial pass (final, and whenever you finish early)
Write ten new attack hypotheses against the **current** implementation that are not in the 191-case matrix or Section K. Run each in the fixture with a positive control. Each is recorded as PASS, FAIL or UNTESTABLE with the reason. Add the ones that fail as new gates. Examples of directions to consider (do not stop at these): race between consume and capability issuance, grace-window item used after promotion rollback, replay of a hook event after worker failure, a quota refund path, a source-hash collision, a policy that accidentally widens access in the pre-request gate for a role other than `authenticated`, a Realtime join using a token whose session was removed mid-join, restore followed by a late delayed Admin write.

### 2.6 Audit the auditor
At CP15 and CP16, deliberately plant a harmless defect (for example, make a PASS evidence file reference the wrong SHA, or drop a cleanup boolean) in a **temporary copy** and confirm the certifier or your audit catches it. If it does not, fix the audit and record it.

---

## 3. GITHUB PLAYBOOK [IMMUTABLE]

### 3.1 Allowed
- Work on the feature branch already in use (`feature/mort-age-aware-auth-social`). If it does not exist, stop and report. Do not create other long-lived branches unless needed for a draft pull request, and only as a child of the feature branch.
- Normal `git push` of the feature branch to `origin`.
- Lightweight or annotated tags on the feature branch named `guard-cpN-<shortsha>`.
- A **draft** pull request from the feature branch against the default branch, with a description generated from the final report. Mark it draft. Do not request reviewers or assign people unless the owner asks.

### 3.2 Forbidden
- Force push, `--force-with-lease` included, history rewriting on pushed commits.
- Merging any pull request, enabling auto-merge, or pushing to the default or any protected branch.
- Changing branch protection, repository settings, secrets, variables, webhooks, deploy keys, collaborators or Actions configuration.
- Creating releases, publishing packages or uploading artifacts to any store.
- Pushing anything that contains a secret. If the pre-push scan finds one, do not push; remove it, rotate nothing yourself, and report.

### 3.3 Commit discipline
1. Stage with exact paths or `git add -p`. Run `git diff --cached --stat` and read the diff before every commit.
2. Never stage anything on the `left-alone.txt` list.
3. Message format: `cpN: <summary>` plus a body listing tests run and the evidence file names (no secrets).
4. Run the committed-tree secret scan before every push. The scan must cover the files in the commit, not just the working tree.
5. One checkpoint, one or a few focused commits. Do not squash away history of failed and fixed audits; the ledger references them.
6. After a push, verify with `git ls-remote origin refs/heads/<branch>` that the remote SHA equals the local SHA. Record it.

### 3.4 Drafting the pull request
Title: `MORT email challenge guard: local-verified checkpoint series`. Body: the final report summary, gate table, open failures, BLOCKED gates and what each needs, link to the staging package, and an explicit line: "Not for merge. Hosted activation is a separate approval."

---

## 4. VERCEL AND mortapp.org PLAYBOOK [IMMUTABLE]

The owner has said you may access Vercel, and that this can help with the website side of the process. The owner has not approved changes to the live site. Use the access as follows.

### 4.1 Allowed without asking
1. **Read-only inspection:** list projects, read project and deployment metadata, read the production deployment's headers and served files by making ordinary read requests to the public site, read build and runtime logs of **your own preview deployments**, read configured domains (names only, no changes).
2. **Preview deployments:** deploy the `web/` output (or the relevant directory) to a **preview** environment, never to production. Record the deployment ID and URL in the ledger.
3. **Testing against the preview:** run the script-inventory crawl, header tests, CSP checks and the challenge-page behavior tests against the preview URL.
4. **Cleaning up** previews that you created, once their evidence is recorded. Never delete a deployment you did not create.

### 4.2 Hard stops (ask the owner first, do not do)
- Promoting any deployment to production, assigning or changing aliases, or redeploying the production target.
- Adding, removing or changing a domain, subdomain, redirect at the project level, DNS record or certificate.
- Creating, editing or deleting **environment variables**, secrets or integrations, in any environment.
- Changing project settings, build commands, root directory, framework, firewall, WAF, attack challenge mode, team, members, billing or plan.
- Deleting a project, a production deployment, or anything you did not create.
- Printing a Vercel token or any credential in logs, reports, commits or chat.

### 4.3 What to use the website access for
| Purpose | Allowed action |
|---|---|
| Same-origin audit (MD2-134) | Read-only crawl of the live site for scripts, headers, service worker registrations and cookies. Record findings. |
| Auth page script inventory (CP12) | Preview deployment plus the crawl and header tests. |
| Dedicated auth origin trial | A preview URL or a project-owned `*.vercel.app` URL only. A real subdomain needs DNS: hard stop. |
| Production header comparison | Compare preview headers to production headers read-only, record differences, propose changes in the staging package. |
| Mail link target | Verify the fixed HTTPS route on the **preview** serves the Continue page without consuming anything on load. |

### 4.4 How to keep production safe
1. Before any Vercel call that is not purely a read, state in the ledger which environment it targets. If it is not `preview`, stop.
2. Confirm the preview deployment is not aliased to the production domain.
3. Keep the challenge and confirmation pages disabled in the production output. The build must default to disabled (a test `productionOutputStillDisabled` exists in CP12).
4. Do not point a preview at any hosted Supabase project. Previews use the fixture's synthetic configuration or static test doubles only.
5. After testing, record what you deployed, the IDs, and what you removed.

### 4.5 If you find a problem on the live site
Record it in the ledger as a finding with evidence (header names and values that are not secret, script URLs). Do not fix it on the live site. Put the recommended change in the staging package.

---

## 5. SELF-EDIT PROTOCOL [IMMUTABLE]

You are allowed and expected to improve this blueprint as you learn. You are not allowed to use that freedom to weaken it.

### 5.1 What you may edit
- Any **[MUTABLE]** section.
- The ledger, changelog, templates and catalogs.
- Checkpoint task lists: add tasks, split a checkpoint into sub-checkpoints, reorder independent tasks, or add new checkpoints.
- Test catalogs: add tests.

### 5.2 What you may never edit
- Any **[IMMUTABLE]** section, including this one.
- Gate definitions in a way that lowers the bar: removing a gate, marking one owner-scoped-out without the owner's written approval, loosening a required evidence type.
- Thresholds or approved decisions.
- Historical evidence, historical failures and the unexplained-failure register's recorded entries (you may add to an entry, never remove).

### 5.3 How to edit
1. Write the proposed edit and the evidence for it in `CHANGELOG.md` **before** making it: date, checkpoint, section, what, why, evidence reference.
2. Make the edit.
3. Re-run the lock verification. It must still pass.
4. Add a line to the ledger noting the edit and its checkpoint.
5. If an edit changes what a later checkpoint must do, re-read that checkpoint before starting it.

### 5.4 Self-edit smell tests (stop if any is true)
- The edit makes a currently failing gate pass without new evidence.
- The edit removes or relabels a hard stop.
- The edit appeared after a failing run and its only justification is that the run failed.
- You find yourself editing the lock file or the lock script.

---

## 6. FAILURES, STUCK STATES AND THE REGISTER [MUTABLE]

### 6.1 Unexplained-failure register
Maintain `docs/security/auth-guard-blueprint/UNEXPLAINED.md`. Start with U1 to U4 from Part 1, section 4. For each entry record: id, first seen (SHA and date), symptom, evidence captured, hypotheses (confirmed / ruled out / untested), occurrences since, status (open / explained). New failures with no explanation get the next id. Status moves to **explained** only when a cause is shown with evidence, never because the failure stopped happening.

Hypothesis list to work through (add evidence for each):
- Host sleep or hibernate, Docker Desktop pause, WSL or VM clock changes.
- Port conflicts, container restart policy, health-check race at startup, service dependency order.
- Database connection pool exhaustion, lock waits, `statement_timeout`, `lock_timeout`.
- Auth service restart after hook configuration, `ECONNREFUSED` while a service restarts.
- Subprocess output buffering, a child process holding a pipe, Windows process handling, antivirus scanning, disk I/O stalls.
- Memory pressure in the fixture containers.
- A genuine intermittent guard fault: a race, a lock, a retry path.

### 6.2 Three-strike rule
If a checkpoint fails the same way three times despite diagnostics: record every attempt, mark the checkpoint BLOCKED with the reason, and move on. Return once at the end with fresh eyes. Never loop forever.

### 6.3 Time and budget awareness
Prefer short suites while building. Run long suites only when a checkpoint calls for them. Record durations in the ledger so the owner can see where time goes.

---

## 7. TEST CATALOG [MUTABLE: add, never remove]

Names below are guidance for naming and coverage. Implement as executed named assertions with positive controls.

### 7.1 Gate and lifecycle
`flagOffNoopTableViewRpc`, `flagOnDeniesRevokedTable|View|Rpc`, `reasonIsSessionEnded`, `freshSessionStillAllowed`, `anonUnaffectedBeforeAfter`, `serviceRoleUnchanged`, `passwordChangeRetiresSessionViaAdminPath`, `passwordChangeRetiresSessionViaTrigger(ifUsed)`, `globalRevocationRetiresSession`, `restoreRetiresByGeneration`, `deniedWithin30sPostgrest|Storage|Realtime`, `unchangedHistoricalExpiryFailuresRecordedAndLinked`, `uncoveredPathsMeasuredByTokenLifetime`, `openRealtimeConnectionWindowDocumented`, `catalogCoverageFailsOnUncoveredResource`, `newlyGrantedRelationDetectedWithoutHandRegister`.

### 7.2 Challenge, budget and time
`fiveFailuresExhaustExactlyOneFamily`, `codeAndLinkShareBudget`, `wrongIdSecretPairDebitsOnlyCorrectItem`, `unknownIdDebitsNoFamily`, `concurrentSuccessResolvesOnce`, `lastFailureRaceDeterministicBySerialization`, `expiryEqualityIsExpired`, `lockHeldPastDeadlineUsesPostLockTime`, `clockTimestampNotNow`, `resendNeverRenewsFamily`, `atMostTwoEligibleItems`, `graceStartsAtSmtpPromotion`, `terminalItemNeverReenters`, `lostResponseNeverMintsSecondCapability`, `capabilityBoundaryBeforeAtAfter300s`, `invalidPasswordDoesNotConsumeOrExtend`, `verifierMismatchCannotSetPassword`.

### 7.3 Hook, delivery and quotas
`hookWrongSignatureNoIssuance`, `hookReplayNoSecondItem`, `hookStaleAndFutureTimestampRejected`, `hookUnsupportedActionSafe`, `hookNeverLooksUpUncommittedUser`, `workerDefersUncommittedAccount`, `smtpFailureNeverPromotes`, `ambiguousOutcomeFailsClosed`, `staleAckCannotPromoteLate`, `queueSaturationBounded`, `deliveryConcurrencyMax2`, `ciphertextPurgedOnTerminal`, `perRecipientAndGlobalCeilings`, `perSourceSubLimit`, `inFlightTimeoutShorterThanCooldown`, `overloadResponseNonChargedAndTargetIndependent`.

### 7.4 Provider bypass and mutation guard
`directVerifyGetPostDenied`, `pkceExchangeWithoutMortDenied`, `otpMagiclinkRecoveryInviteEmailChangeDenied`, `legitPasswordOauthRefreshStillWork`, `oauthLinkingDoesNotKeepUnverifiedPassword`, `delayedAdminWriteFencedAfterCleanup`, `newOperationSucceedsAfterOldFenced`, `markerReintroducedByOldRequestRejected`, `markerCarriesNoAuthority`, `providerInternalWritesNotBroken`, `bulkUpdateWhereCovered`, `triggerOrderingDocumented`.

### 7.5 Browser and web
`loadMakesNoSecretRequest`, `fragmentClearedImmediately`, `uuidAloneShowsNeutral`, `continueShowsServerMaskedRecipient`, `lostResponseAndRefreshNoReplay`, `doubleClickContinueOneConsume`, `noStorageOfSecrets`, `cspNoInlineNoEval`, `frameAncestorsNone`, `noServiceWorker`, `crawlLoadsOnlyApprovedScripts`, `productionOutputStillDisabled`, `previewMatchesLocalHeaders`, `accessibleStatusTextWithoutColor`, `noJavaScriptSafeMessage`.

### 7.6 Logging and operations
`credentialLeakageZeroAllSinks`, `hookWorkerGuardNeverLogAddress`, `auditPurgeKeepsNewer`, `restoreRetiresGenerations`, `failoverRetiresInFlight`, `rollbackCoherent`, `partialActivationRefused`, `cleanupLeavesZeroFixtureRows`, `secretScanCommittedTreeZero`.

### 7.7 Certification
`staleShaEvidenceRejected`, `flagCannotBeSetDirectly`, `blockedGateKeepsFalse`, `truncatedMatrixFailsLoudly`, `missingCleanupBooleanRejected`, `countsComputedNotHardcoded`, `plantedBadEvidenceCaught`.

---

## 8. ANTI-PATTERNS (do not do these) [IMMUTABLE]

1. Marking a gate PASS because a related test passed.
2. Treating a green rerun as a diagnosis.
3. Widening a timeout or margin after seeing a failure.
4. Writing tests after the implementation and calling them test-first.
5. Counting overlapping requirements as independent passing tests.
6. Putting a secret, address or token into a log, report or commit "just for debugging".
7. Using the ledger as a diary of intentions. It records executed facts only.
8. Quietly editing a historical report or evidence file.
9. Using hosted resources "just to check".
10. Staging unrelated changes because it was convenient.
11. Disabling a failing test, skipping a suite or catching and swallowing an assertion error.
12. Letting a cleanup error hide the primary failure.
13. Claiming hosted behavior from fixture evidence.
14. Claiming device or mail-client behavior from a server-side check.
15. Using `now()` for a deadline decision.
16. Building policies from regex over migrations instead of the live catalog.
17. Editing the lock file or its verifier to make a mismatch go away.

---

## 9. RISK REGISTER [MUTABLE]

| Risk | Impact | Mitigation in this blueprint |
|---|---|---|
| Session gate misfires and locks out real users | High | Flag off by default, flag-off parity, staged enablement only after the owner approves staging |
| `db_pre_request` unsupported or different on hosted | High | Gate H09 BLOCKED until staging; fallback of restrictive policies from the live catalog |
| Pre-request gate adds latency at scale | Medium | Measured in CP3; capacity under concurrency still a staging item |
| Edge functions silently bypass RLS | High | CP5 evidence-first decision; hybrid and non-user lists |
| Realtime open connections outlive revocation | Medium | Documented window, client re-auth on refresh, path register |
| Unexplained flakes hide a real race | High | CP1 diagnostics, register, no closing by rerun |
| Mail quota exhaustion by throwaway signups | Medium | Per-source sub-limit, 50% alert, documented cap control |
| Same-origin script compromise | Medium | Script inventory, CSP, dedicated origin option, staged DNS |
| Failover loses a consumed marker | Medium | Failover as restore event, optional synchronous commit |
| Agent overstates certification | High | Computed certification, claim audit, audit-the-auditor |
| Agent edits its own rules | High | Immutable core lock, changelog, smell tests |
| Production site changed by accident | High | Preview-only Vercel rules, environment statement before each non-read call |

---

# APPENDICES

## APPENDIX A. GATES REGISTRY [MUTABLE: add, never remove or relax]

Local gates (must be PASS for `LOCAL_GUARD_VERIFIED`):

| ID | Gate | Checkpoint |
|---|---|---|
| G01 | Fixture isolation and exact-target refusal | CP1 |
| G02 | Provider checkpoints P1 to P5 on the pinned provider | CP0, CP3 |
| G03 | Challenge lifecycle and shared failure budget | existing, CP15 |
| G04 | Hook ingress, signup, real hook path | existing, CP14 |
| G05 | Hook ingress, recovery, real hook path | CP14 |
| G06 | Continue and verifier-bound capability | existing, CP15 |
| G07 | Mutation guard and delayed-write fence | existing, CP15 |
| G08 | Token hook and direct-provider bypass denial | existing, CP15 |
| G09 | Cutover, rollback and restore | existing, CP15 |
| G10 | Retention and cleanup | existing, CP15 |
| G11 | 30 s lifecycle gate, PostgREST (table, view, RPC; password change, revocation, restore) | CP3 |
| G12 | 30 s lifecycle gate, Storage | CP4 |
| G13 | 30 s lifecycle gate, Realtime joins | CP4 |
| G14 | Session gate flag-off no-op | CP3, CP6 |
| G15 | Catalog-driven coverage | CP4 |
| G16 | Edge Function session behavior decided by evidence | CP5 |
| G17 | Trusted source and shared limits | CP7 |
| G18 | Key ring | CP8 |
| G19 | Password policy parity | CP9 |
| G20 | No credential in any sink (hard) | CP10 |
| G21 | Address policy sink inventory and purge (fixture) | CP10 |
| G22 | Failover as restore event (two-node fixture) | CP11 |
| G23 | Auth page script inventory and headers (local) | CP12 |
| G24 | Auth page inventory on Vercel preview | CP12 |
| G25 | Emulator link checks | CP13 |
| G26 | Owner-run mail checklist prepared | CP13 |
| G27 | Recovery end-to-end with controls | CP14 |
| G28 | Hook-path decision memo | CP14 |
| G29 | Computed certification | CP2 |
| G30 | Secret scan on the committed tree | every checkpoint, CP15 |
| G31 | Regression: Flutter, backend, RLS, website | CP15 |
| G32 | Three consecutive clean serial runs on one SHA | CP15 |
| G33 | Four-role review and adversarial pass | CP16 |
| G34 | Migration additive, flag off, rollback documented | CP6 |
| G35 | Immutable-core lock verified at every checkpoint | CP0 onward |

Hosted or external gates (BLOCKED until approvals; required for `FULL_GUARD_CERTIFIED`):

| ID | Gate | Needs |
|---|---|---|
| H01 | Key rotation with the real key manager | Staging project |
| H02 | Live Google and Apple sign-in paths (MD2-065) | Staging, test accounts |
| H03 | Hosted log inspection and retention (MD-119) | Staging, retention decision |
| H04 | Hosted failover or recovery behavior (MD2-095) | Hosted topology answer |
| H05 | Real mail delivery and SPF/DKIM/DMARC headers (MD2-135) | Approved sender |
| H06 | Notification previews on real clients (MD2-126), including iPhone | Approved sender, owner on device |
| H07 | Dedicated auth origin and DNS (MD2-134) | DNS and certificate approval |
| H08 | MD2-168 scope-out | Owner approval |
| H09 | `db_pre_request` support and behavior on hosted | Staging |
| H10 | Hosted trusted-source header | Staging |
| H11 | Production token lifetime setting | Owner decision |
| H12 | Native Android on a real device (if the emulator is not accepted) | Owner device |

---

## APPENDIX B. LEDGER SCHEMA [MUTABLE]

`LEDGER.json`:

```json
{
  "schema": 1,
  "baseline": { "sha": "", "branch": "", "capturedAt": "", "leftAlonePathsFile": "" },
  "lock": { "hash": "", "verifiedAt": "" },
  "externalMailSent": 0,
  "checkpoints": [
    {
      "id": "CP0",
      "status": "NOT_STARTED|IN_PROGRESS|DONE|BLOCKED",
      "commit": "",
      "tag": "",
      "startedAt": "",
      "finishedAt": "",
      "audit": { "A1": "PASS|FAIL", "A2": "", "A3": "", "A4": "", "A5": "", "A6": "", "A7": "", "A8": "", "A9": "", "A10": "" },
      "claimAuditSample": ["gateId", "gateId", "gateId"],
      "blockedReason": "",
      "notes": ""
    }
  ],
  "gates": [
    { "id": "G11", "status": "PASS|FAIL|BLOCKED|NOT_RUN|OWNER_SCOPED_OUT", "sha": "", "evidenceFile": "", "evidenceSha256": "", "logAuditClean": true, "cleanupComplete": true, "blockedBy": "" }
  ],
  "unexplainedFailures": [
    { "id": "U1", "status": "open|explained", "hypotheses": [ { "text": "", "state": "confirmed|ruled_out|untested", "evidence": "" } ] }
  ],
  "externalCommands": [ { "checkpoint": "", "tool": "git|vercel|adb|docker", "environment": "local|preview|read-only", "summary": "" } ],
  "vercel": { "previews": [ { "id": "", "environment": "preview", "createdAt": "", "removedAt": "" } ] },
  "github": { "pushes": [ { "sha": "", "remoteShaVerified": true } ], "draftPr": "" }
}
```

`LEDGER.md` mirrors it in a readable table plus a short narrative per checkpoint.

---

## APPENDIX C. REQUIREMENT GROUP MAPPING [MUTABLE]

Map the 191 current matrix requirements, the 328 historical records (519 records total) and the Section K rows to executable tests. Keep IDs stable. Groups used so far:

| Group | Focus | Typical gates |
|---|---|---|
| T1 | Parsing, binding, crypto, locator | G03, G06 |
| T2 | Budget, expiry, authoritative time | G03 |
| T3 | Hook auth and replay | G04, G05 |
| T4 | Signup timing, orphans, failover | G04, G22 |
| T5 | Provider bypass, JWT, session paths, mutation guard | G07, G08, G11 to G13 |
| T6 | Capability, recovery, races, delayed writes | G06, G07, G27 |
| T7 | SMTP, TLS, injection, fixed redirect | G04 |
| T8 | Browser | G23, G24 |
| T9 | Quotas, IPv6, flood, locks | G17 |
| T10 | Overlooked-bypass items | G17, G19, G23 |
| T11 | Restore, rollback, baseline | G09, G22 |
| T12 | Execution contract and isolation | G01, G29 |
| T13 | Policy decisions and fences | G03, G07 |
| T14 | Notification previews, same-origin, gateways, native links | H05, H06, H07, G25 |

Rules: one executable test may cover several IDs but every ID needs its own evidence reference. Never relabel an old ID. Never count overlapping requirements as independent tests. Keep static triage verdicts separate from runtime status.

---

## APPENDIX D. FINAL REPORT TEMPLATE [MUTABLE]

Write to `hardening/` and summarize to the owner.

1. Final commit SHA, the list of commits and tags, remote SHA verification, draft pull request link, files deliberately left alone.
2. Test counts per runner (Node, Deno, browser, Flutter) at that exact SHA.
3. The gate table (G and H gates) with status, evidence file, evidence hash, and for BLOCKED gates exactly what each needs.
4. Computed `fullGuardCertified` and the certification level, with the reasons.
5. The unexplained-failure register with every hypothesis and its state.
6. The lifecycle gate results: nine combinations for PostgREST, Storage and Realtime, denial times, controls, added latency (p50, p95), and the path register.
7. Edge Function result: whether `getUser` already rejects revoked sessions, the helper decision, the caller classification differences from the report.
8. Views, buckets, published tables and catalog coverage results.
9. Web results: local inventory, Vercel preview inventory, deployment IDs, same-origin audit findings, differences between preview and production headers. Confirmation that production was not changed.
10. Emulator result and the owner-run mail checklist location. External mail counter (expected 0).
11. The four-role review outputs and the adversarial pass results.
12. Audit-the-auditor results.
13. Owner decisions still pending, with the specific question for each.
14. Everything that remains BLOCKED.

---

## APPENDIX E. CHECKPOINT REPORT TEMPLATE [MUTABLE]

```
Checkpoint: CPn <title>
SHA: <short and full>
Tests: written first: <n>; failing-before: <n>; passing-after: <n>
Suites run: <names, counts, durations>
Gates touched: <ids and status>
Audit A1..A10: <PASS/FAIL each, with notes>
Claim audit sample: <three gate ids and results>
Findings: <list; include negative results>
Unexplained failures: <new or updated>
External commands: <list with environment>
Blocked: <what and why>
Next: <next checkpoint and any prerequisite changes>
```

---

## APPENDIX F. SELF-AUDIT QUICK CHECKLIST [MUTABLE]

Before you say "done" on any checkpoint, answer yes to all:
- [ ] Every new test failed for the right reason first.
- [ ] Every denial has a positive control.
- [ ] No threshold, limit or approved decision changed.
- [ ] Immutable lock verified.
- [ ] Secret scan clean on the exact tree, no secrets or addresses in evidence.
- [ ] Flag-off suite unchanged.
- [ ] Every PASS has an evidence file bound to this SHA.
- [ ] I struck every claim I cannot back.
- [ ] Nothing hosted, production, DNS, mail or protected-branch happened.
- [ ] Left-alone files untouched.
- [ ] The ledger is updated, including negative results.

---

## APPENDIX G. WORKING NOTES AND CONVENTIONS [MUTABLE]

1. **Discover, do not guess, commands.** Run each tool's `--help` before first use. Do not invent flags.
2. **Time.** Use `clock_timestamp()` in database deadline logic. Use real elapsed time for assertions. Test setup may move disposable row deadlines, but no production clock override exists.
3. **Concurrency.** Load tests: 20 concurrent, 500 requests, 60 second wall deadline, pool max 8. Abort on unauthorized mutation, secret exposure, cleanup failure, non-fixture connection or resource-bound violation.
4. **Synthetic callers.** Rotating-IP tests use synthetic trusted-ingress contexts only.
5. **Naming.** Evidence files: `hardening/auth-email-guard-<checkpoint>-<topic>-<date>.json`, sanitized.
6. **Vocabulary.** "Verified" means executed with evidence. "Inspected" means read in source. "Claimed" means reported by someone else. Use the right word.
7. **Glossary.** Family: a set of challenge items for one account and purpose sharing a deadline and counter. Item: one deliverable code and link. Capability: the one-use secret issued at Continue. Fence: a generation that retires older sessions, grants or tokens. Grace: the 60 second overlap of the previous item. Generation: a monotonic counter kept in the external journal. Gate: a registry entry that must be PASS.

---

## APPENDIX H. STAGING PACKAGE (produced in CP16, not executed) [MUTABLE]

Deliver a document for the owner to review before approving staging. It must contain:

1. **Scope of what staging would change:** exact Auth settings (hook configuration, JWT expiry value proposed, SMTP test sender), exact migrations, exact Edge Function deployments, secrets by name and location (no values), and `pgrst.db_pre_request` configuration.
2. **Activation steps** as a single coherent cutover sequence, with the control flags and their order, and the baseline procedure (rebuild at cutover, compare aggregate counts and digests, no address inventories).
3. **Rollback and restore steps**, including generation bump, old-link retirement and the assurance level after rollback.
4. **Per-gate hosted checks:** H01 to H12, each with the exact test to run, the evidence it produces and who runs it.
5. **What the owner must supply:** staging project and its allowed changes, a mail sender, test mailboxes and an iPhone check, Google and Apple test accounts, retention period, failover answer, DNS decision, token lifetime decision.
6. **Risks and unknowns** with the evidence that would resolve each.
7. **Cost and time estimate** where known.
8. **Explicit statement:** no hosted change has been made; approval of this package authorizes staging only, never production.

---

## APPENDIX I. FOUR-ROLE REVIEW PROMPTS [MUTABLE]

**Believer.** "List every claim in the report. For each, cite the evidence file and hash. State the strongest argument that the work is correct and complete for its scope. List what the evidence does not cover."

**Skeptic.** "Assume the work is wrong. Name the five most likely places. For each, design and run a test in the fixture with a positive control. Report results. Add three attacks not in the matrix, Section K or the adversarial list."

**Investor and operations.** "Walk through: a user signing up, a user locked out by the busy response, a mail outage, a restore, a failover, key rotation, an on-call night. What fails, what does the user see, what does the operator do, how long does it take? List the cost drivers and the limits that need owner numbers."

**Judge.** "Combine the three. A conclusion stands only if evidence backs it. A failed security or provider assertion cannot be overruled by a passing build or a static opinion. State the certification level, the blocked gates and the recommendation, and say what you could not verify."

---

## APPENDIX J. OPEN QUESTIONS FOR THE OWNER [MUTABLE]

Ask once, in the final report, not during the run:
1. Approve scoping out MD2-168?
2. Approve a staging project, and which settings may change there?
3. Approve a mail sender or relay and how many messages?
4. What log retention period do you accept, and do you accept the address-exposure statement?
5. What is your hosting provider's failover and replication behavior?
6. Do you want a dedicated auth origin, and who handles DNS?
7. What access-token lifetime do you want in production?
8. May web changes ever be promoted to production, and under what process?
9. Do you want the HTTP hook or the native database hook for the hosted deployment?

---

## 10. START HERE

Begin with CP0. Verify the lock after you build it. Work through CP1 to CP16 in order, auditing yourself after each, editing the mutable parts when the evidence says so, and logging every edit. Push each checkpoint to the feature branch. Use Vercel previews and read-only inspection for the web side. Never touch production, DNS, hosted Supabase, mail or builds 115, 116 and 120. Finish when every checkpoint is DONE or honestly BLOCKED, the final report is delivered, and the staging package is ready for the owner.
