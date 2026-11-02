# MORT Supabase migration drift review — 2026-11-02

## Scope and hashing
Read-only comparison of production `jxbnrkasktbhtiujkhay` and isolated QA `ckcxakhxqlkhppsxxjhv`. For each applied ledger row, SHA-256 is calculated over UTF-8 `array_to_string(supabase_migrations.schema_migrations.statements, E'\\n')`; this is the recorded SQL statement payload, not a hash of the current schema. Production was queried read-only. Isolated project schema/data were not changed.

## Result
- Production: 73 migrations, `20261026194801` through `20261102113314`.
- Isolated: 82 migrations.
- Shared migration names: 72; 71 have identical SQL payload hashes. All 72 shared migrations have different version IDs in the isolated ledger because that chain was replayed/restamped.
- One shared name, `restrict_job_application_direct_select`, has a ledger-hash mismatch only because the isolated payload has one final LF byte (475 bytes vs production 474). After stripping SQL line comments and normalizing whitespace, executable text matches exactly. Runtime privilege/RLS inspection also matches production.
- One production migration is absent from isolated: `20261102113314_guardian_id_response_mask_production`, SHA-256 `96ad143a1c066d3496ca492774c810a9bc196e629f2c7fa2bf908459c4392efa`.
- Isolated has ten additional migrations listed below; it is a divergent QA extension, not a clone to reset or overwrite.

## Production migrations reconciled by name
| Production version | Isolated version | Name | Ledger SQL SHA-256 | Comparison |
|---|---|---|---|---|
| 20261026194801 | 20261102033233 | mort_production_core_architecture | cb0e53f045c48bae83fa2f828d2046846ed2fdd8e2aff79ae0e8f60441d9f051 | identical SQL payload |
| 20261026195135 | 20261102033237 | mort_production_architecture_hardening | 0702d9ce825c7bc39efcd116573b960e06bd36013a177e387339cdb6f155369c | identical SQL payload |
| 20261026195746 | 20261102033240 | mort_production_workflow_rpcs | e75c65bebe148938ecc33642ea26ba7f1ad78e685d6986e5ed5631717869a02a | identical SQL payload |
| 20261026195814 | 20261102033242 | mort_production_messaging_workflows | f70d5df86afeb282a2e03cc9ce046659d7740482d0557c699ac6e0023d14a8bb | identical SQL payload |
| 20261026195853 | 20261102033243 | mort_production_role_verification_workflows | dfd92b6d5ea222a7ab5d65d33604c22bb4039e81a615cfde28aa15ceb09d62b5 | identical SQL payload |
| 20261027072203 | 20261102033245 | mort_job_interests | b15dbdce4849783fb55cffe6d8a8347e3720fd19a1ea28184f28cfa3af5f0fdb | identical SQL payload |
| 20261027073519 | 20261102033248 | mort_protect_exact_job_address | aab757dde0d383a942eb6d0c1dacaa3cd7283252b47a78bc932d903070c9d397 | identical SQL payload |
| 20261027082432 | 20261102033250 | mort_enforce_job_age_eligibility | 39e8ea67ed2c01ce597990e1fbaed69eb3dca836864a7e4f198eefae528d52c7 | identical SQL payload |
| 20261027084715 | 20261102033252 | mort_release_mode_status | bf95f4253bb6145afb8312e646bf19c0e4619a0a3555f764d83986b3f6c94e87 | identical SQL payload |
| 20261027084830 | 20261102033254 | mort_release_status_invoker_access | 65607f44285f286390a55194ead71017ca4444b968fd0938470693e3baf6b03d | identical SQL payload |
| 20261027092720 | 20261102033301 | mort_auth_profile_bootstrap | 7851ea105c38d0fdba3798d599cb9e152105887529b8f221825de433d1f09bc8 | identical SQL payload |
| 20261027092959 | 20261102033303 | mort_auth_invoker_wrappers | 3f04c64db9293a1efed0ce3f727d5ac36d91624e16b15fba17e748655911b491 | identical SQL payload |
| 20261027102746 | 20261102033305 | onboarding_progress_rpc_contract | 41b5bb4b8066b704ec6a75068d48ab3406598845a10301604b0d2e99bd77b1fc | identical SQL payload |
| 20261027120458 | 20261102033307 | mort_stripe_production_foundation | 0a0bbd30d9267349649ddecef6f200e66d2f16cf81bdd2a3cf65863bda78d371 | identical SQL payload |
| 20261027121059 | 20261102033309 | mort_flutter_marketplace_contract | f578dd7bbc077613c553f3f654a0ca1ee46a0e156b9c15dbaf915d9ad234f6d3 | identical SQL payload |
| 20261027121614 | 20261102033311 | mort_stripe_assignment_payment_api | 0c4ac5e66c80b189b7e0acfbcbf26fdc84d87f37c48ac54e36d493e56e98063f | identical SQL payload |
| 20261027121939 | 20261102033313 | mort_stripe_assignment_payment_status | 95a74b4ebfa8f44c13327be5ddad6d2596d720d101fac011cc6116e40243fee1 | identical SQL payload |
| 20261028010003 | 20261102033315 | mort_teen_guardian_onboarding | 2ade658e9b19c66ccd4309fea9ad8ec8cb19e95a426b3dd393cfc43a4b2a682a | identical SQL payload |
| 20261028010507 | 20261102033320 | mort_guardian_link_lifecycle | 0121629a7e717cc9f57ffa1bceeaee19a1e5bd1dd8f3d8ef98907ac6c7bb4cc0 | identical SQL payload |
| 20261028010533 | 20261102033322 | mort_guardian_link_revocation_audit | e8183e3d0ac5d331898d26ba5a87d567f5e7ba00a21f7240d288999a763cee7e | identical SQL payload |
| 20261028012746 | 20261102033324 | mort_production_foreign_key_indexes | ca5cd3449403eaefccbff78285183b49b321b1f315e86e57ac8818195ce1503e | identical SQL payload |
| 20261028031921 | 20261102033328 | mort_public_marketplace_activation | 62940df89effae500b41dd01c2329a5a779a0891dc6948aa8468fdef56fb8b50 | identical SQL payload |
| 20261028034447 | 20261102033330 | flutter_application_backend_contract | 33afef66dc308a76502e2d7c3b40cf5c39f67449b032286891be02627a467652 | identical SQL payload |
| 20261028040220 | 20261102033332 | flutter_job_management_contract | 0ec9e3e6a8fc567babbae0e07e059797a55ecdeb5f8e185250a01c0b3e264168 | identical SQL payload |
| 20261028040438 | 20261102033335 | status_event_actor_indexes | a5791167994853a7a04aa69ce8120bc1c7160533186e695d2a8ffea9b7994c0d | identical SQL payload |
| 20261028041541 | 20261102033337 | flutter_legal_clickwrap_foundation | a78ed025124dbe1f31b628bc9c5d421cc03d457423dab805e4c3b70e13d6571f | identical SQL payload |
| 20261028041919 | 20261102033342 | flutter_legal_contract_index_and_actor_fix | bb17385f78b0ed0cd9bb512e7c578af98481cd4e158f7081f949bd3e26c96b03 | identical SQL payload |
| 20261028043814 | 20261102033344 | production_runtime_feature_status_contract | 03d681677002a3af47aee4ea8aec87a7daa4e24404e01e2d3c2f5aecc60628e9 | identical SQL payload |
| 20261028044508 | 20261102033346 | guard_job_acceptance_guardian_consent | 88a898e2c50447f3719808696f61da1c2f3dfe0bc6e9a4520edc76a28ea90e45 | identical SQL payload |
| 20261028045055 | 20261102033348 | enable_rls_private_security_tables | 64dd1f04ec52fc057108ab18aa486fca8e72feedf71291ad325d83fb6962297d | identical SQL payload |
| 20261028045720 | 20261102033350 | flutter_job_contract_backend | 246fd4aff83737f103d48fec0b64cbccceae3ed93c19ace306c0580a1863de80 | identical SQL payload |
| 20261028052414 | 20261102033352 | guardian_alert_preferences | 800fc7b536bcf4524bd462e4b309906c786e71c868521f8a8f4e0be4039353dc | identical SQL payload |
| 20261028053421 | 20261102033354 | safety_report_contract | 744c248772cbc6197f1572224693ab9b6bcd3b88f01b5c747071a9efbf2da45b | identical SQL payload |
| 20261028053832 | 20261102033356 | safety_report_invoker_security | 13207542c9f3122939b709fd7c3f3ed85e19573cb445395a39812e68ab5ad6b6 | identical SQL payload |
| 20261028054348 | 20261102033401 | safety_ping_and_job_checkins | 7c870c6caa03eff1a47918b6eac964d2371d3c47e57243ba3dd6cc0ff0adbe8c | identical SQL payload |
| 20261028055217 | 20261102033403 | saved_jobs_contract | e9306536fa5783afe43411284973577fcbbfc1e8add008d6c1ceeb0b33da6c63 | identical SQL payload |
| 20261028062156 | 20261102033406 | mort_flutter_job_safety_agreements | 71610fdb87104a0e4950f7f9da633c435b206214d186177f7b1c1ec1e88e85e0 | identical SQL payload |
| 20261028062322 | 20261102033408 | mort_flutter_job_safety_rpc_invoker_wrappers | 8f92466c549e14c90013515a04cdb1181d6d0ee64f1b29a0b858c8c826ab925e | identical SQL payload |
| 20261028065139 | 20261102033410 | mort_job_execution_status_live_model | d9c428c0c1f25751760f5ee6d30e5c964a6d3758c64345a85d0b35b075ab00a4 | identical SQL payload |
| 20261028070130 | 20261102033412 | mort_job_safety_cancellation_live_model | 6ae5bf21dd499091cacb00c85cb7bdb9aa102d1c25060d313628cacb90ba7873 | identical SQL payload |
| 20261028070221 | 20261102033414 | index_job_safety_cancellation_relations | decf3e1754cef46e56f502ed4e8b36940b08a10d7332f03cd6ba2c89ec321ecf | identical SQL payload |
| 20261028071751 | 20261102033416 | mort_job_execution_pins_live_model | b4da1026a7bc0e5cdc3b2b312c8a03bfc059a6e1914729841a1632acac0882a9 | identical SQL payload |
| 20261028071846 | 20261102033421 | mort_job_execution_review_response_access | b6eea4e04f67b9dff48d5125d14da22166461c504b7e7933e8cc124b68adbfb7 | identical SQL payload |
| 20261028071941 | 20261102033423 | mort_job_execution_review_response_indexes | c52d94865b5a229b0d33fb0d8da5ad08ce2481dda5fb9abacf4409914499d70e | identical SQL payload |
| 20261028073745 | 20261102033425 | flutter_proof_upload_review_current_model | 6a6a21e0dd264b62f649f3561e0927ec5f0636328a6b28c048c05f379b98f020 | identical SQL payload |
| 20261028074611 | 20261102033427 | harden_proof_review_completion_lifecycle | e686915b8de5f97623afa6b3452af473e64e6f6a234eea2710d7e9f4b6d450b5 | identical SQL payload |
| 20261028074711 | 20261102033433 | serialize_proof_review_locks | 4099274fab73cb80b2fdcc0c466d4c9c750664cb4f6de92453ba72064e4f8d67 | identical SQL payload |
| 20261028075800 | 20261102033436 | flutter_first_party_trust_status_contract | 355bc6b7bc169f88b33a5c9539e985b04d0c5b0bad6e511d1a97c4c3a0851768 | identical SQL payload |
| 20261028081226 | 20261102033438 | flutter_identity_provider_unavailable_status | fbcea7d90566ed368199fb6d3220ebbc056ffed8945e44704d2458a90257b400 | identical SQL payload |
| 20261028101143 | 20261102033442 | completed_job_star_reviews | 910680f67d0b27c602eb8959a617f1c3210da0e9f610d05b978883dfe5a418cc | identical SQL payload |
| 20261028111929 | 20261102033447 | mort_public_messaging_contract | f9b1e82894c50f3a61ba1d2854e671bf6d8bc212293a9f87e6125f04111e8cc6 | identical SQL payload |
| 20261028114820 | 20261102033450 | mort_message_moderation_visibility | 94ed3f6a87b700511f88bc5adb7bf8c756aa2a3479f885358ce6d7ce4309e361 | identical SQL payload |
| 20261028120908 | 20261102033452 | restrict_job_contract_table_writes | 924e039a611c4d40e88129d83ab53f41c3ea8257ebbaf0b0dd50931aff079f1e | identical SQL payload |
| 20261031220518 | 20261102033454 | allow_confirmed_pending_legal_acceptance | b8009009ca64c5368e1f21b604958a9ab3cfbca5812032c5fb66216be34c2c0e | identical SQL payload |
| 20261031224305 | 20261102033456 | fix_onboarding_account_user_id_ambiguity | b2f79924794e8d772e82e99be2b30d1d74cf97051d119e7096fec3448f033406 | identical SQL payload |
| 20261031225301 | 20261102033458 | fix_onboarding_safety_user_id_ambiguity | a018309c2e383df86d826f7e7a2eec02113967b42b64a248ea610855875943b4 | identical SQL payload |
| 20261031230849 | 20261102033500 | require_verified_school_email_for_minors | bdf9041531dac2fe9e7ecbc7ad1966b83128d97f7ae92e36062b752a7cf9ab6a | identical SQL payload |
| 20261031231634 | 20261102033502 | approve_herron_student_email_domains | 68d6f4d67432d2188c8859f124f160c750e65e38d1c31caec94ee317241ca2f0 | identical SQL payload |
| 20261031232548 | 20261102033507 | enforce_minimum_age_and_hybrid_identity_requirements | 37520bb4cb01983f0e24f6952c7e7f82bb806e7e7e764f78b69e4f38e63ae4eb | identical SQL payload |
| 20261031233241 | 20261102033510 | require_dob_for_email_signups | 7e5b3277cd261973be46c182b542207ddc68a9703b1fada41b77cfee53d02b1c | identical SQL payload |
| 20261031234728 | 20261102033512 | optimize_participant_rls_auth_uid_initplans | e43e5aa8df0c1788d552f12e95a1cc2743f10b0a4805d418f4f44739ddaef5bc | identical SQL payload |
| 20261031235321 | 20261102033514 | restrict_direct_job_application_inserts | f2112cae30cd37a7ab546cb6e9bbdeb5a8eb9fcc01040e93ca2acf86cb9d0f71 | identical SQL payload |
| 20261101001147 | 20261102033521 | hide_jobs_from_inactive_posters | 2fc328f01d7e2e523a6d23c01db77553d653b9c5fa7b44d13c56ac179546f330 | identical SQL payload |
| 20261101001315 | 20261102033523 | restrict_guardian_link_direct_writes | 24324ed6d17d3c0bae8651b5a6bb6f3dfbf455c26b4b9188401edfbb7d0a9733 | identical SQL payload |
| 20261101001528 | 20261102033525 | require_active_guardian_for_teen_access | 8d50a9c61e172917879552f3acbf362122f388f6327f68b86c28f2f3da09aae6 | identical SQL payload |
| 20261101001842 | 20261102033527 | limit_message_sends_to_safe_rpc | 55423978127016fd1f697c71d022de53c2fc90ce5e1c15f916b5c023fa28bc50 | identical SQL payload |
| 20261101002049 | 20261102033532 | require_active_guardian_for_job_approval | 79a93a596bc8116147e1d4c45a43f21daa6544bb84b2e3350b8b23ecdfba7dd4 | identical SQL payload |
| 20261101002253 | 20261102033534 | enforce_minimum_age_on_verification_review | 41b1d301b064ec3c993b5c7fc3a303806dcbe7ee5a209aed52a5d5535422dda5 | identical SQL payload |
| 20261101002805 | 20261102033540 | safety_reports_server_only_idempotent | 7e28e40545898cd81a16e01bf530e62d29d48635c7b3eacd54a9deeaec7f7d5e | identical SQL payload |
| 20261102003713 | 20261102033542 | atomic_application_and_guardian_resend_contract | 938aa78d7096058a8f61343902a1571e225188c3ac456f207e1709fa6b9954f0 | identical SQL payload |
| 20261102003741 | 20261102033544 | private_location_and_block_message_contract | 6950b856320e8a72f131b3dcb111e915356ffb732a0a216b1d2810d97f62b036 | identical SQL payload |
| 20261102040639 | 20261102033615 | restrict_job_application_direct_select | d816da845f1c71643a0d577b9629b98b3e8db9c0ed4c3667e8a4e7db7a60cf6d / b49e184e16b6cc91e24fc3e74bde87bb8ef6b128d61fdbbfe2f5e2471d72ec2c | trailing-newline-only difference; executable SQL equal |
| 20261102113314 | — | guardian_id_response_mask_production | 96ad143a1c066d3496ca492774c810a9bc196e629f2c7fa2bf908459c4392efa | missing in isolated |

## Ten isolated-only migrations
| Isolated version | Name | Ledger SQL SHA-256 | Direct dependencies / effects observed in SQL |
|---|---|---|---|
| 20261102033559 | job_location_change_notifications | 7a559a87dfc35875e6ce5a6d5b1f998668c2cdba148a87e0fde233f4a0805c8a | Replaces `private.refresh_job_safety_agreement`; uses `public.job_safety_agreements` and `public.notifications`. Depends on the baseline job safety agreement and notification contracts. |
| 20261102033605 | job_distance_band_contract | d7427b73e49d4f8cc8f96bb82c012099925cffd3715d7d304fb75d760e868d11 | Creates private distance-center table and `set_job_approx_location_v1` / `get_job_distance_v1`; references jobs, profiles, release control, verification, Guardian links, auth users, blocks, and `private.mort_edge_action_limits`. |
| 20261102033608 | safety_report_moderation_rpc | 24825e51bd83271db5aa5268abd02dc169361d52c46df2b915065149969e1e60 | Creates `mort_review_safety_report`; references safety reports, profiles, `private.user_roles`, and admin audit. It predates the QA staff foundation and uses the legacy role table. |
| 20261102033610 | guardian_application_decision_schema_rpc | f462bb6bf71efa9f70d4c468777e6eff68c6e1fd53073645eacb8b8b953e6156 | Adds decision fields/index/event table, `guardian_decide_job_application`, and a Guardian-link-revocation trigger; depends on applications, jobs, links, profiles, auth users, notifications. Adds Guardian application decisions absent from production policy; do not port without product-policy approval. |
| 20261102033613 | guardian_application_visibility_contract | b302609ff6aae080d594616f6573234561324cec25b7790026a80f4120115d2f | Replaces the job-application SELECT policy using jobs, profiles, Guardian links/preferences, and auth users. Subsequent direct-SELECT revoke removes table access for anon/authenticated; RLS alone does not mask columns. |
| 20261102040606 | mort_require_three_teen_verification_tracks | d7f4bdb5577f7608a57271a34469b6c02fc8fabc76d4808904451f58e4c05b37 | Adds `private.teen_has_mort_verification_triplet`, replaces eligibility, adds verification-action triggers to application/contract/message writes, and changes application insert policy. References profiles, verification cases, jobs, release control, Guardian tables, applications, conversations, contracts, and messages. |
| 20261102041917 | mort_staff_access_foundation | 02864f006ddc40ac058ec701dc83e3e0b35513ff7eb8842bfd5f6719db49633c | Creates staff identities/memberships/training/permissions/audit tables, permission and audit functions/triggers. Depends on Auth identities; no initial reviewer is seeded. |
| 20261102052602 | enable_pgtap_for_isolated_backend_tests | 01d53eac23af1b1a2596ee06ba1366d2ce0a8412d273529bb081f9e8e061a2bc | Installs `pgtap` in `extensions` for isolated database tests; no MORT application object dependency. |
| 20261102112306 | guardian_id_mask_harmonize_strict_check | cfbdf7c568488710a530bd8b0c9f12d8f9e4e862ab7b5ce437cef61d5d94d8e8 | Exact-anchor replacement in `get_my_job_applications`; strengthens Guardian ID visibility to require active Guardian profile, adult DOB, and confirmed email in addition to active dual consent. |
| 20261102112319 | guardian_decision_reason_mask_harmonize | ef5985b9efb9ac0db14433d5f417b97fff021ca1e905963cea5cc48e3084ec06 | Exact-anchor replacement in `get_my_job_applications`; masks the QA-only Guardian decision reason and applies the same current Guardian identity checks. Depends on the Guardian decision schema extension. |

## Missing Guardian mask migration
The production row `20261102113314_guardian_id_response_mask_production` has exact payload SHA-256 `96ad143a1c066d3496ca492774c810a9bc196e629f2c7fa2bf908459c4392efa`; no row with that version or name exists in isolated QA. The isolated project contains two differently named, separately hashed Guardian masking migrations at 11:23 UTC, before production's 11:33 UTC migration. Current isolated function `get_my_job_applications(uuid)` has MD5 `ab635df2e852da240d1f82595afc372c`; production and the clean local baseline have MD5 `94a1b987774f994019ba6269b9abeb16`. Catalog timestamps show the isolated chain diverged before the production migration and received independent harmonization; catalog data cannot prove the operator/audit reason it was omitted. Do not insert a synthetic history row or replay the production text: its old anchor is no longer present. The production and isolated RPC definitions both enforce caller-scoped Guardian-ID masking; isolated has additional active-account/adult/confirmed-email checks.

## Proposal source comparison
Proposal 901 contains two source guards (not five). Across proposals 900, 901, and 902 there are five guarded functions:
| Proposal function | Production / expected MD5 | Isolated MD5 | Result |
|---|---|---|---|
| `mort_review_verification_case(...)` | `9de9e53ea3e300b78819932eabc14594` | `9de9e53ea3e300b78819932eabc14594` | exact match |
| `get_job_application_eligibility(uuid)` | `401d64ec19cf1fa1ab072709266fe4a7` | `5b701599fe40c74a21e027aae102eea1` | substantive QA-only change |
| `mort_accept_job_application(uuid)` | `a44e036f16579106d9ae615d2a54235f` | `c53a5ecfc861bb6b6eb723ba2f465892` | substantive QA-only change |
| `schedule_active_job_checkin(uuid,integer,uuid)` | `68ddb42187ef290145bda12d93a7b00b` | `68ddb42187ef290145bda12d93a7b00b` | exact match |
| `complete_active_job_checkin(uuid,uuid)` | `7a7b9ea9824a47e14e783b79aefac098` | `7a7b9ea9824a47e14e783b79aefac098` | exact match |

Three of five match because verification review and the two check-in definitions were not changed in the QA extension. Eligibility differs after `mort_require_three_teen_verification_tracks`: it checks the QA triplet helper, locks Guardian-preference rows, supports optional Guardian approval, and returns an additional approval field. Acceptance differs after `guardian_application_decision_schema_rpc`: it requires QA-only `guardian_decision_status`, `guardian_decided_by`, and matching Guardian identity. These are behavior/schema changes, not formatting. They could conflict with production's existing three-track/application semantics and Guardian-read-only policy. Proposal 901 remains correctly guarded against the production function hashes. Do not weaken the guards or generate a QA replacement that silently drops the QA-only rules.

## Current runtime grants and RLS
Read-only inspection of production and isolated QA found: `job_applications` has RLS and FORCE RLS enabled; anon/authenticated have no table SELECT privilege; no SELECT policy is active for them; service_role retains SELECT. `get_my_job_applications(uuid)` is SECURITY DEFINER with empty search_path, EXECUTE denied to anon and granted to authenticated. Its Guardian ID mask text and current Guardian checks are present in both definitions. The actual isolated anonymous API returned 42501 for RPC and direct table access. Positive authenticated visibility remains untested because no synthetic accounts/fixtures exist.

The production/isolated direct-select migration source digest differs only because the isolated ledger payload has one trailing LF byte. The exact production and isolated payload hashes are listed above; executable statements match.

## Reconciliation plan and rollback safety
1. Preserve the existing hosted isolated project in place. It has 6 storage buckets (0 objects) and no Auth users, profiles, jobs, applications, assignments, Guardian links, verification cases, conversations, messages, notifications, or staff records. Do not reset it, delete migrations, or write ledger rows. The buckets and ten QA migrations are existing project state.
2. Before any future DDL or test writes on that project, make a verified encrypted snapshot of database schema/data/ledger, Auth users and relevant Auth config, Storage bucket metadata, and Storage object bytes/metadata. Save hashes/manifests outside the project and prove the snapshot is readable; database dump alone is not a Storage backup.
3. Keep the clean production baseline and QA extension as distinct environments. The existing disposable Docker baseline database `supabase_db_mort-proposals-local-20261102` currently reports PostgreSQL 17.6 and exactly 73 ledger entries through `20261102113314`; it contains both production Guardian mask and direct-SELECT migration records. The production hosted DB is 17.11; local Docker is same major but not exact minor/runtime clone. Prior fresh replay/compile evidence is in the execution checklist. Do not treat local ACL defaults as hosted-accurate until aligned.
4. Use that clean baseline for exact-production migration replay, proposal compilation, and pgTAP. Keep the hosted project as QA-extension only for tests that explicitly target its additional semantics. For a production-equivalent authenticated API matrix, create a new disposable QA project/branch only after cost approval; do not reconcile the existing one in-place.
5. Before any future isolated schema/data work, obtain a complete verified snapshot (database/schema/ledger, Auth users/config, Storage bucket definitions and object bytes), record checksums, and prove the export can be read. A database dump alone does not protect Storage bytes. Require exact SQL review and apply only to a new branch/clone, never the existing project.
6. Rollback is to abandon the newly created disposable branch/clone and retain the original isolated project plus its snapshot and logs. Do not reverse historical migrations, edit applied ledger rows, or restore over the original project. If a future test requires mutating existing QA state, stop until a non-destructive restore path is demonstrated. No such change is made by this report.

## Earlier validation snapshot — superseded by the final update below
- Read-only migration ledger comparisons: 73 production rows, 82 isolated rows, all migration names/hashes accounted for above.
- PostgreSQL 17.6 local baseline ledger: 73 entries from `20261026194801` through `20261102113314`; both mask/direct-SELECT migration rows present.
- `supabase-production/proposals/tests/20261102010500_job_application_direct_select_privacy.sql` ran transactionally and rolled back: 4/5 pgTAP assertions passed; service_role SELECT assertion failed in local baseline because its local grant is absent. Hosted production and isolated QA catalog checks both show service_role SELECT=true. Do not weaken that assertion; treat as local privilege-environment mismatch to resolve before relying on local test.
- Actual API anonymous checks against isolated project: `get_my_job_applications`, nested status-update, and direct `job_applications` read all denied with SQLSTATE 42501. Authenticated role tests were not run.
- Static migration, proposal, recovery, RLS/grant catalog and file-integrity checks are listed in the branch checklist. No hosted schema migration or data was changed.

Provider/synthetic-user prerequisites are described in `MORT_ISOLATED_QA_PROVISIONING_2026-11-02.md`. No provider is selected. Yoti publishes age and IDV sandbox flows with mocked outcomes; Persona and Veriff also provide integration simulations with provider-specific limitations. The published Yoti and Veriff document type lists do not identify school IDs, so school-ID support remains unconfirmed and requires written vendor confirmation before selection. No provider credentials, paid account, or test data was created.

## 2026-11-02 final validator and PostgreSQL 17.11 replay update

The earlier migration-parity failure for
`20260918032930_guardian_teen_summary_v1.sql` was a false positive. The
validator used the literal two-byte separator backslash + zero instead of the
NUL byte required by Git's blob hash. Correct byte calculations yield:

- Git NUL-byte SHA / `git hash-object`: `65455e7593dbcb51612f71303ba808063b43f6a6`.
- Old literal-backslash-zero SHA: `21eb6a0accd633b5fb92319b4062385a931899b6`.
- Read-only production migration ledger lookup for that version/name: no row.

The local SQL and expected hash were preserved. The parity validator now
hashes Git objects correctly and passes. There is no active production payload
for that September migration to compare, so this is not a production-ledger
content discrepancy.

A genuinely fresh, localhost-only Supabase PostgreSQL 17.11 image replayed the
73 production SQL files in order using byte-preserving Node streams. The local
source ledger is `73|20261026194801|20261102113314|73`. The five guarded
function hashes matched live production before proposal compilation. Proposal
compilation, local ACL and pgTAP results are in
`supabase-production/proposals/MORT_BACKEND_SECURITY_REMEDIATION_BACKLOG_2026-11-02.md`
and `docs/MORT-2.0-EXECUTION-CHECKLIST.md`.

This matches PostgreSQL 17.11 but not the complete hosted Supabase platform.
Bootstrap needed the empty Auth table's missing `email_confirmed_at` column,
local `postgres` creation permission on `storage`, and minimal
`storage.buckets`, `storage.objects`, and `storage.foldername` definitions
used by the MORT migration set. No Auth users, Storage objects, or production
data were copied. The first PowerShell text-stream replay was discarded after
it changed a curly apostrophe; only the subsequent byte-exact replay counts.
