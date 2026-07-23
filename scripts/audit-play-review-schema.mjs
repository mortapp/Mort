import pg from 'pg';

const password = process.env.SUPABASE_DB_PASSWORD;
if (!password) {
  throw new Error('SUPABASE_DB_PASSWORD is required and is never printed.');
}

const tables = [
  'partner_organizations',
  'partner_staff',
  'partner_permissions',
  'pilot_enrollments',
  'job_contracts',
  'job_contract_versions',
  'job_contract_acceptances',
  'job_safety_agreements',
  'job_arrival_handshakes',
  'job_completion_assertions',
  'job_payment_obligations',
  'completion_evidence_records',
  'payment_confirmation_records',
  'payment_disputes',
  'reports',
  'blocks',
  'account_deletion_requests',
  'safety_reports',
  'job_completion_events',
];

const client = new pg.Client({
  host: 'db.rakjydmgwwgtdislanbt.supabase.co',
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password,
  ssl: { rejectUnauthorized: false },
});

await client.connect();
try {
  const { rows } = await client.query(
    `select table_name, column_name, data_type, is_nullable, column_default
     from information_schema.columns
     where table_schema = 'public' and table_name = any($1)
     order by table_name, ordinal_position`,
    [tables],
  );
  for (const row of rows) {
    process.stdout.write(
      [
        row.table_name,
        row.column_name,
        row.data_type,
        row.is_nullable,
        row.column_default ?? '',
      ].join('|') + '\n',
    );
  }
} finally {
  await client.end();
}
