import { readFile } from "node:fs/promises";

const dataSource = await readFile(new URL("../lib/data.ts", import.meta.url), "utf8");
const postJobSource = await readFile(new URL("../app/adult/post-job.tsx", import.meta.url), "utf8");
const adminSource = await readFile(new URL("../app/admin/jobs.tsx", import.meta.url), "utf8");
const createJobSource = dataSource.slice(dataSource.indexOf("export async function createJob"), dataSource.indexOf("export async function applyToJob"));

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

assert(!/from\("jobs"\)\.insert|from\("jobs"\)\.update/.test(dataSource), "website must not write jobs directly");
assert(createJobSource.includes('supabase.rpc("save_job_draft_or_publish"'), "website createJob must use save_job_draft_or_publish");
assert(dataSource.includes('supabase.rpc("admin_moderate_job"'), "website moderation must use admin_moderate_job");
assert(createJobSource.includes("p_client_request_id: newClientRequestId()"), "website job publishing must be idempotent");
assert(dataSource.includes('p_action: "remove"'), "website removal must use the admin remove action");
assert(!createJobSource.includes("poster_id: input.posterId"), "website must not send a client-controlled poster_id");
assert(!createJobSource.includes('status: "open"'), "website must not send a client-controlled status");
assert(postJobSource.includes("createJob"), "adult posting screen should use the guarded helper");
assert(adminSource.includes("updateJobStatus"), "admin jobs screen should use the guarded moderation helper");

console.log("[qa-reference-website-job-write-contract] PASS");
