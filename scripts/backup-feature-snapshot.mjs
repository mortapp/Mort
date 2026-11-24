// Shared feature-data snapshot logic. Used by the production backup
// (backup-feature-data.mjs) and by the local restore drill
// (restore-drill-local.mjs) so the drill exercises the exact code path that
// produces real backups.

export const quoteIdentifier = (value) => `"${String(value).replaceAll('"', '""')}"`;

// Scope of the feature-data snapshot. Keep in sync with the restore drill's
// coverage report: anything outside this scope is NOT captured by the
// feature-data backup.
export const featureSnapshotRelationsSql = `
  select n.nspname as schema_name, c.relname as table_name
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where c.relkind in ('r', 'p')
    and (
      n.nspname = 'public'
      or (n.nspname = 'storage' and c.relname in ('buckets', 'objects'))
    )
  order by n.nspname, c.relname
`;

export async function collectFeatureDataSnapshot(client, { projectRef, handling }) {
  const snapshot = {
    projectRef,
    generatedAt: new Date().toISOString(),
    handling: handling ?? "Private local backup. Exclude from source archives and logs.",
    tables: {},
  };
  const relations = await client.query(featureSnapshotRelationsSql);
  for (const relation of relations.rows) {
    const key = `${relation.schema_name}.${relation.table_name}`;
    const qualified = `${quoteIdentifier(relation.schema_name)}.${quoteIdentifier(relation.table_name)}`;
    const rows = await client.query(`select to_jsonb(source_row) as value from ${qualified} source_row`);
    snapshot.tables[key] = rows.rows.map((row) => row.value);
  }
  return snapshot;
}
