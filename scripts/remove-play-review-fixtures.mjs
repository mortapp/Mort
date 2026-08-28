import { createClient } from '@supabase/supabase-js';

const url = 'https://rakjydmgwwgtdislanbt.supabase.co';
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!key) throw new Error('SUPABASE_SERVICE_ROLE_KEY is required and is never printed.');
const client = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });

let removed = 0;
for (let page = 1; page <= 20; page += 1) {
  const { data, error } = await client.auth.admin.listUsers({ page, perPage: 100 });
  if (error) throw error;
  const fixtures = data.users.filter((user) => user.user_metadata?.play_review_fixture === true);
  for (const user of fixtures) {
    const { error: deleteError } = await client.auth.admin.deleteUser(user.id, false);
    if (deleteError) throw deleteError;
    removed += 1;
  }
  if (data.users.length < 100) break;
}
process.stdout.write(`Removed ${removed} Play review fixture accounts.\n`);
