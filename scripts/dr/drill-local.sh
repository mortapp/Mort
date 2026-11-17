#!/usr/bin/env bash
# End-to-end MORT disaster-recovery drill, entirely local and disposable:
#   1. build a production replica and populate it through real user journeys
#      (GoTrue signups, Storage uploads, staff roles) - no SQL-created users
#   2. full encrypted backup (auth + private + public + Storage bytes)
#   3. DESTROY the replica (all Docker volumes) and build a fresh empty target
#      from the production-baseline recovery set
#   4. restore, then verify hashes, FKs, sequences, bytes, original-password
#      sign-in and RLS-scoped reads for every restored user
#   5. negative checks: wrong key, tampered file, production target refused
# Never connects to a hosted project.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${DR_DRILL_OUT:-$ROOT/.dr-drill-out}"
rm -rf "$OUT"; mkdir -p "$OUT/source" "$OUT/target" "$OUT/backup"
cd "$ROOT"
T0=$(date +%s)

echo "== 1. source: production replica populated by fresh-user journeys"
REPLICA_OUT="$OUT/source" scripts/qa/replica/build-and-test.sh >"$OUT/source.log" 2>&1 || { tail -30 "$OUT/source.log"; exit 1; }
tail -2 "$OUT/source.log"
# shellcheck disable=SC1091
. "$OUT/source/replica.env"
MORT_BACKUP_ENCRYPTION_KEY="$(openssl rand -base64 32)"; export MORT_BACKUP_ENCRYPTION_KEY

echo "== 2. full encrypted backup"
T1=$(date +%s)
DR_SOURCE=local DR_LOCAL_DB_URL="$DB_URL" DR_LOCAL_API_URL="$API_URL" SUPABASE_SERVICE_ROLE_KEY="$SERVICE_ROLE_KEY" \
  DR_OUT="$OUT/backup" DR_SUMMARY="$OUT/backup-summary.json" node scripts/dr/dr-full-backup.mjs
BACKUP="$(ls "$OUT"/backup/*.enc)"
if grep -q -- "$(node -e 'const a=require(process.argv[1]);console.log(Object.values(a)[0].email)' "$OUT/source/actors.json")" "$BACKUP"; then
  echo "FAIL backup file contains plaintext email"; exit 1
fi
echo "PASS backup file is ciphertext (no plaintext email)"

echo "== 3. destroy source, build fresh empty target"
T2=$(date +%s)
MORT_PASSWORD_ATTESTATION_SECRET="$(openssl rand -hex 32)"; export MORT_PASSWORD_ATTESTATION_SECRET
BUILD_ONLY=1 REPLICA_OUT="$OUT/target" scripts/qa/replica/build-and-test.sh >"$OUT/target.log" 2>&1 || { tail -30 "$OUT/target.log"; exit 1; }
# shellcheck disable=SC1091
. "$OUT/target/replica.env"
USERS=$(docker exec supabase_db_mort-production-replica psql -U postgres -At -c "select count(*) from auth.users")
OBJS=$(docker exec supabase_db_mort-production-replica psql -U postgres -At -c "select count(*) from storage.objects")
[ "$USERS" = 0 ] && [ "$OBJS" = 0 ] || { echo "FAIL target not empty (users=$USERS objects=$OBJS)"; exit 1; }
echo "PASS target is empty (auth.users=0, storage.objects=0)"

common=(DR_LOCAL_DB_URL="$DB_URL" DR_LOCAL_API_URL="$API_URL" SUPABASE_SERVICE_ROLE_KEY="$SERVICE_ROLE_KEY" SUPABASE_ANON_KEY="$ANON_KEY" DR_EXPECTED_SOURCE_REF=local-replica)

echo "== 5a. negative checks (before restore)"
neg() { local name="$1"; shift; if env "$@" node scripts/dr/dr-full-restore.mjs >"$OUT/neg.log" 2>&1; then echo "FAIL $name accepted"; exit 1; else echo "PASS $name rejected: $(grep -oE 'dr_[a-z_]+|Unsupported state[^\n]*|backup_[a-z_]+' "$OUT/neg.log" | head -1)"; fi; }
neg "wrong encryption key" "${common[@]}" DR_TARGET=local DR_BACKUP="$BACKUP" MORT_BACKUP_ENCRYPTION_KEY="$(openssl rand -base64 32)"
cp "$BACKUP" "$OUT/tampered.enc"; cp "$BACKUP.sha256" "$OUT/tampered.enc.sha256"; printf 'x' >>"$OUT/tampered.enc"
neg "tampered backup file" "${common[@]}" DR_TARGET=local DR_BACKUP="$OUT/tampered.enc"
neg "production as restore target" "${common[@]}" DR_TARGET=hosted DR_TARGET_REF=jxbnrkasktbhtiujkhay DR_CONFIRM_TARGET=jxbnrkasktbhtiujkhay DR_TARGET_DB_PASSWORD=x DR_BACKUP="$BACKUP"
neg "deleted project as restore target" "${common[@]}" DR_TARGET=hosted DR_TARGET_REF=rakjydmgwwgtdislanbt DR_CONFIRM_TARGET=rakjydmgwwgtdislanbt DR_TARGET_DB_PASSWORD=x DR_BACKUP="$BACKUP"
neg "unconfirmed hosted target" "${common[@]}" DR_TARGET=hosted DR_TARGET_REF=abcdefghijklmnopqrst DR_TARGET_DB_PASSWORD=x DR_BACKUP="$BACKUP"
neg "non-loopback local target" "${common[@]}" DR_TARGET=local DR_LOCAL_DB_URL=postgresql://postgres:x@db.example.com:5432/postgres DR_BACKUP="$BACKUP"

echo "== 4. restore + verify"
T3=$(date +%s)
env "${common[@]}" DR_TARGET=local DR_BACKUP="$BACKUP" DR_VERIFY_ACTORS="$OUT/source/actors.json" DR_REPORT="$OUT/restore-report.json" \
  node scripts/dr/dr-full-restore.mjs | tee "$OUT/restore.log"
T4=$(date +%s)

echo "== 6. post-restore authorization suite on the restored target"
# Fresh users + adversarial checks against restored data and policies.
export PASSWORD_GUARD_PORT=55399 PASSWORD_GUARD_URL="http://127.0.0.1:55399/password-guard"
deno run --no-config --node-modules-dir=none --allow-net --allow-env scripts/qa/replica/password-guard-serve.ts >"$OUT/password-guard.log" 2>&1 &
GUARD_PID=$!; trap 'kill $GUARD_PID 2>/dev/null || true' EXIT
for _ in $(seq 1 60); do grep -q "password-guard on" "$OUT/password-guard.log" && break; sleep 0.5; done
set +e
ACTORS_OUT="$OUT/post-actors.json" AUTHZ_RESULTS="$OUT/post-authz.json" JOURNEY_RESULTS="$OUT/post-journeys.json" node scripts/qa/replica/journeys.mjs >"$OUT/post-journeys.log" 2>&1; PJ=$?
ACTORS_OUT="$OUT/post-actors.json" AUTHZ_RESULTS="$OUT/post-authz.json" node scripts/qa/replica/authz.mjs >"$OUT/post-authz.log" 2>&1; PA=$?
set -e
tail -1 "$OUT/post-journeys.log"; tail -1 "$OUT/post-authz.log"
cat >"$OUT/timings.json" <<EOF
{"source_build_and_journeys_s": $((T1-T0)), "backup_s": $((T2-T1)), "target_rebuild_s": $((T3-T2)), "restore_and_verify_s": $((T4-T3))}
EOF
cat "$OUT/timings.json"
[ "$PJ" = 0 ] && [ "$PA" = 0 ] || { echo "FAIL post-restore suites"; exit 1; }
echo "DR drill: PASS"
