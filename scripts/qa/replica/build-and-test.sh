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
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
REC="$ROOT/supabase/production-baseline-recovery"
PROJ="$ROOT/supabase/production-replica"
OUT="${REPLICA_OUT:-$ROOT/.replica-out}"
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
    if [ "$m" = "20261121170000_job_execution_gate_accepts_verified_status.sql" ]; then
      regression="$ROOT/supabase/production-baseline-tests/job_execution_gate_verified_status.test.sql"
      rollback="$ROOT/supabase/production-baseline-recovery/20261121170000_job_execution_gate.rollback.sql"
      echo "== job gate verification-state regression and rollback rehearsal"
      psqlf "$ROOT/supabase/production-baseline-migrations/$m" -1
      psqlf "$regression" -1
      psqlf "$rollback" -1
      psqlf "$ROOT/supabase/production-baseline-migrations/$m" -1
      psqlf "$regression" -1
      echo "job gate migration, rollback, and re-apply: passed"
    else
      psqlf "$ROOT/supabase/production-baseline-migrations/$m"
    fi
  done <"$ROOT/supabase/production-baseline-migrations/PENDING_PRODUCTION_APPROVAL.txt"
fi

# Restore rehearsals need the same migrations as the source, on a target
# with no Auth users, feature rows, or Storage uploads seeded by the journeys.
if [ "${BUILD_ONLY:-0}" = "1" ]; then
  echo "replica schema ready; journey data not seeded"
  exit 0
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
