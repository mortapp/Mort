#!/usr/bin/env bash
# Build a LOCAL replica of the MORT production database (catalog parity with
# jxbnrkasktbhtiujkhay as of 2026-11-16), prove parity, apply production-
# baseline migrations awaiting approval, and run fresh-user journeys plus
# adversarial authorization tests through the public Supabase APIs.
#
# Never points at a hosted project. Requires Docker + Supabase CLI >= 2.122.
#
#   scripts/qa/replica/build-and-test.sh            # parity + pending migrations + tests
#   PRE_FIX=1 scripts/qa/replica/build-and-test.sh  # parity + tests WITHOUT pending migrations
#   RUN_GUARDIAN_CONSENT_DRAFT=1 scripts/qa/replica/build-and-test.sh  # opt-in unapproved draft
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
REC="$ROOT/supabase/production-baseline-recovery"
PROJ="$ROOT/supabase/production-replica"
OUT="${REPLICA_OUT:-$ROOT/.replica-out}"
if [ "${RUN_GUARDIAN_CONSENT_DRAFT:-0}" = 1 ] && [ "${PRE_FIX:-0}" = 1 ]; then
  echo "The guardian consent draft requires the reviewed replica baseline."
  exit 1
fi
mkdir -p "$OUT"

cd "$PROJ"
supabase stop --no-backup >/dev/null 2>&1 || true
supabase start -x studio,imgproxy,logflare,vector,supavisor,edge-runtime,postgres-meta >"$OUT/start.log" 2>&1
supabase status -o env 2>/dev/null | sed 's/^/export /' >"$OUT/replica.env"
# shellcheck disable=SC1091
. "$OUT/replica.env"
DB="supabase_db_mort-production-replica"

psqlf() { docker cp "$1" "$DB:/tmp/in.sql" && docker exec "$DB" psql -U postgres -v ON_ERROR_STOP=1 -q ${2:-} -f /tmp/in.sql >>"$OUT/build.log" 2>&1 || { echo "FAILED applying $1"; tail -20 "$OUT/build.log"; exit 1; }; }

echo "== baseline schema (2026-11-12 pg_dump)"; psqlf "$REC/production-baseline-2026-11-12.sql"
echo "== storage buckets + policies";          psqlf "$REC/storage-policies-2026-11-12.sql"
echo "== production ledger 2026-11-13..15 (exact statements)"
for f in $(ls "$REC/ledger-2026-11-13-to-2026-11-15" | sort); do psqlf "$REC/ledger-2026-11-13-to-2026-11-15/$f" -1; done
echo "== production privileges";               psqlf "$REC/production-acl-2026-11-16.sql" -1
echo "== production config rows (no Stripe rows)"; psqlf "$REC/production-config-rows-2026-11-16.sql" -1
echo "== MORT triggers on auth.users";         psqlf "$REC/auth-triggers-2026-11-16.sql" -1

echo "== catalog fingerprint vs production"
docker cp "$ROOT/scripts/qa/replica/fingerprint.sql" "$DB:/tmp/fp.sql"
docker exec "$DB" psql -U postgres -At -F' ' -f /tmp/fp.sql >"$OUT/replica-fingerprint.txt"
if ! diff -u "$ROOT/scripts/qa/replica/production-fingerprint-2026-11-16.txt" "$OUT/replica-fingerprint.txt"; then
  echo "Replica does not match the recorded production fingerprint"; exit 1
fi
echo "parity: identical"

if [ "${PRE_FIX:-0}" != "1" ]; then
  while read -r m; do
    [ -z "$m" ] && continue
    echo "== pending production-baseline migration: $m"
    psqlf "$ROOT/supabase/production-baseline-migrations/$m"
  done <"$ROOT/supabase/production-baseline-migrations/PENDING_PRODUCTION_APPROVAL.txt"
fi

if [ "${RUN_GUARDIAN_CONSENT_DRAFT:-0}" = 1 ]; then
  echo "== disposable-replica-only teen guardian consent draft"
  psqlf "$ROOT/supabase/production-baseline-migrations/drafts/teen_guardian_consent_v1.sql"
fi

cd "$ROOT"
export ACTORS_OUT="$OUT/actors.json" JOURNEY_RESULTS="$OUT/journeys.json" AUTHZ_RESULTS="$OUT/authz.json"
set +e
node scripts/qa/replica/journeys.mjs | tee "$OUT/journeys.log"; J=${PIPESTATUS[0]}
node scripts/qa/replica/authz.mjs | tee "$OUT/authz.log"; A=${PIPESTATUS[0]}
set -e
node -e '
const j=require(process.argv[1]), a=require(process.argv[2]);
const f=[...j,...a].filter(r=>!r.pass);
console.log(`journeys ${j.length-j.filter(r=>!r.pass).length}/${j.length}, authz ${a.length-a.filter(r=>!r.pass).length}/${a.length}`);
process.exit(f.length?1:0);' "$OUT/journeys.json" "$OUT/authz.json"
[ "$J" = 0 ] && [ "$A" = 0 ]

if [ "${RUN_ACCOUNT_DELETION:-0}" = 1 ] && [ "${PRE_FIX:-0}" != 1 ]; then
  # Entirely standalone and short-lived, using this replica's service key.
  # The test client additionally rejects any non-loopback endpoint.
  export SUPABASE_URL="${API_URL:?local API_URL is required}"
  export SUPABASE_SERVICE_ROLE_KEY="${SERVICE_ROLE_KEY:?local SERVICE_ROLE_KEY is required}"
  export ACCOUNT_DELETION_WORKER_SECRET="$(openssl rand -hex 32)"
  export MORT_LOCAL_DELETION_WORKER_URL="http://127.0.0.1:8000"
  deno run --no-config --lock=deno.lock --frozen --node-modules-dir=none \
    --allow-env --allow-net supabase/functions/account-deletion-processor/index.ts \
    >"$OUT/account-deletion-worker.log" 2>&1 &
  WORKER_PID=$!
  trap 'kill "$WORKER_PID" 2>/dev/null || true' EXIT
  ready_status="$(curl --silent --show-error --max-time 2 --retry 10 --retry-connrefused \
    -o /dev/null -w '%{http_code}' "$MORT_LOCAL_DELETION_WORKER_URL")"
  [ "$ready_status" = "405" ]
  node scripts/qa/replica/account-deletion.mjs | tee "$OUT/account-deletion.log"
fi
