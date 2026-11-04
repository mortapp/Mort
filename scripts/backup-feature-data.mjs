import { createHash } from "node:crypto";
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, isAbsolute, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import pg from "pg";

const projectRef = process.env.MORT_BACKUP_PROJECT_REF || "jxbnrkasktbhtiujkhay";
const backupApproved = process.env.MORT_BACKUP_APPROVED === "true";
const storageConfirmed = process.env.MORT_BACKUP_STORAGE_CONFIRMED === "encrypted-at-rest";
const requestedBackupDir = process.env.MORT_BACKUP_OUTPUT_DIR;
const password = process.env.SUPABASE_DB_PASSWORD;

if (projectRef !== "jxbnrkasktbhtiujkhay" || !backupApproved || !storageConfirmed || !requestedBackupDir) {
  throw new Error("Production data snapshot blocked. Set the production project ref, MORT_BACKUP_APPROVED=true, MORT_BACKUP_STORAGE_CONFIRMED=encrypted-at-rest, and an external encrypted MORT_BACKUP_OUTPUT_DIR after completing issue #57.");
}
if (!password) {
  throw new Error("Set SUPABASE_DB_PASSWORD before creating the remote data snapshot.");
}

const client = new pg.Client({
  host: `db.${projectRef}.supabase.co`,
  port: 5432,
  database: "postgres",
  user: "postgres",
  password,
  ssl: { rejectUnauthorized: false },
});

const quoteIdentifier = (value) => `"${value.replaceAll('"', '""')}"`;

await client.connect();
const snapshot = {
  projectRef,
  generatedAt: new Date().toISOString(),
  handling: "Private local backup. Exclude from source archives and logs.",
  tables: {},
};

try {
  const relations = await client.query(`
    select n.nspname as schema_name, c.relname as table_name
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where c.relkind in ('r', 'p')
      and (
        n.nspname = 'public'
        or (n.nspname = 'storage' and c.relname in ('buckets', 'objects'))
      )
    order by n.nspname, c.relname
  `);

  for (const relation of relations.rows) {
    const key = `${relation.schema_name}.${relation.table_name}`;
    const qualified = `${quoteIdentifier(relation.schema_name)}.${quoteIdentifier(relation.table_name)}`;
    const rows = await client.query(`select to_jsonb(source_row) as value from ${qualified} source_row`);
    snapshot.tables[key] = rows.rows.map((row) => row.value);
  }
} finally {
  await client.end();
}

const repoRoot = dirname(dirname(fileURLToPath(import.meta.url)));
const backupDir = resolve(requestedBackupDir);
const relativeToRepo = relative(repoRoot, backupDir);
if (!isAbsolute(requestedBackupDir) || relativeToRepo === "" || (!relativeToRepo.startsWith("..") && !isAbsolute(relativeToRepo))) {
  throw new Error("MORT_BACKUP_OUTPUT_DIR must be an absolute path outside the repository.");
}
mkdirSync(backupDir, { recursive: true, mode: 0o700 });
const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
const outputPath = join(backupDir, `remote-feature-data-${projectRef}-${timestamp}.json`);
const body = `${JSON.stringify(snapshot, null, 2)}\n`;
writeFileSync(outputPath, body, { encoding: "utf8", mode: 0o600 });

const rowCount = Object.values(snapshot.tables).reduce((sum, rows) => sum + rows.length, 0);
const sha256 = createHash("sha256").update(body).digest("hex").toUpperCase();
console.log(`[backup-feature-data] Project ref: ${projectRef}`);
console.log(`[backup-feature-data] Snapshot: ${outputPath}`);
console.log(`[backup-feature-data] Tables=${Object.keys(snapshot.tables).length}, rows=${rowCount}, SHA-256=${sha256}`);
