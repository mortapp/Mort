import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { assertQa, qaLog, withDatabase } from "./feature-qa-helpers.mjs";
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

await withDatabase(async (database) => {
  const table = await database.query(`
    select c.relrowsecurity, c.relforcerowsecurity
    from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='private' and c.relname='financial_documents'
  `);
  assertQa(table.rows[0]?.relrowsecurity === true, "financial_documents must enable RLS");
  assertQa(table.rows[0]?.relforcerowsecurity === true, "financial_documents must force RLS");

  const trigger = await database.query(`
    select pg_get_triggerdef(t.oid) as definition
    from pg_trigger t join pg_class c on c.oid=t.tgrelid
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='private' and c.relname='financial_documents' and not t.tgisinternal
  `);
  assertQa(trigger.rows.some((row) => String(row.definition).includes("financial_documents_immutable")),
    "financial document immutability trigger is missing");

  const issue = await database.query(`
    select pg_get_functiondef(to_regprocedure(
      'public.stripe_server_issue_financial_document_v1(text,uuid,text,text,uuid,uuid,uuid,integer,text,text,text,jsonb,jsonb)'
    )) as definition
  `);
  const issueSource = String(issue.rows[0]?.definition ?? "");
  for (const required of [
    "private.require_stripe_service_role()","financial_document_privacy_violation",
    "legal_name","client_secret","webhook_secret",
  ]) assertQa(issueSource.includes(required), `document issuer missing ${required}`);

  const read = await database.query(`
    select pg_get_functiondef(to_regprocedure('public.get_my_financial_document_v1(text)')) as definition
  `);
  assertQa(String(read.rows[0]?.definition ?? "").includes("owner_id = auth.uid()"),
    "document lookup is not caller-bound");

  const uniqueIndex = await database.query(`
    select indexdef from pg_indexes
    where schemaname='private' and tablename='financial_documents' and indexdef ilike '%unique%'
  `);
  assertQa(uniqueIndex.rows.some((row) =>
    /owner_id.*source_type.*source_id.*document_type/i.test(String(row.indexdef))),
    "financial document source idempotency uniqueness is missing");
});

const shared = await readFile(path.join(root,"supabase","functions","_shared","stripe_financial_reads.ts"),"utf8");
assertQa(shared.includes("sensitiveKeyPattern"), "document Edge DTO redaction is missing");
assertQa(shared.includes("minimizeDocument"), "document Edge DTO minimization is missing");
qaLog("stripe-financial-documents",
  "documents are immutable/idempotent, caller-bound on read, forced-RLS, and minimized at the Edge boundary");
