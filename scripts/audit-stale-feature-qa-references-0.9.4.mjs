import { serviceClient, withDatabase } from "./feature-qa-helpers.mjs";

const staleUsers = [];
for (let page = 1; ; page += 1) {
  const result = await serviceClient.auth.admin.listUsers({ page, perPage: 1000 });
  if (result.error) throw result.error;
  staleUsers.push(
    ...result.data.users.filter((user) =>
      /^qa-feature-[a-z0-9_-]+-[a-z0-9-]+@mort\.test$/i.test(user.email ?? ""),
    ),
  );
  if (result.data.users.length < 1000) break;
}

const quoteIdentifier = (value) => `"${value.replaceAll('"', '""')}"`;
const references = [];

if (staleUsers.length > 0) {
  await withDatabase(async (database) => {
    const constraints = await database.query(`
      select
        source_namespace.nspname as schema_name,
        source_table.relname as table_name,
        source_column.attname as column_name,
        constraint_record.conname as constraint_name,
        constraint_record.confdeltype as delete_action
      from pg_constraint constraint_record
      join pg_class source_table
        on source_table.oid = constraint_record.conrelid
      join pg_namespace source_namespace
        on source_namespace.oid = source_table.relnamespace
      cross join lateral unnest(constraint_record.conkey) with ordinality source_key(attnum, position)
      join pg_attribute source_column
        on source_column.attrelid = constraint_record.conrelid
       and source_column.attnum = source_key.attnum
      where constraint_record.contype = 'f'
        and constraint_record.confrelid = 'auth.users'::regclass
      order by source_namespace.nspname, source_table.relname, source_column.attname
    `);

    const userIds = staleUsers.map((user) => user.id);
    for (const constraint of constraints.rows) {
      const table = `${quoteIdentifier(constraint.schema_name)}.${quoteIdentifier(constraint.table_name)}`;
      const column = quoteIdentifier(constraint.column_name);
      const count = await database.query(
        `select count(*)::integer as row_count from ${table} where ${column} = any($1::uuid[])`,
        [userIds],
      );
      if (count.rows[0].row_count > 0) {
        references.push({
          schema: constraint.schema_name,
          table: constraint.table_name,
          column: constraint.column_name,
          delete_action: constraint.delete_action,
          row_count: count.rows[0].row_count,
        });
      }
    }
  });
}

console.log(
  JSON.stringify(
    {
      project_ref: "rakjydmgwwgtdislanbt",
      aggregate_only: true,
      strict_feature_qa_users: staleUsers.length,
      remaining_auth_user_references: references,
    },
    null,
    2,
  ),
);
