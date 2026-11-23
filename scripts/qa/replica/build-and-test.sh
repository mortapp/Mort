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

# GitHub-hosted runners can retain another local Supabase stack or run jobs
# concurrently on the same host. Allocate isolated names and host ports for
# the disposable copy, independent of the checked-in port defaults.
REPLICA_WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/mort-production-replica.XXXXXX")"
REPLICA_RUN_ID="mort-replica-$(basename "$REPLICA_WORKDIR" | cut -d. -f2 | tr '[:upper:]' '[:lower:]')"
cleanup_replica() {
  (cd "$REPLICA_WORKDIR" && supabase stop --no-backup >/dev/null 2>&1) || true
  rm -rf "$REPLICA_WORKDIR"
}
trap cleanup_replica EXIT
cp -a "$PROJ/." "$REPLICA_WORKDIR/"
python3 - "$REPLICA_WORKDIR/supabase/config.toml" "$REPLICA_RUN_ID" <<'PY'
from pathlib import Path
import re
import socket
import sys
import tomllib

path, project_id = Path(sys.argv[1]), sys.argv[2]
addresses = [("api", "port"), ("db", "port"), ("db", "shadow_port"),
             ("db.pooler", "port"), ("studio", "port"), ("inbucket", "port")]
sockets = [socket.socket() for _ in addresses]
try:
    for sock in sockets:
        sock.bind(("0.0.0.0", 0))
    ports = dict(zip(addresses, (sock.getsockname()[1] for sock in sockets)))
    changes = {**ports, ("", "project_id"): f'"{project_id}"'}
    section = ""
    output = []
    for line in path.read_text().splitlines(keepends=True):
        heading = re.match(r"^\[([^\]]+)\]\s*$", line)
        if heading:
            section = heading[1]
        field = re.match(r"^([a-z_][a-z_0-9]*)\s*=", line)
        if field and (section, field[1]) in changes:
            key = field[1]
            line = f"{key} = {changes.pop((section, key))}\n"
        output.append(line)
    if changes:
        raise SystemExit(f"Missing replica config fields: {sorted(changes)}")
    result = "".join(output)
    parsed = tomllib.loads(result)
    for (key, attribute), port in ports.items():
        table = parsed
        for part in key.split("."):
            table = table[part]
        if table[attribute] != port:
            raise SystemExit(f"Replica port was not assigned: {key}.{attribute}")
    path.write_text(result)
finally:
    for sock in sockets:
        sock.close()
PY
cd "$REPLICA_WORKDIR"
supabase start -x studio,imgproxy,logflare,vector,supavisor,edge-runtime,postgres-meta >"$OUT/start.log" 2>&1
supabase status -o env 2>/dev/null | sed 's/^/export /' >"$OUT/replica.env"
# shellcheck disable=SC1091
. "$OUT/replica.env"
DB="supabase_db_$REPLICA_RUN_ID"

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
  echo "== staff-role PR migration and live-session matrix (disposable replica only)"
  psqlf "$ROOT/supabase/migrations/20261122133500_harden_staff_role_active_status.sql" -1
  export MORT_REPLICA_STAFF_ROLE_MATRIX=1
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
