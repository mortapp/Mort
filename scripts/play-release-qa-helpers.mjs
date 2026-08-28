import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { createClient } from '@supabase/supabase-js';

export const root = resolve(import.meta.dirname, '..');
export const projectUrl = 'https://rakjydmgwwgtdislanbt.supabase.co';

export function read(relative) {
  return readFileSync(resolve(root, relative), 'utf8');
}

export function assert(condition, message) {
  if (!condition) throw new Error(message);
}

export function pass(scope, message) {
  process.stdout.write(`[${scope}] PASS: ${message}\n`);
}

export function required(name) {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}

export function anonClient() {
  assert(required('EXPO_PUBLIC_SUPABASE_URL') === projectUrl, 'QA points to the wrong Supabase project.');
  return createClient(projectUrl, required('EXPO_PUBLIC_SUPABASE_ANON_KEY'), {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export function serviceClient() {
  return createClient(projectUrl, required('SUPABASE_SERVICE_ROLE_KEY'), {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export async function reviewClient(role) {
  const prefix = `PLAY_REVIEW_${role.toUpperCase()}`;
  const client = anonClient();
  const { data, error } = await client.auth.signInWithPassword({
    email: required(`${prefix}_EMAIL`),
    password: required(`${prefix}_PASSWORD`),
  });
  if (error || !data.user) throw new Error(`Could not authenticate the ${role} review fixture.`);
  return { client, user: data.user };
}
