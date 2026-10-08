# MORT Auth Guard: Defensive Jailbreak and Stress-Test Matrix

Run only against isolated local `mort-mobile` Supabase/GoTrue, disposable accounts, synthetic mailboxes, and fake SMTP credentials. Never target production, real users, real SMTP, public proxies, or third-party systems. Never log secrets, passwords, tokens, codes, recipient inventories, or bearer credentials. A pass means no unauthorized state change, generic failure where required, bounded resources, and no sensitive disclosure.

## Cases 1–120: core attack surface

1. Unknown challenge ID: generic failure, no enumeration.
2. Empty/oversized/non-UUID ID: bounded rejection, no mutation.
3. Unicode/null-byte ID: parser-safe rejection.
4. Duplicate JSON keys: deterministic parse or rejection.
5. Unexpected JSON types: no coercion bypass.
6. Oversized body/header/cookie: bounded 4xx, no exhaustion.
7. Content-type confusion: only supported parser path works.
8. Method confusion: GET/HEAD never consume.
9. Path normalization: no weaker route via dot segments or encoding.
10. Parameter duplication: trusted binding wins or request rejects.
11. Unknown fields/flags: `admin`, `verified`, `skip_check` do nothing.
12. Cross-account redemption fails.
13. Cross-purpose redemption fails.
14. Code/link representations share one budget/state.
15. Recipient substitution cannot alter binding.
16. Client account UUID cannot select target.
17. Purpose case/encoding variants cannot alias authority.
18. Stale challenge after address change fails.
19. Deleted-account redemption cannot mutate or recreate.
20. Superseded challenge stays dead.
21. Signup rollback orphan cannot rebind.
22. Boundary codes (all-zero/all-nine) follow fixed policy.
23. Leading-zero code is not numerically coerced.
24. Wrong-length code is generic and correctly accounted.
25. Unicode digit confusables do not bypass.
26. Whitespace/delimiter variants have explicit policy.
27. Near-miss timing leaks no useful oracle.
28. Missing HMAC key fails closed.
29. Key rotation has explicit safe semantics.
30. Digest/configuration algorithm is pinned.
31. Link sample meets 128-bit entropy requirement.
32. URL/referrer/history inspection finds no secret leakage.
33. Fragment/query/path mix-ups do not create an alternate flow.
34. Replay after restart still fails.
35. Exactly five wrong guesses retires one challenge.
36. Sixth wrong guess gives no further useful mutation.
37. Four failures followed by success consumes once.
38. Failure after success cannot resurrect state.
39. Concurrent wrong guesses yield exactly one coherent budget.
40. Concurrent correct/wrong submissions serialize safely.
41. Resend cooldown/hourly quota holds under active challenge.
42. Resend after exhaustion cannot revive old item.
43. Just-before-expiry boundary is deterministic.
44. At-expiry boundary is invalid under `now >= expires_at`.
45. Post-expiry authorization fails.
46. Clock skew cannot bypass authoritative time.
47. Missing hook signature rejects.
48. Altered signature/body rejects.
49. Wrong signing key/algorithm rejects.
50. Stale signed event rejects.
51. Exact event replay is idempotent.
52. New transport ID cannot replay old event.
53. Action-type confusion rejects.
54. Payload substitution cannot change trusted fields.
55. Duplicate callbacks are bounded.
56. Hook timeout/retry storm cannot over-issue.
57. GET `/verify` provider token gives no MORT proof.
58. POST `/verify` provider token gives no MORT proof.
59. Token-hash form cannot bypass.
60. Typed provider code cannot bypass.
61. PKCE exchange cannot create unauthorized session.
62. Implicit flow cannot create unauthorized session.
63. Attacker-chosen signup password cannot sign in before proof.
64. Direct recovery endpoint cannot reset/login without capability.
65. Actual GoTrue method variants are tested and denied as required.
66. Provider-version drift fails activation if ordering changes.
67. Client `user_metadata` proof claim never authorizes.
68. Client `app_metadata` cannot create privileged proof.
69. Forged JWT claims fail signature validation.
70. Stale JWT behavior matches documented policy.
71. Refresh after unauthorized confirmation remains blocked.
72. Refresh sessions after recovery behave as locally verified.
73. Access-token hook timeout fails closed.
74. Low-privilege hook role cannot read private state.
75. Malformed JWT claim types cannot exploit truthiness.
76. Private registry cannot be enumerated through APIs/RPC.
77. Recovery capability reuse fails.
78. Capability expiry blocks late mutation.
79. Capability account substitution fails.
80. Capability-purpose substitution fails.
81. Empty/weak/oversized/confusable passwords fail policy.
82. Recovery cannot directly create login session.
83. Recovery response cannot enumerate accounts.
84. Recovery cannot mutate role/entitlement fields.
85. Consumed grant cannot authorize repeated password writes.
86. Unknown upstream result retains safe pending state.
87. Email change racing redemption is atomic and safe.
88. Password change racing recovery has no confused deputy.
89. Deletion racing redemption leaves no orphan proof.
90. Resend racing redemption is deterministic.
91. Fifth failure racing resend preserves terminal semantics.
92. Hook-before-user-commit does not assume committed FK.
93. Signup rollback cleans orphan challenge.
94. One operation grant cannot authorize concurrent writes.
95. Database failover during consume cannot replay.
96. Worker crash after SMTP send is idempotent.
97. SMTP authentication failure never marks usable.
98. TLS downgrade/invalid certificate rejects.
99. SMTP recipient mismatch never verifies.
100. CRLF/template injection cannot alter headers/HTML.
101. Redirect is fixed HTTPS route only.
102. Provider token never leaks into email/logs.
103. Scanner GET does not consume.
104. Mailbox prefetch/retry does not consume.
105. Recipient mailbox race honors current binding.
106. Unsupported notification action has no mutation authority.
107. Static page load causes no mutation.
108. Fragment clears and secret stays in memory only.
109. Browser history cannot replay.
110. Iframe/cross-origin embedding is blocked or harmless.
111. URL-field injection cannot cause XSS.
112. No-JavaScript browser has safe no-mutation failure.
113. Double-click/rapid submit executes once.
114. Network retry after submit is idempotent.
115. Native link compatibility works without alternate auth.
116. Accessible status text matches server result.
117. Distributed wrong guesses cannot evade per-challenge budget.
118. IPv4/IPv6 rotation cannot evade quotas.
119. Concurrent quota updates are atomic.
120. Unknown-ID flood is independently rate-limited.

## Cases 121–137: overlooked-bypass review

121. Pre-created account password takeover: never promote pre-verification password.
122. OAuth transition cannot silently promote unconfirmed password identity.
123. Link swap remains bound to original account/generation.
124. Masked recipient comes only from server-bound challenge.
125. Attacker email fields cannot control subject/preheader/HTML/destination.
126. Notification previews contain no credential material.
127. Hook timing paths leak no useful oracle.
128. Email parser/canonicalization policy is consistent.
129. Case/normalization collision cannot share proof.
130. IPv6 and forwarded-header spoofing cannot establish identity.
131. Cross-user invalidation is impossible.
132. Mail-bombing has recipient/global ceilings and backpressure.
133. Hot-row lock waits and pool usage are bounded.
134. Same-origin scripts/service workers cannot access recovery secrets.
135. Mail gateway/fragment rewriting cannot consume or relocate secrets unsafely.
136. Android custom-scheme interception cannot capture capabilities.
137. Dashboard/Admin alternate routes enforce the same boundary.

## Cases 138–160: execution contract and clarification

138. Parser failures reject before challenge mutation.
139. Recognized malformed credentials consume failure; parser failures do not.
140. Database time rejects expiry and future hook timestamps.
141. Address change retires generation; changing back does not resurrect proof.
142. Cutover baseline race cannot inherit proof.
143. Every pending account, old or new, follows replacement-password rule.
144. All enabled session paths are inventoried; disabled providers are tested.
145. PostgREST/Storage/Realtime token behavior is recorded and accurate.
146. CORS and credentialed cross-origin POSTs cannot bypass capability.
147. Host/forwarded-origin spoofing cannot choose policy or destination.
148. Error text/size/headers/timing leak no useful oracle.
149. Invalid password is rejected before capability consumption/dispatch.
150. Recovery of unconfirmed account cannot implicitly confirm it.
151. Delayed Admin update cannot duplicate or prematurely report success.
152. Provider-internal credential updates hit the mutation guard.
153. Restore retires pre-restore generations before reopening redemption.
154. Rollback records assurance and never reopens consumed state.
155. Destructive tests abort unless exact local project/containers/database match.
156. Synthetic bounded load uses no public proxies or external traffic.
157. Version drift runs in a separate fixture without mutating working stack.
158. SMTP fault tests use fake local credentials only.
159. Service-role compromise remains a boundary; no public bypass is justified.
160. Evidence records stable source ID, redacted request, fixture, state digest, logs, cleanup, and status.

## Cases 161–182: policy decisions and delayed writes

161. Continue-only recipient display: GET is neutral; Continue atomically validates/consumes and returns masked target plus restricted capability.
162. Optional non-consuming peek returns only masked target, no authority, and shares locked state with redeem.
163. Peek with wrong recognized credential consumes shared failure; parser failures follow parser boundary.
164. Peek rate limit prevents discovery/timing abuse.
165. Scanner JavaScript can learn at most masked recipient, never consume or authorize.
166. Peek logs/errors never pair challenge ID with masked address or secrets.
167. Invalid password is rejected before restricted capability use or Admin dispatch.
168. Immediate supersession, cooldown, redelivery, and overlap are tested in separate policy fixtures.
169. If overlap is approved, at most current/immediately previous delivered item is eligible within approved grace/cooldown bounds.
170. Overlapping family shares original ten-minute deadline; resend cannot extend or reset.
171. Overlapping credentials share one locked ceiling of five failures.
172. Consumed/exhausted/expired/retired/ambiguous items never re-enter grace.
173. Successful consumption invalidates the entire family.
174. Idempotent redelivery cannot extend expiry or refresh budget.
175. Owner completion remains possible during bounded maximum-rate resend testing; no universal availability claim.
176. Duplicate/out-of-order hooks and delivery preserve approved eligible set and ceiling.
177. Tier labels cannot defer secrecy, isolation, resource, status, provider, or required delivery gates.
178. Hook-enabled testing occurs only in a disposable isolated fixture.
179. Operation marker is a correlator, not bearer authorization.
180. Marker/token inspection reveals no credential material and marker alone authorizes nothing.
181. Delayed write racing cleanup/new operation is fenced at provider boundary.
182. Unknown Admin outcome retains safe pending state, prevents replay, and preserves retry liveness; otherwise activation is blocked.

## Execution and approval rules

All cases begin `NOT_RUN`. Static triage and design review are not runtime certification. Preserve source mappings such as `MD-001`–`MD-120`, revised `MD2-001`–`MD2-137`, `MD2-138`–`MD2-160`, and `DOCX-K01`–`DOCX-K17` without relabeling historical evidence. Overlapping documents are requirements, not independent passing tests. Record redacted request shape, caller role, fixture/version, concurrency, expected/observed result, permitted counter changes, before/after state digest, sanitized-log check, and cleanup. Failed or incomplete cleanup cannot pass.

Recipient-display choice, resend strategy and grace bounds, activation tiers, and operation-marker fencing require owner approval. Keep positive controls: valid confirmation/recovery and existing legitimate password/OAuth sessions must work; rejecting every request is not a pass. No hosted activation, production hook change, release, merge, emulator, repackaging, or credential operation follows from completing this matrix alone.

## Supplemental challenge-locator and recovery-lease cases (183–191)

The eighth attachment adds mandatory challenge-ID semantics and proposes a recovery-capability lease change. These cases are local-only review gates; the five-minute lease policy is not approved merely because it appears in the design.

183. **Missing challenge UUID:** Submit a code or link secret without the canonical challenge UUID carried by the email. Pass: reject before challenge mutation; no email-address fallback, latest-challenge lookup, account-wide counter change, or state disclosure.
184. **Malformed challenge UUID:** Submit malformed, ambiguous, duplicate, or noncanonical IDs. Pass: bounded generic rejection before challenge mutation with independent abuse controls.
185. **Opaque locator is not authorization:** Obtain or guess a valid challenge UUID without its code/link secret. Pass: UUID alone cannot display a target, consume a challenge, issue a capability, confirm an address, reset a password, or create a session.
186. **No email-plus-code lookup:** Attempt redemption using only an email address and code, including case/alias/normalization variants. Pass: endpoint does not perform address-based challenge lookup and cannot enumerate or mutate account-wide state.
187. **ID/secret cross-binding:** Pair a valid UUID from account A with a valid code/link secret from account B, or swap IDs between representations. Pass: exact challenge binding fails; neither account changes and no failure budget is charged to the wrong challenge.
188. **Canonical ID transport integrity:** Test URL fragments, query parameters, copied links, duplicate ID fields, encoding, truncation, and line wrapping. Pass: the email-carried canonical UUID is parsed exactly once; no alternate locator or fallback route is accepted.
189. **Capability issuance boundary:** Verify that page load, scanner access, peek (if approved), invalid challenge, and provider-only confirmation cannot issue a recovery capability. Pass: only successful server-authorized challenge consumption can create the restricted one-use capability.
190. **Recovery lease start-time policy:** Test the approved/legacy alternatives separately: original-challenge deadline cap versus a proposed five-minute lease beginning at successful challenge consumption. Pass: no capability outlives the owner-approved maximum, no resend extends it, and no implementation silently adopts the proposed change without recorded approval.
191. **Recovery lease boundary and reconciliation:** Test just before, at, and after the capability deadline; race expiry with password submission, duplicate submission, delayed Admin result, and marker cleanup. Pass: exact expiry is deterministic, one-use state persists, unknown outcomes never reopen capability, and stale delayed writes remain fenced.

### New owner-review decisions

- Mandatory canonical challenge UUID transport is part of the proposed binding model.
- Email-address-plus-code lookup and latest-challenge fallback remain prohibited.
- The UUID is an opaque locator, never authorization by itself.
- The five-minute post-consumption recovery lease requires explicit owner approval and compatibility testing before implementation or activation.
