import { readFile } from "node:fs/promises";
import { join } from "node:path";

import {
  assertQa,
  qaLog,
  serviceClient,
  withDatabase,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const root = process.cwd();

async function queryAs(database, userId, sql, params = []) {
  await database.query(
    "select set_config('request.jwt.claim.sub', $1, true), set_config('request.jwt.claim.role', 'authenticated', true)",
    [userId],
  );
  await database.query("set local role authenticated");
  try {
    return await database.query(sql, params);
  } finally {
    await database.query("reset role");
  }
}

async function insertSyntheticPublishedLegalVersion(database, suffix, materialRevision = true) {
  const document = await database.query(
    `
      insert into public.legal_documents (
        document_key, title, document_category, publication_status
      ) values ($1, 'Synthetic QA clickwrap document - not legal terms', 'synthetic_qa', 'published')
      returning id
    `,
    [`synthetic_qa_${suffix}`],
  );
  const content = `Synthetic QA clickwrap content ${suffix}. This record exists only inside a rollback-only database test. It is not attorney reviewed, is not legally approved, is not shown as MORT terms, and does not create a real legal obligation. `.repeat(3);
  const version = await database.query(
    `
      insert into public.legal_document_versions (
        document_id, version_label, content_hash, content_path, content_markdown,
        effective_at, published_at, material_revision, publication_status,
        attorney_reviewed_at, approved_by_counsel_reference
      ) values (
        $1, $2, encode(extensions.digest($3, 'sha256'), 'hex'),
        'synthetic-qa/rollback-only', $3, now(), now(), $4, 'published',
        now(), 'synthetic_qa_not_legal_approval'
      ) returning id, content_hash
    `,
    [document.rows[0].id, suffix, content, materialRevision],
  );
  return { documentId: document.rows[0].id, ...version.rows[0] };
}

async function createContractFixture(users, { activate = true, paymentDueRule = "at_completion" } = {}) {
  const fixture = await withDatabase(async (database) => {
    const job = await database.query(
      `
        insert into public.jobs (
          poster_id, title, summary, description, category, location_text,
          city, state, pay_amount_cents, teen_min_age, teen_max_age,
          status, estimated_duration_minutes, workers_needed, experience_level,
          work_environment, location_type, payment_type, payment_method,
          payment_timing, adult_supervision_present, public_meeting_available,
          daylight_only, applications_open, is_test, created_by_qa,
          environment_tag, risk_tier, who_will_be_present, safety_notes,
          payment_due_rule, maximum_approved_hours, completion_requirements
        ) values (
          $1, 'Synthetic QA contract job', 'Synthetic rollback-safe contract QA.',
          'Sort labeled books at a staffed public desk. No other work is included.',
          'organization', 'Public library area', 'Indianapolis', 'IN', 1800,
          13, 17, 'open', 60, 1, 'any', 'indoor', 'public', 'fixed',
          'cash', 'after_completion', true, true, true, true, true, true,
          'sandbox', 'lower_risk', 'Named library staff',
          'Stay in public staff areas.', $2, null,
          'Return all labeled books to the marked shelves.'
        ) returning id, status, pilot_review_status
      `,
      [users.adult.id, paymentDueRule],
    );
    assertQa(job.rows[0].status === "open", `QA job was not eligible: ${job.rows[0].pilot_review_status}`);
    const application = await database.query(
      `
        insert into public.applications (
          job_id, teen_id, status, note, availability_confirmed
        ) values ($1, $2, 'adult_review', 'Synthetic contract QA application.', true)
        returning id
      `,
      [job.rows[0].id, users.teen.id],
    );
    return { jobId: job.rows[0].id, applicationId: application.rows[0].id };
  });

  const accepted = await users.adult.client.rpc("update_application_status_v2", {
    p_application_id: fixture.applicationId,
    p_action: "accepted",
  });
  assertQa(!accepted.error && accepted.data?.ok === true, `Could not accept QA application: ${accepted.error?.message ?? accepted.data?.code}`);

  const contractResult = await serviceClient
    .from("job_contracts")
    .select("id,active_version_id,status")
    .eq("application_id", fixture.applicationId)
    .single();
  assertQa(!contractResult.error && contractResult.data, `Job contract was not created: ${contractResult.error?.message}`);
  const versionResult = await serviceClient
    .from("job_contract_versions")
    .select("id,version_number,content_hash,status,fixed_total_cents,agreed_scope")
    .eq("contract_id", contractResult.data.id)
    .eq("version_number", 1)
    .single();
  assertQa(!versionResult.error && versionResult.data, `Initial contract version missing: ${versionResult.error?.message}`);

  const result = { ...fixture, contract: contractResult.data, version: versionResult.data };
  if (activate) {
    const teenConfirmation = await users.teen.client.rpc("confirm_job_contract_version", {
      p_contract_version_id: result.version.id,
      p_affirmative_checkbox: true,
      p_confirmation_text: "I reviewed and confirm this exact job agreement.",
      p_platform: "qa",
      p_app_version: "qa-1",
    });
    assertQa(!teenConfirmation.error && teenConfirmation.data?.ok === true, `Teen contract confirmation failed: ${teenConfirmation.error?.message}`);
    assertQa(teenConfirmation.data.contract_active === false, "One party must not activate a contract");
    const adultConfirmation = await users.adult.client.rpc("confirm_job_contract_version", {
      p_contract_version_id: result.version.id,
      p_affirmative_checkbox: true,
      p_confirmation_text: "I reviewed and confirm this exact job agreement.",
      p_platform: "qa",
      p_app_version: "qa-1",
    });
    assertQa(!adultConfirmation.error && adultConfirmation.data?.contract_active === true, `Adult contract confirmation failed: ${adultConfirmation.error?.message}`);
  }
  return result;
}

async function makePaymentDue(users, contractId) {
  const completed = await users.teen.client.rpc("submit_job_completion_assertion", {
    p_contract_id: contractId,
    p_task_checklist: [{ item: "Sorted labeled books", completed: true }],
    p_start_timestamp: new Date(Date.now() - 30 * 60 * 1000).toISOString(),
    p_completion_timestamp: new Date().toISOString(),
    p_location_type_confirmation: "public",
    p_approved_scope_confirmation: true,
    p_witness_notes: "Synthetic QA only",
    p_statement: "The accepted synthetic task was completed.",
  });
  assertQa(!completed.error && completed.data?.ok === true, `Worker completion failed: ${completed.error?.message ?? completed.data?.code}`);
  const acknowledged = await users.adult.client.rpc("respond_job_completion", {
    p_contract_id: contractId,
    p_acknowledged: true,
    p_statement: "Synthetic completion acknowledged.",
  });
  assertQa(!acknowledged.error && acknowledged.data?.payment_due === true, `Adult acknowledgment failed: ${acknowledged.error?.message ?? acknowledged.data?.code}`);
  const obligation = await serviceClient
    .from("job_payment_obligations")
    .select("id,status,amount_cents,due_at")
    .eq("contract_id", contractId)
    .eq("status", "due")
    .single();
  assertQa(!obligation.error && obligation.data, `Payment obligation did not become due: ${obligation.error?.message}`);
  return obligation.data;
}

async function openNonpaymentDispute(users, contractId) {
  const obligation = await makePaymentDue(users, contractId);
  const report = await users.teen.client.rpc("report_nonpayment", {
    p_obligation_id: obligation.id,
    p_worker_statement: "The agreed off-platform payment has not been received in this synthetic QA case.",
  });
  assertQa(!report.error && report.data?.ok === true, `Nonpayment report failed: ${report.error?.message ?? report.data?.code}`);
  return { obligation, disputeId: report.data.dispute_id, report: report.data };
}

async function seedReadyTeamMember(database, userId, adminId, roleKey) {
  await database.query(
    `insert into public.team_confidentiality_acknowledgements
      (user_id, policy_version, content_hash, affirmative_checkbox, expires_at)
     values ($1, 'synthetic-qa-v1', repeat('a', 64), true, now() + interval '1 day')`,
    [userId],
  );
  await database.query(
    `insert into public.team_conflict_disclosures
      (user_id, disclosure_version, has_conflict, review_status, reviewed_by, reviewed_at, expires_at)
     values ($1, 'synthetic-qa-v1', false, 'cleared', $2, now(), now() + interval '1 day')`,
    [userId, adminId],
  );
  await database.query(
    `insert into public.team_device_compliance
      (user_id, device_reference_hash, passcode_enabled, encryption_enabled,
       supported_os, shared_device, review_status, reviewed_by, reviewed_at, expires_at)
     values ($1, repeat('b', 64), true, true, true, false, 'approved', $2, now(), now() + interval '1 day')`,
    [userId, adminId],
  );
  await database.query(
    `insert into public.team_training_completions
      (user_id, module_key, module_version, assessment_passed, score_percent, expires_at, approved_by)
     select $1, module.module_key, module.module_version, true, 100, now() + interval '1 day', $2
     from public.team_training_modules module
     join public.team_role_training_requirements requirement
       on requirement.module_key = module.module_key and requirement.role_key = $3
     where module.active`,
    [userId, adminId, roleKey],
  );
  const assignment = await database.query(
    `insert into public.team_role_assignments
      (user_id, role_key, environment_scope, access_status, approved_by,
       approval_reason, access_reason, granted_at, expires_at)
     values ($1, $2, 'synthetic_qa', 'active', $3,
       'Synthetic QA role only.', 'Synthetic QA assignment test.', now(), now() + interval '1 day')
     returning id`,
    [userId, roleKey, adminId],
  );
  return assignment.rows[0].id;
}

async function createReviewerAccessFixture(database, users, { assignedReviewer = true } = {}) {
  await seedReadyTeamMember(database, users.reviewer.id, users.admin.id, "document_reviewer");
  const reviewCase = await database.query(
    `insert into public.document_review_cases
      (subject_user_id, environment, evidence_category, status, contains_real_person_data, requires_two_person_review)
     values ($1, 'sandbox', 'alternative_evidence', 'document_review_pending', false, true)
     returning id`,
    [users.subject.id],
  );
  const appearance = await database.query(
    `insert into public.appearance_review_cases
      (document_review_case_id, subject_user_id, synthetic_qa, contains_real_face_data)
     values ($1, $2, true, false) returning id`,
    [reviewCase.rows[0].id, users.subject.id],
  );
  const capture = await database.query(
    `insert into public.document_capture_sessions
      (subject_user_id, review_case_id, document_type, synthetic_qa,
       contains_real_person_data, retention_expires_at)
     values ($1, $2, 'synthetic_test_document', true, false, now() + interval '1 hour')
     returning id`,
    [users.subject.id, reviewCase.rows[0].id],
  );
  const request = await database.query(
    `insert into public.document_web_reuse_requests
      (capture_session_id, subject_user_id, consent_disclosure_version,
       consent_recorded, request_status, synthetic_qa, expires_at)
     values ($1, $2, 'synthetic-qa-v1', true, 'synthetic_completed', true, now() + interval '1 hour')
     returning id`,
    [capture.rows[0].id, users.subject.id],
  );
  const result = await database.query(
    `insert into public.document_web_reuse_results
      (request_id, provider_event_id, provider_signature_verified, result_level,
       known_test_fixture_match, automatically_approved, automatically_rejected,
       authenticity_conclusion, synthetic_qa)
     values ($1, $2, true, 'document_web_reuse_signal_flagged', true, false, false,
       'authenticity_not_authoritatively_confirmed', true)
     returning id`,
    [request.rows[0].id, `qa-provider-${Date.now()}-${Math.random()}`],
  );
  if (assignedReviewer) {
    await database.query(
      `insert into public.appearance_review_assignments
        (appearance_case_id, reviewer_id, review_position, assigned_by, purpose, expires_at)
       values ($1, $2, 1, $3, 'Synthetic QA assigned review.', now() + interval '1 hour')`,
      [appearance.rows[0].id, users.reviewer.id, users.admin.id],
    );
  }
  return { reviewCaseId: reviewCase.rows[0].id, appearanceCaseId: appearance.rows[0].id, resultId: result.rows[0].id };
}

const suites = {
  "qa-legal-clickwrap": async (scope) => withQaUsers(scope, [{ key: "teen", role: "teen" }], async ({ teen }) => {
    await withDatabase(async (database) => {
      await database.query("begin");
      try {
        const version = await insertSyntheticPublishedLegalVersion(database, `clickwrap_${Date.now()}`);
        const rejected = await queryAs(database, teen.id,
          "select public.submit_legal_acceptance($1, false, true, null, 'qa', 'qa-1', 'en-US') result",
          [version.id]);
        assertQa(rejected.rows[0].result.code === "affirmative_checkbox_required", "Unchecked clickwrap was not rejected");
        const accepted = await queryAs(database, teen.id,
          "select public.submit_legal_acceptance($1, true, true, null, 'qa', 'qa-1', 'en-US') result",
          [version.id]);
        assertQa(accepted.rows[0].result.ok === true && accepted.rows[0].result.content_hash === version.content_hash, "Affirmative acceptance was not version/hash bound");
      } finally { await database.query("rollback"); }
    });
    qaLog(scope, "affirmative, teen-summary-first, version/hash-bound clickwrap passed");
  }),

  "qa-legal-version-forgery": async (scope) => withQaUsers(scope, [{ key: "teen", role: "teen" }], async ({ teen }) => {
    const draft = await serviceClient.from("legal_document_versions").select("id").eq("publication_status", "draft_attorney_review").limit(1).single();
    assertQa(!draft.error && draft.data, "Draft legal catalog is missing");
    const draftAttempt = await teen.client.rpc("submit_legal_acceptance", {
      p_document_version_id: draft.data.id, p_affirmative_checkbox: true,
      p_teen_summary_viewed: true, p_electronic_signature_text: null,
      p_platform: "qa", p_app_version: "qa-1", p_language_code: "en-US",
    });
    assertQa(!draftAttempt.error && draftAttempt.data?.ok === false, "Draft version was accepted");
    const forged = await teen.client.from("legal_acceptances").insert({
      user_id: teen.id, role: "teen", age_band: "teen_13_15",
      document_id: "00000000-0000-0000-0000-000000000001",
      document_version_id: draft.data.id, content_hash: "0".repeat(64),
      effective_date: new Date().toISOString(), platform: "qa", app_version: "qa",
      language_code: "en-US", jurisdiction_policy: "forged",
      acceptance_ui_version: "forged", affirmative_checkbox: true,
    });
    assertQa(Boolean(forged.error), "Client forged a direct legal acceptance");
    qaLog(scope, "draft acceptance and direct-client forgery were rejected");
  }),

  "qa-legal-reacceptance": async (scope) => withQaUsers(scope, [{ key: "teen", role: "teen" }], async ({ teen }) => {
    await withDatabase(async (database) => {
      await database.query("begin");
      try {
        const suffix = `reaccept_${Date.now()}`;
        const first = await insertSyntheticPublishedLegalVersion(database, `${suffix}_v1`);
        await queryAs(database, teen.id, "select public.submit_legal_acceptance($1, true, true, null, 'qa', 'qa-1', 'en-US')", [first.id]);
        const secondContent = "Synthetic material revision. Not legal terms or legal approval. ".repeat(8);
        const second = await database.query(
          `insert into public.legal_document_versions
            (document_id, version_label, content_hash, content_path, content_markdown,
             effective_at, published_at, material_revision, publication_status,
             attorney_reviewed_at, approved_by_counsel_reference)
           values ($1, $2, encode(extensions.digest($3, 'sha256'), 'hex'),
             'synthetic-qa/rollback-only', $3, now(), now(), true, 'published',
             now(), 'synthetic_qa_not_legal_approval') returning id`,
          [first.documentId, `${suffix}_v2`, secondContent],
        );
        const open = await database.query("select count(*)::int count from public.legal_reacceptance_requirements where user_id=$1 and required_version_id=$2 and satisfied_at is null", [teen.id, second.rows[0].id]);
        assertQa(open.rows[0].count === 1, "Material revision did not create reacceptance requirement");
        await queryAs(database, teen.id, "select public.submit_legal_acceptance($1, true, true, null, 'qa', 'qa-1', 'en-US')", [second.rows[0].id]);
        const resolved = await database.query("select satisfied_at is not null satisfied from public.legal_reacceptance_requirements where user_id=$1 and required_version_id=$2", [teen.id, second.rows[0].id]);
        assertQa(resolved.rows[0].satisfied, "New exact version did not satisfy reacceptance");
      } finally { await database.query("rollback"); }
    });
    qaLog(scope, "material revision required and recorded a separate reacceptance");
  }),

  "qa-job-contract-immutability": async (scope) => withQaUsers(scope, [{ key: "teen", role: "teen" }, { key: "adult", role: "adult" }], async (users) => {
    const fixture = await createContractFixture(users);
    const update = await users.adult.client.from("job_contract_versions").update({ fixed_total_cents: 1 }).eq("id", fixture.version.id);
    assertQa(Boolean(update.error), "Adult directly rewrote immutable contract history");
    const after = await serviceClient.from("job_contract_versions").select("fixed_total_cents,version_number").eq("id", fixture.version.id).single();
    assertQa(after.data.fixed_total_cents === 1800 && after.data.version_number === 1, "Contract amount/history changed");
    qaLog(scope, "contract history and amount resisted unilateral direct mutation");
  }),

  "qa-contract-change-consent": async (scope) => withQaUsers(scope, [{ key: "teen", role: "teen" }, { key: "adult", role: "adult" }], async (users) => {
    const fixture = await createContractFixture(users);
    const request = await users.adult.client.rpc("request_job_contract_change", {
      p_contract_id: fixture.contract.id,
      p_patch: { fixed_total_cents: 2000, agreed_scope: "Sort labeled books and return the cart to the staffed desk." },
      p_reason: "The parties are considering one explicit scope and amount revision.",
    });
    assertQa(!request.error && request.data?.ok, `Change request failed: ${request.error?.message}`);
    const adult = await users.adult.client.rpc("respond_job_contract_change", { p_change_request_id: request.data.change_request_id, p_accept: true, p_affirmative_checkbox: true });
    assertQa(adult.data?.status === "awaiting_other_party", "Adult alone activated a material change");
    const before = await serviceClient.from("job_contract_versions").select("id", { count: "exact", head: true }).eq("contract_id", fixture.contract.id);
    assertQa(before.count === 1, "A unilateral response created a contract version");
    const teen = await users.teen.client.rpc("respond_job_contract_change", { p_change_request_id: request.data.change_request_id, p_accept: true, p_affirmative_checkbox: true });
    assertQa(!teen.error && teen.data?.status === "accepted", `Second-party acceptance failed: ${teen.error?.message}`);
    const latest = await serviceClient.from("job_contract_versions").select("version_number,fixed_total_cents,agreed_scope,status").eq("contract_id", fixture.contract.id).order("version_number", { ascending: false }).limit(1).single();
    assertQa(latest.data.version_number === 2 && latest.data.fixed_total_cents === 2000 && latest.data.status === "active", "Mutually accepted change version was not created");
    qaLog(scope, "amount and scope change required both exact-hash confirmations");
  }),

  "qa-payment-obligation": async (scope) => withQaUsers(scope, [{ key: "teen", role: "teen" }, { key: "adult", role: "adult" }], async (users) => {
    const fixture = await createContractFixture(users);
    const obligation = await makePaymentDue(users, fixture.contract.id);
    const sent = await users.adult.client.rpc("record_payment_confirmation", { p_obligation_id: obligation.id, p_confirmation_type: "poster_marked_sent", p_amount_cents: 1800, p_occurred_at: new Date().toISOString(), p_payment_reference: "synthetic qa" });
    assertQa(sent.data?.payment_received === false, "Poster-sent confirmation falsely marked payment received");
    const report = await users.teen.client.rpc("report_nonpayment", {
      p_obligation_id: obligation.id,
      p_worker_statement: "Synthetic QA report used only to prove the private publication restriction.",
    });
    assertQa(!report.error && report.data?.ok, `Synthetic restriction dispute failed: ${report.error?.message ?? report.data?.code}`);
    await withDatabase(async (database) => {
      await database.query("begin");
      try {
        await database.query(
          `insert into public.poster_payment_restrictions
            (poster_id, dispute_id, restriction_type, private_reason, imposed_by, expires_at)
           values ($1, $2, 'block_new_job_publication',
             'Synthetic rollback-only payment restriction QA.', $1, now() + interval '15 minutes')`,
          [users.adult.id, report.data.dispute_id],
        );
        await database.query("savepoint restricted_job_insert");
        let publicationRejected = false;
        try {
          await database.query(
            `insert into public.jobs (
              poster_id, title, summary, description, category, location_text,
              city, state, pay_amount_cents, teen_min_age, teen_max_age, status,
              estimated_duration_minutes, workers_needed, experience_level,
              work_environment, location_type, payment_type, payment_method,
              payment_timing, adult_supervision_present, public_meeting_available,
              daylight_only, applications_open, is_test, created_by_qa,
              environment_tag, risk_tier, who_will_be_present, safety_notes
            ) values (
              $1, 'Synthetic restricted publication QA', 'Rollback-only trigger test.',
              'This synthetic job must never be committed.', 'organization',
              'Public staffed area', 'Indianapolis', 'IN', 1800, 13, 17, 'open',
              60, 1, 'any', 'indoor', 'public', 'fixed', 'cash',
              'after_completion', true, true, true, true, true, true,
              'sandbox', 'lower_risk', 'Named synthetic QA staff',
              'Synthetic rollback-only restriction test.'
            )`,
            [users.adult.id],
          );
        } catch (error) {
          publicationRejected = /temporarily restricted from publishing jobs/i.test(error.message);
          await database.query("rollback to savepoint restricted_job_insert");
        }
        assertQa(publicationRejected, "Active private payment restriction did not block new job publication");
      } finally {
        await database.query("rollback");
      }
    });
    const received = await users.teen.client.rpc("record_payment_confirmation", { p_obligation_id: obligation.id, p_confirmation_type: "worker_confirmed_received", p_amount_cents: 1800, p_occurred_at: new Date().toISOString(), p_payment_reference: "synthetic qa" });
    assertQa(received.data?.payment_received === true, "Worker receipt confirmation was not distinguished");
    qaLog(scope, "payment states stayed distinct and an active private restriction blocked new job publication");
  }),

  "qa-nonpayment-dispute-isolation": async (scope) => withQaUsers(scope, [{ key: "teen", role: "teen" }, { key: "adult", role: "adult" }, { key: "outsider", role: "adult" }], async (users) => {
    const fixture = await createContractFixture(users);
    const opened = await openNonpaymentDispute(users, fixture.contract.id);
    assertQa(opened.report.guilt_determined === false && opened.report.automatic_lawsuit === false, "Report made an automatic guilt or lawsuit finding");
    const outsider = await users.outsider.client.from("payment_disputes").select("id").eq("id", opened.disputeId);
    assertQa(!outsider.error && outsider.data.length === 0, "Ordinary outsider read a private payment dispute");
    qaLog(scope, "nonpayment remained a private allegation and outsider isolation passed");
  }),

  "qa-payment-evidence-preservation": async (scope) => withQaUsers(scope, [{ key: "teen", role: "teen" }, { key: "adult", role: "adult" }, { key: "outsider", role: "adult" }], async (users) => {
    const fixture = await createContractFixture(users);
    const evidenceId = await withDatabase(async (database) => {
      const result = await database.query(`insert into public.completion_evidence_records
        (contract_id, contract_version_id, submitted_by, evidence_type, evidence_metadata, preserved)
        values ($1,$2,$3,'task_checklist','{"synthetic_qa":true}'::jsonb,true) returning id`, [fixture.contract.id, fixture.version.id, users.teen.id]);
      return result.rows[0].id;
    });
    const deleted = await users.adult.client.from("completion_evidence_records").delete().eq("id", evidenceId);
    assertQa(Boolean(deleted.error), "Adult deleted preserved completion evidence");
    const stillThere = await serviceClient.from("completion_evidence_records").select("id,preserved").eq("id", evidenceId).single();
    assertQa(stillThere.data?.preserved === true, "Preserved evidence disappeared");
    const opened = await openNonpaymentDispute(users, fixture.contract.id);
    const exported = await users.teen.client.rpc("request_payment_evidence_export", { p_dispute_id: opened.disputeId });
    assertQa(!exported.error && exported.data?.ok, `Authorized evidence export failed: ${exported.error?.message ?? exported.data?.code}`);
    const manifest = exported.data.export;
    const excluded = new Set(manifest.excluded_categories ?? []);
    assertQa(manifest.legal_information_only === true && manifest.automatic_lawsuit === false && manifest.recovery_guaranteed === false, "Evidence export overstated legal action or recovery");
    assertQa(["raw_identity_documents", "face_data", "residential_addresses", "precise_coordinates", "secrets"].every((item) => excluded.has(item)), "Evidence export did not declare all sensitive exclusions");
    const outsider = await users.outsider.client.rpc("request_payment_evidence_export", { p_dispute_id: opened.disputeId });
    assertQa(!outsider.error && outsider.data?.ok === false && outsider.data?.code === "authorized_dispute_party_required", "Outsider received a private payment evidence export");
    qaLog(scope, "preserved evidence resisted deletion and export stayed party-authorized with sensitive categories excluded");
  }),

  "qa-no-automatic-legal-advice": async (scope) => {
    const policy = await readFile(join(root, "docs", "MORT_LEGAL_INFORMATION_NOT_ADVICE_POLICY.md"), "utf8");
    const process = await readFile(join(root, "docs", "MORT_NONPAYMENT_OPERATIONAL_PROCESS.md"), "utf8");
    assertQa(/does not.*provide legal representation/i.test(`${policy}\n${process}`), "Legal-information boundary is missing");
    assertQa(!/MORT will sue you|MORT will automatically sue|MORT guarantees recovery|recovery is guaranteed/i.test(`${policy}\n${process}`), "Automatic lawsuit or recovery promise detected");
    assertQa(/(?:does not|cannot) guarantee recovery/i.test(`${policy}\n${process}`), "Required no-recovery-guarantee disclaimer is missing");
    qaLog(scope, "legal information is conditional and no lawsuit/recovery promise exists");
  },

  "qa-document-web-reuse-signal": async (scope) => withQaUsers(scope, [{ key: "teen", role: "teen" }], async ({ teen }) => {
    const capture = await teen.client.rpc("start_synthetic_document_capture", { p_document_type: "synthetic_test_document", p_retention_minutes: 30 });
    assertQa(capture.data?.synthetic_qa_only === true && capture.data?.real_document_upload_allowed === false, "Capture was not synthetic-only");
    const request = await teen.client.rpc("request_synthetic_web_reuse_signal", { p_capture_session_id: capture.data.capture_session_id, p_consent_disclosure_version: "synthetic-qa-v1", p_consent_recorded: true });
    assertQa(request.data?.external_provider_called === false && request.data?.match_would_require_human_review === true, "Web reuse request overstated or called a provider");
    const resultId = await withDatabase(async (database) => {
      const result = await database.query("select private.record_document_web_reuse_result($1,$2,true,'document_web_reuse_signal_flagged',1,0,true,array['known_synthetic_fixture'], '[]'::jsonb) id", [request.data.request_id, `qa-${Date.now()}`]);
      return result.rows[0].id;
    });
    const result = await serviceClient.from("document_web_reuse_results").select("result_level,automatically_approved,automatically_rejected,authenticity_conclusion,synthetic_qa").eq("id", resultId).single();
    assertQa(result.data.result_level === "document_web_reuse_signal_flagged" && !result.data.automatically_approved && !result.data.automatically_rejected, "Web match was not signal-only");
    qaLog(scope, "web match created review signal only; no external provider or auto-decision occurred");
  }),

  "qa-web-reuse-not-authenticity": async (scope) => {
    await withDatabase(async (database) => {
      await database.query("begin");
      try {
        const constraint = await database.query("select pg_get_constraintdef(oid) definition from pg_constraint where conname='document_web_reuse_no_auth_check'");
        assertQa(/not automatically_approved/i.test(constraint.rows[0].definition) && /authenticity_not_authoritatively_confirmed/i.test(constraint.rows[0].definition), "Web-reuse authenticity boundary constraint missing");
        let rejected = false;
        try { await database.query("select private.record_document_web_reuse_result(gen_random_uuid(),'unsigned',false,'document_web_reuse_signal_clear',0,0,false,array[]::text[],'[]'::jsonb)"); } catch (error) { rejected = /Unsigned provider result rejected/.test(error.message); }
        assertQa(rejected, "Unsigned web-reuse provider result was not rejected");
      } finally { await database.query("rollback"); }
    });
    qaLog(scope, "no-match cannot authenticate and unsigned provider result is rejected");
  },

  "qa-live-presence-challenge": async (scope) => withQaUsers(scope, [{ key: "teen", role: "teen" }], async ({ teen }) => {
    const challenge = await teen.client.rpc("start_live_presence_challenge", { p_synthetic_qa: true, p_accessibility_requested: false });
    assertQa(challenge.data?.ok && challenge.data.steps.length === 4 && challenge.data.legal_identity_result === false, "Bound random synthetic challenge was not issued");
    const resultId = await withDatabase(async (database) => {
      const result = await database.query("select private.record_live_presence_result($1,$2,$3,true,false,true,true,false,'live_presence_challenge_passed') id", [challenge.data.challenge_id, challenge.data.server_nonce, `qa-live-${Date.now()}`]);
      return result.rows[0].id;
    });
    const result = await serviceClient.from("live_presence_results").select("result_level,legal_identity_verified,persistent_face_template_created,synthetic_qa").eq("id", resultId).single();
    assertQa(result.data.result_level === "live_presence_challenge_passed" && !result.data.legal_identity_verified && !result.data.persistent_face_template_created, "Live-presence signal raised identity or stored a template");
    qaLog(scope, "server-bound live-presence signal passed without legal-identity claim or face template");
  }),

  "qa-live-presence-replay": async (scope) => withQaUsers(scope, [{ key: "teen", role: "teen" }], async ({ teen }) => {
    const challenge = await teen.client.rpc("start_live_presence_challenge", { p_synthetic_qa: true, p_accessibility_requested: false });
    await withDatabase(async (database) => {
      await database.query("select private.record_live_presence_result($1,$2,$3,true,false,true,true,false,'live_presence_challenge_passed')", [challenge.data.challenge_id, challenge.data.server_nonce, `qa-live-first-${Date.now()}`]);
      let replayRejected = false;
      try { await database.query("select private.record_live_presence_result($1,$2,$3,true,false,true,true,false,'live_presence_challenge_passed')", [challenge.data.challenge_id, challenge.data.server_nonce, `qa-live-replay-${Date.now()}`]); } catch (error) { replayRejected = /replay rejected/i.test(error.message); }
      assertQa(replayRejected, "Second use of challenge was not rejected as replay");
    });
    qaLog(scope, "one-shot nonce replay was rejected");
  }),

  "qa-live-presence-accessibility": async (scope) => withQaUsers(scope, [{ key: "teen", role: "teen" }], async ({ teen }) => {
    const challenge = await teen.client.rpc("start_live_presence_challenge", { p_synthetic_qa: true, p_accessibility_requested: true });
    assertQa(challenge.data?.accessibility_alternative_available === true, "Accessibility alternative was not offered");
    const alternative = await teen.client.rpc("request_live_presence_accessibility_alternative", { p_challenge_id: challenge.data.challenge_id, p_reason_code: "cannot_perform_requested_movement" });
    assertQa(alternative.data?.alternative_route_requested === true && alternative.data?.disability_penalty === false, "Accessible route failed or imposed a penalty");
    qaLog(scope, "accessible alternative route exists without disability penalty");
  }),

  "qa-appearance-review-two-person": async (scope) => withQaUsers(scope, [{ key: "subject", role: "teen" }, { key: "reviewer1", role: "adult" }, { key: "reviewer2", role: "adult" }, { key: "admin", role: "admin" }], async (users) => {
    await withDatabase(async (database) => {
      await database.query("begin");
      try {
        await seedReadyTeamMember(database, users.reviewer1.id, users.admin.id, "document_reviewer");
        await seedReadyTeamMember(database, users.reviewer2.id, users.admin.id, "senior_document_reviewer");
        const review = await database.query("insert into public.document_review_cases (subject_user_id,environment,evidence_category,status,contains_real_person_data,requires_two_person_review) values ($1,'sandbox','alternative_evidence','document_review_pending',false,true) returning id", [users.subject.id]);
        const appearance = await database.query("insert into public.appearance_review_cases (document_review_case_id,subject_user_id,synthetic_qa,contains_real_face_data) values ($1,$2,true,false) returning id", [review.rows[0].id, users.subject.id]);
        const a1 = await database.query("insert into public.appearance_review_assignments (appearance_case_id,reviewer_id,review_position,assigned_by,purpose,expires_at) values ($1,$2,1,$3,'Synthetic mismatch QA',now()+interval '1 hour') returning id", [appearance.rows[0].id, users.reviewer1.id, users.admin.id]);
        const a2 = await database.query("insert into public.appearance_review_assignments (appearance_case_id,reviewer_id,review_position,assigned_by,purpose,expires_at) values ($1,$2,2,$3,'Independent synthetic mismatch QA',now()+interval '1 hour') returning id", [appearance.rows[0].id, users.reviewer2.id, users.admin.id]);
        const first = await queryAs(database, users.reviewer1.id, "select public.submit_appearance_review_decision($1,'appearance_mismatch_requires_review','synthetic_mismatch',null) result", [a1.rows[0].id]);
        assertQa(first.rows[0].result.second_independent_reviewer_required === true, "First mismatch reviewer finalized consequential result");
        const pending = await database.query("select final_result,review_state from public.appearance_review_cases where id=$1", [appearance.rows[0].id]);
        assertQa(pending.rows[0].final_result === null && pending.rows[0].review_state === "second_review_required", "Mismatch was finalized before second review");
        const second = await queryAs(database, users.reviewer2.id, "select public.submit_appearance_review_decision($1,'appearance_mismatch_requires_review','independent_synthetic_mismatch',null) result", [a2.rows[0].id]);
        assertQa(second.rows[0].result.final_result === "appearance_mismatch_requires_review" && second.rows[0].result.legal_identity_verified === false, "Second independent result did not remain limited");
      } finally { await database.query("rollback"); }
    });
    qaLog(scope, "consequential appearance mismatch required two distinct trained reviewers");
  }),

  "qa-face-id-not-identity": async (scope) => {
    const deviceService = await readFile(join(root, "swift_mort", "MORT", "Services", "DeviceAuthenticationService.swift"), "utf8");
    const disclosure = await readFile(join(root, "docs", "legal", "MORT_FACE_ID_DISCLOSURE.md"), "utf8");
    assertQa(/LocalAuthentication/.test(deviceService), "Swift device authentication is not using LocalAuthentication");
    assertQa(/does not verify your legal identity/i.test(disclosure), "Face ID legal-identity limitation copy missing");
    const status = await serviceClient.rpc("get_first_party_trust_status");
    assertQa(status.data?.device_biometric_is_legal_identity === false, "Backend treats device biometrics as identity");
    qaLog(scope, "Face ID/Touch ID protects the device only and sends no biometric identity result");
  },

  "qa-team-role-isolation": async (scope) => withQaUsers(scope, [{ key: "subject", role: "teen" }, { key: "reviewer", role: "adult" }, { key: "outsider", role: "adult" }, { key: "admin", role: "admin" }], async (users) => {
    const fixture = await withDatabase((database) => createReviewerAccessFixture(database, users));
    const outsider = await users.outsider.client.from("document_web_reuse_results").select("id").eq("id", fixture.resultId);
    assertQa(!outsider.error && outsider.data.length === 0, "Ordinary tester viewed assigned sensitive review result");
    const roleRows = await users.outsider.client.from("team_role_assignments").select("id").eq("user_id", users.reviewer.id);
    assertQa(!roleRows.error && roleRows.data.length === 0, "Ordinary user viewed another team member's role assignment");
    qaLog(scope, "ordinary testers received no production-style review or team access");
  }),

  "qa-reviewer-assignment": async (scope) => withQaUsers(scope, [{ key: "subject", role: "teen" }, { key: "reviewer", role: "adult" }, { key: "outsider", role: "adult" }, { key: "admin", role: "admin" }], async (users) => {
    const fixture = await withDatabase((database) => createReviewerAccessFixture(database, users));
    const assignment = await withDatabase(async (database) => {
      await database.query("begin");
      try {
        return await queryAs(
          database,
          users.reviewer.id,
          "select private.is_assigned_appearance_reviewer($1) assigned",
          [fixture.appearanceCaseId],
        );
      } finally {
        await database.query("rollback");
      }
    });
    assertQa(assignment.rows[0].assigned === true, "Reviewer role prerequisites or assignment were not ready");
    const assigned = await users.reviewer.client.from("document_web_reuse_results").select("id,result_level").eq("id", fixture.resultId);
    assertQa(!assigned.error && assigned.data.length === 1, "Assigned trained reviewer could not view assigned result");
    const unassigned = await users.outsider.client.from("document_web_reuse_results").select("id").eq("id", fixture.resultId);
    assertQa(!unassigned.error && unassigned.data.length === 0, "Unassigned reviewer accessed result");
    qaLog(scope, "review result access required active role, prerequisites, and case assignment");
  }),

  "qa-founder-no-automatic-id-access": async (scope) => withQaUsers(scope, [{ key: "subject", role: "teen" }, { key: "reviewer", role: "adult" }, { key: "outsider", role: "adult" }, { key: "admin", role: "admin" }], async (users) => {
    const fixture = await withDatabase((database) => createReviewerAccessFixture(database, users));
    const adminRead = await users.admin.client.from("document_web_reuse_results").select("id").eq("id", fixture.resultId);
    assertQa(!adminRead.error && adminRead.data.length === 0, "Admin/founder-style account received automatic raw review access");
    qaLog(scope, "admin or founder status alone grants no raw identity-review access");
  }),

  "qa-sensitive-data-not-in-group-chat": async (scope) => {
    const docs = await Promise.all([
      "MORT_CONFIDENTIALITY_AND_DATA_ACCESS.md",
      "MORT_TEAM_ROLE_MATRIX.md",
      "MORT_SECURITY_ADVISOR_SCOPE.md",
    ].map((name) => readFile(join(root, "docs", "operations", name), "utf8")));
    const combined = docs.join("\n");
    assertQa(/No raw ID.*group chat/is.test(combined) || /No production secret.*group chat/is.test(combined), "Group-chat sensitive-data prohibition missing");
    const grantCheck = await withDatabase((database) => database.query("select count(*)::int count from public.team_role_assignments where approval_reason ilike '%group chat%' or access_reason ilike '%group chat%'"));
    assertQa(grantCheck.rows[0].count === 0, "Group-chat membership appears in role grants");
    qaLog(scope, "group chat grants no role and is prohibited for sensitive files or secrets");
  },

  "qa-guardian-remains-optional": async (scope) => {
    const status = await serviceClient.rpc("get_first_party_trust_status");
    const catalog = await serviceClient.from("legal_documents").select("guardian_mode_independent");
    assertQa(status.data?.guardian_mode_optional === true, "Trust status made Guardian Mode mandatory");
    assertQa(!catalog.error && catalog.data.every((row) => row.guardian_mode_independent === true), "Legal catalog coupled consent to Guardian Mode");
    const defaults = await withDatabase((database) => database.query("select column_default from information_schema.columns where table_schema='public' and table_name='jobs' and column_name='requires_guardian_approval'"));
    assertQa(/false/i.test(defaults.rows[0].column_default), "Job guardian approval default is not optional");
    qaLog(scope, "Guardian Mode remains optional and separate from jurisdictional legal consent");
  },
};

export async function runLegalTrustSuite(scope) {
  const suite = suites[scope];
  if (!suite) throw new Error(`Unknown legal/trust QA suite: ${scope}`);
  await suite(scope);
}

export const legalTrustSuiteNames = Object.freeze(Object.keys(suites));
