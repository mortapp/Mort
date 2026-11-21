#!/usr/bin/env bash
# Run only on a disposable runner. Source and target both use real, local
# Supabase sessions. No production/QA data or credentials are accepted.
set -euo pipefail
umask 077
root="$(cd "$(dirname "$0")/../../.." && pwd)"
out="${DR_EVIDENCE_DIR:?Set a fresh evidence output directory}"
test ! -e "$out" || { echo "Refusing to reuse an evidence directory." >&2; exit 1; }
mkdir -m 700 "$out"
cd "$root"
key="$(openssl rand -base64 32)"
export MORT_BACKUP_ENCRYPTION_KEY="$key"

require_local_stack() {
  node --input-type=module - "$DB_URL" "$API_URL" <<'JS'
const [database, api] = process.argv.slice(2).map((value) => new URL(value));
const loopback = new Set(["localhost", "127.0.0.1"]);
if (database.protocol !== "postgresql:" || !loopback.has(database.hostname) ||
    database.pathname !== "/postgres" || database.search || database.hash ||
    api.protocol !== "http:" || !loopback.has(api.hostname) || api.username ||
    api.password || api.pathname !== "/" || api.search || api.hash) {
  throw new Error("Disaster recovery rehearsal requires local Supabase URLs.");
}
JS
}

started="$(date +%s)"
REPLICA_OUT="$out/source" bash scripts/qa/replica/build-and-test.sh
# Only source the environment emitted by the replica CLI in the fresh directory.
source "$out/source/replica.env"
require_local_stack
source_ready="$(date +%s)"
DR_SOURCE=local DR_LOCAL_DB_URL="$DB_URL" DR_LOCAL_API_URL="$API_URL" \
  SUPABASE_SERVICE_ROLE_KEY="$SERVICE_ROLE_KEY" DR_OUT="$out/sealed" \
  DR_SUMMARY="$out/backup-summary.json" node scripts/dr/dr-full-backup.mjs
shopt -s nullglob
backups=("$out"/sealed/*.enc)
test "${#backups[@]}" -eq 1
sealed="$(date +%s)"

BUILD_ONLY=1 REPLICA_OUT="$out/target" bash scripts/qa/replica/build-and-test.sh
source "$out/target/replica.env"
require_local_stack
DB=supabase_db_mort-production-replica
counts="$(docker exec "$DB" psql -X -U postgres -v ON_ERROR_STOP=1 -Atc \
  'select (select count(*) from auth.users), (select count(*) from storage.objects)')"
test "$counts" = '0|0' || { echo "Restore refused: the replica is not empty." >&2; exit 1; }
target_ready="$(date +%s)"
DR_TARGET=local DR_LOCAL_DB_URL="$DB_URL" DR_LOCAL_API_URL="$API_URL" \
  SUPABASE_SERVICE_ROLE_KEY="$SERVICE_ROLE_KEY" SUPABASE_ANON_KEY="$ANON_KEY" \
  DR_EXPECTED_SOURCE_REF=local-replica DR_BACKUP="${backups[0]}" \
  DR_VERIFY_ACTORS="$out/source/actors.json" DR_REPORT="$out/restore-report.json" \
  node scripts/dr/dr-full-restore.mjs
restored="$(date +%s)"

node --input-type=module - "$out" "$started" "$source_ready" "$sealed" "$target_ready" "$restored" <<'JS'
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
const [out, ...marks] = process.argv.slice(2);
const [started, source, sealed, target, restored] = marks.map(Number);
const summary = JSON.parse(readFileSync(join(out, "backup-summary.json"), "utf8"));
const report = JSON.parse(readFileSync(join(out, "restore-report.json"), "utf8"));
if (!report.pass || report.source !== "local-replica" || report.target !== "local-replica" ||
    summary.projectRef !== "local-replica" || summary.authUsers < 1 ||
    summary.privateTables < 1 || summary.objects < 1 || summary.objectBytes < 1) {
  throw new Error("The local rehearsal did not exercise all required data scopes.");
}
writeFileSync(join(out, "fixture-timings.json"), JSON.stringify({
  source_build_seconds: source - started,
  backup_seconds: sealed - source,
  target_rebuild_seconds: target - sealed,
  restore_and_verification_seconds: restored - target,
  note: "Disposable fixture measurements, not production RPO/RTO",
}, null, 2));
JS
