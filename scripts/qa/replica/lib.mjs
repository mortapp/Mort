// Shared helpers for MORT production-replica journey and adversarial tests.
// These helpers only talk to a LOCAL Supabase stack (the production replica).
// They refuse to run against any non-local API URL.
import { createClient } from '@supabase/supabase-js';
import { randomUUID } from 'node:crypto';

export const API_URL = process.env.API_URL;
export const ANON_KEY = process.env.ANON_KEY;
export const MAILPIT_URL = process.env.MAILPIT_URL;

export function assertLocal() {
  for (const [name, value] of [['API_URL', API_URL], ['MAILPIT_URL', MAILPIT_URL]]) {
    if (!value) throw new Error(`${name} is required`);
    const host = new URL(value).hostname;
    if (!['127.0.0.1', 'localhost', '::1'].includes(host)) {
      throw new Error(`${name} must point at a local replica, got ${host}`);
    }
  }
  if (!ANON_KEY) throw new Error('ANON_KEY is required');
}

export const results = [];
export function record(area, name, pass, detail = '') {
  results.push({ area, name, pass: Boolean(pass), detail: typeof detail === 'string' ? detail : JSON.stringify(detail) });
  const mark = pass ? 'PASS' : 'FAIL';
  console.log(`${mark} [${area}] ${name}${detail ? ` -- ${typeof detail === 'string' ? detail : JSON.stringify(detail)}` : ''}`);
}

export function anonClient() {
  return createClient(API_URL, ANON_KEY, { auth: { persistSession: false, autoRefreshToken: false } });
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function confirmationLink(email) {
  for (let i = 0; i < 40; i += 1) {
    const res = await fetch(`${MAILPIT_URL}/api/v1/search?query=${encodeURIComponent(`to:"${email}"`)}`);
    const body = await res.json();
    const msg = body.messages?.[0];
    if (msg) {
      const full = await (await fetch(`${MAILPIT_URL}/api/v1/message/${msg.ID}`)).json();
      const text = `${full.Text ?? ''}\n${full.HTML ?? ''}`;
      const m = text.match(/https?:\/\/[^\s"'<>]+\/auth\/v1\/verify\?[^\s"'<>]+/);
      if (m) return m[0].replace(/&amp;/g, '&');
    }
    await sleep(250);
  }
  throw new Error(`no confirmation email for ${email}`);
}

// Normal journey: public signup (as the corrected client sends it) + email link.
export async function signUpAndConfirm({ email, password, dob, displayName }) {
  const client = anonClient();
  const { data, error } = await client.auth.signUp({
    email,
    password,
    options: { data: { date_of_birth: dob, display_name: displayName } },
  });
  if (error) throw new Error(`signup ${email}: ${error.message}`);
  if (data.session) throw new Error('replica must require email confirmation');
  const link = await confirmationLink(email);
  const res = await fetch(link, { redirect: 'manual' });
  if (![200, 302, 303].includes(res.status)) throw new Error(`verify link status ${res.status}`);
  const signed = anonClient();
  const s = await signed.auth.signInWithPassword({ email, password });
  if (s.error) throw new Error(`signin ${email}: ${s.error.message}`);
  return { client: signed, id: s.data.user.id, email, password };
}

export async function rpc(client, fn, args = {}) {
  const { data, error } = await client.rpc(fn, args);
  return { data, error };
}

export function okData(r) {
  return !r.error && r.data && (typeof r.data !== 'object' || r.data.ok !== false);
}

export const reqId = () => randomUUID();
export { randomUUID };

// Minimal valid JPEG bytes (synthetic, contains no personal data).
export const JPEG = Buffer.from(
  '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AKp//2Q==',
  'base64',
);
export const PNG = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=',
  'base64',
);
