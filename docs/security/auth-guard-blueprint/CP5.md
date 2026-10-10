# CP5 — provider SDK session verification

Real pinned GoTrue plus installed Supabase AuthClient: valid accepted; actual globally revoked token rejected; fixture-signed expired negative rejected; service-role token rejected; fresh provider-issued session accepted afterward. Thirteen named assertions executed. No production helper is necessary for these verified getUser call patterns. The expired control was manually fixture-signed; it does not establish provider issuance or token-lifetime evidence.

Classification regression verifies 44 declared entrypoints and shared routing: 31 user, three user-plus-operations-secret and ten exclusions. Four tests include removal of all shared getUser checks and removal of each hybrid operations check. Missing verifier module RED preceded implementation; existing provider behavior required no fix. The ten excluded source blobs are hashed against CP4 and unchanged. Classification is a structural regression, not an executed request for every deployed Edge Function. No deployment or live configuration certification.

Protected mort-verify working changes remain untouched; exact committed-source classification is rerun from the disposable archive before push. Excluded worker/webhook/provider functions keep their existing caller authorization.

Self-audit: A1 no helper/auth architecture change; A2 immutable lock verified; A3 missing verifier RED, mutation negatives, actual SDK checks; A4 exact-HEAD rerun pending; A5 no thresholds changed; A6 committed scan pending; A7 owned synthetic account cleanup complete in initial provider test; A8 no historical runtime PASS inherited; A9 claim limited to tested SDK semantics and structural callers; A10 hosted/mail/production/artifacts untouched.
