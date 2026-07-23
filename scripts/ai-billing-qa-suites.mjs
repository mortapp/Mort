import { randomUUID } from "node:crypto";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  assertQa,
  qaLog,
  serviceClient,
  withDatabase,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const text = (relative) => readFile(path.join(root, relative), "utf8");

export async function runAiBillingQa(scope, scenario) {
  const checks = {
    "auth-session-lifecycle": authSessionLifecycle,
    "dob-age-gating": dobAgeGating,
    "role-forgery": roleForgery,
    "teen-verification-options": teenVerificationOptions,
    "camera-contextual-permission": cameraContextualPermission,
    "real-id-remains-disabled": realIdRemainsDisabled,
    "ai-mode-gating": aiModeGating,
    "ai-private-data-boundary": aiPrivateDataBoundary,
    "ai-input-output-moderation": aiInputOutputModeration,
    "ai-cost-limits": aiCostLimits,
    "ai-minor-consent-gate": aiMinorConsentGate,
    "ai-no-high-stakes-decisions": aiNoHighStakesDecisions,
    "billing-entitlement-forgery": billingEntitlementForgery,
    "billing-token-replay": billingTokenReplay,
    "billing-review-entitlement": billingReviewEntitlement,
    "billing-free-core": billingFreeCore,
    "paywall-disclosures": paywallDisclosures,
    "admob-disabled-mode": admobDisabledMode,
    "admob-test-mode": admobTestMode,
    "teen-ad-treatment": teenAdTreatment,
    "sensitive-ad-placement": sensitiveAdPlacement,
  };
  const check = checks[scenario];
  if (!check) throw new Error(`Unknown AI/Billing QA scenario: ${scenario}`);
  await check(scope);
}

async function authSessionLifecycle(scope) {
  await withQaUsers(scope, [{ key: "teen", role: "teen" }], async ({ teen }) => {
    const before = await teen.client.auth.getUser();
    assertQa(before.data.user?.id === teen.id, "authenticated session was not restored");
    const signedOut = await teen.client.auth.signOut();
    assertQa(!signedOut.error, "sign-out failed");
    const after = await teen.client.auth.getUser();
    assertQa(after.data.user == null, "user remained authenticated after sign-out");
    const signedIn = await teen.client.auth.signInWithPassword({ email: teen.email, password: teen.password });
    assertQa(!signedIn.error && signedIn.data.user?.id === teen.id, "sign-in after sign-out failed");
  });
  qaLog(scope, "Supabase Auth session get-user, sign-out, and sign-in lifecycle passed");
}

async function dobAgeGating(scope) {
  await withDatabase(async (database) => {
    const result = await database.query(`
      select
        public.derive_age_eligibility((current_date - interval '12 years')::date) under_13,
        public.derive_age_eligibility((current_date - interval '13 years')::date) exact_13,
        public.derive_age_eligibility((current_date - interval '17 years')::date) exact_17,
        public.derive_age_eligibility((current_date - interval '18 years')::date) exact_18,
        public.derive_age_eligibility((current_date + interval '1 day')::date) future
    `);
    const row = result.rows[0];
    assertQa(row.under_13.age_band === "under_13" && row.under_13.eligible === false, "under-13 result was not rejected");
    assertQa(row.exact_13.age_band === "teen_13_15" && row.exact_13.eligible === true, "exact 13th birthday failed");
    assertQa(row.exact_17.age_band === "teen_16_17", "age 17 band failed");
    assertQa(row.exact_18.age_band === "adult_18_plus", "exact 18th birthday failed");
    assertQa(row.future.code === "future_dob_rejected", "future DOB did not fail");
  });
  qaLog(scope, "server-date under-13, teen, adult, and future-DOB boundaries passed");
}

async function roleForgery(scope) {
  await withQaUsers(scope, [{ key: "teen", role: "teen" }], async ({ teen }) => {
    const direct = await teen.client.from("profiles").update({ role: "admin" }).eq("id", teen.id).select("role");
    assertQa(direct.error || direct.data.length === 0, "teen directly changed the server-owned role");
    const rpc = await teen.client.rpc("update_my_profile", {
      p_patch: { role: "admin" },
      p_client_request_id: randomUUID(),
    });
    assertQa(!rpc.error && rpc.data?.code === "protected_or_unknown_profile_field", "canonical profile RPC accepted role forgery");
  });
  qaLog(scope, "direct and canonical profile paths reject client role forgery");
}

async function teenVerificationOptions(scope) {
  const ui = await text("flutter_mort/lib/features/trust/teen_verification_screens.dart");
  for (const marker of [
    "Current school ID review", "Recommended", "Verified school email",
    "Partner or youth-program attestation", "Government or youth-program ID",
    "Manual exception or no-document pilot route",
  ]) assertQa(ui.includes(marker), `missing teen verification option: ${marker}`);
  assertQa(ui.includes("it is not mandatory"), "school ID was presented as mandatory");
  assertQa(ui.includes("does not prove current enrollment"), "school document limitation is missing");
  qaLog(scope, "school ID is recommended but alternatives and evidence limits remain explicit");
}

async function cameraContextualPermission(scope) {
  const ui = await text("flutter_mort/lib/features/trust/teen_verification_screens.dart");
  const service = await text("flutter_mort/lib/services/native_permissions_service.dart");
  assertQa(ui.includes("_requestCameraAfterExplicitAction"), "contextual camera action is absent");
  assertQa(ui.includes("_permissions.requestCamera()"), "camera action does not invoke native permission service");
  assertQa(!ui.match(/initState[\s\S]{0,500}requestCamera/), "camera is requested during screen initialization");
  assertQa(service.includes("Permission.camera.request()"), "native permission implementation is absent");
  assertQa(ui.includes("Use camera - Real collection disabled"), "disabled real-collection state is missing");
  qaLog(scope, "camera permission is contextual, denial-aware, and unreachable while collection is disabled");
}

async function realIdRemainsDisabled(scope) {
  await withDatabase(async (database) => {
    const result = await database.query(`select public.get_release_mode_status() status`);
    const status = result.rows[0].status;
    assertQa(status.identity_verification_mode === "disabled", "identity verification mode is not disabled");
    assertQa(status.real_document_collection === false, "real document collection is enabled");
  });
  const config = await text("flutter_mort/lib/core/config/app_config.dart");
  assertQa(config.includes("MORT_IDENTITY_VERIFICATION_ENABLED") && config.includes("defaultValue: false"), "mobile verification default is not fail-closed");
  qaLog(scope, "real identity-document collection stays server- and client-disabled; QA remains synthetic-only");
}

async function aiModeGating(scope) {
  await withQaUsers(scope, [{ key: "teen", role: "teen" }], async ({ teen }) => {
    const config = await teen.client.rpc("get_mort_guide_config");
    assertQa(!config.error && config.data?.mode === "faq_only", "MORT Guide default is not faq_only");
    assertQa(config.data.external_provider_available === false, "external provider is unexpectedly enabled");
    const answer = await teen.client.rpc("ask_mort_guide_faq", {
      p_question: "How do I apply for a job?",
      p_client_request_id: randomUUID(),
    });
    assertQa(!answer.error && answer.data?.ok === true && answer.data?.mode === "faq_only", "deterministic FAQ answer failed");
    assertQa(answer.data.source?.url?.startsWith("https://mort.app/help/"), "FAQ answer did not cite approved MORT help");
  });
  qaLog(scope, "remote FAQ mode answers from approved MORT sources without an external provider");
}

async function aiPrivateDataBoundary(scope) {
  await withQaUsers(scope, [{ key: "teenA", role: "teen" }, { key: "teenB", role: "teen" }], async ({ teenA, teenB }) => {
    const answer = await teenA.client.rpc("ask_mort_guide_faq", {
      p_question: "How do reports and blocking work?",
      p_client_request_id: randomUUID(),
    });
    assertQa(answer.data?.ok === true, "first user could not create FAQ conversation");
    const conversationId = answer.data.conversation_id;
    const direct = await teenB.client.from("ai_messages").select("id,content").eq("conversation_id", conversationId);
    assertQa(!direct.error && direct.data.length === 0, "another user read private AI messages");
    const rpc = await teenB.client.rpc("get_my_mort_guide_messages", { p_conversation_id: conversationId });
    assertQa(!rpc.error && rpc.data.length === 0, "history RPC returned another user's messages");
    const removed = await teenB.client.rpc("delete_my_mort_guide_conversation", { p_conversation_id: conversationId });
    assertQa(!removed.error && removed.data === false, "another user deleted the conversation");
  });
  qaLog(scope, "AI conversation reads and deletes remain caller-bound under remote RLS/RPC checks");
}

async function aiInputOutputModeration(scope) {
  await withQaUsers(scope, [{ key: "adult", role: "adult" }], async ({ adult }) => {
    const sensitive = await adult.client.rpc("ask_mort_guide_faq", {
      p_question: "Can I send my password and exact address?",
      p_client_request_id: randomUUID(),
    });
    assertQa(sensitive.data?.ok === true && sensitive.data.answer.includes("Please do not send"), "sensitive-data input was not redirected");
    const danger = await adult.client.rpc("ask_mort_guide_faq", {
      p_question: "I am in immediate danger and being followed",
      p_client_request_id: randomUUID(),
    });
    assertQa(danger.data?.safety_escalation === true, "danger input did not trigger safety escalation");
    const events = await serviceClient.from("ai_safety_events").select("direction,action,scanner").eq("user_id", adult.id);
    assertQa(!events.error && events.data.length >= 2, "input safety scanner events were not recorded");
    assertQa(events.data.every((event) => event.direction === "input" && event.scanner === "mort_deterministic_v1"), "FAQ safety scanner evidence is incorrect");
    await serviceClient.from("ai_human_review_escalations").delete().in("safety_event_id", (await serviceClient.from("ai_safety_events").select("id").eq("user_id", adult.id)).data?.map((row) => row.id) ?? []);
    await serviceClient.from("ai_safety_events").delete().eq("user_id", adult.id);
  });
  const edge = await text("supabase/functions/ai-support/index.ts");
  assertQa((edge.match(/moderations\.create/g) ?? []).length === 2, "external path does not moderate both input and output");
  qaLog(scope, "FAQ input scanner and optional-provider input/output moderation contracts passed");
}

async function aiCostLimits(scope) {
  await withDatabase(async (database) => {
    const { rows } = await database.query(`select mode, daily_user_requests, monthly_user_requests, global_daily_budget_usd, external_provider_enabled, provider_circuit_open from public.ai_runtime_controls where id`);
    const control = rows[0];
    assertQa(control.mode === "faq_only" && control.external_provider_enabled === false, "cost-free FAQ default is not active");
    assertQa(control.daily_user_requests > 0 && control.monthly_user_requests > control.daily_user_requests, "user limits are invalid");
    assertQa(Number(control.global_daily_budget_usd) === 0 && control.provider_circuit_open === false, "closed-test provider budget controls are invalid");
  });
  const edge = await text("supabase/functions/ai-support/index.ts");
  for (const marker of ["MORT_AI_MAX_INPUT_TOKENS", "MORT_AI_MAX_OUTPUT_TOKENS", "timeout: 20_000", "maxRetries: 1"]) assertQa(edge.includes(marker), `missing AI cost control: ${marker}`);
  qaLog(scope, "per-user limits, zero external budget default, token caps, timeout, retry, and circuit controls exist");
}

async function aiMinorConsentGate(scope) {
  await withQaUsers(scope, [{ key: "teen", role: "teen" }], async ({ teen }) => {
    const before = await teen.client.rpc("get_mort_guide_config");
    assertQa(before.data?.consent_status === "not_requested", "teen consent did not start not_requested");
    const request = await teen.client.rpc("update_my_ai_consent", { p_action: "request" });
    assertQa(request.data?.status === "pending", "teen could not request provider-specific consent");
    const directApprove = await teen.client.from("ai_processing_consents").update({ status: "approved" }).eq("user_id", teen.id).select("status");
    assertQa(directApprove.error || directApprove.data.length === 0, "teen self-approved external AI consent");
  });
  const edge = await text("supabase/functions/ai-support/index.ts");
  assertQa(edge.includes('profile.role === "teen"') && edge.includes('config.consent_status !== "approved"'), "Edge Function lacks teen consent enforcement");
  qaLog(scope, "FAQ remains available while teen external generation requires non-client-approved consent");
}

async function aiNoHighStakesDecisions(scope) {
  await withQaUsers(scope, [{ key: "adult", role: "adult" }], async ({ adult }) => {
    const answer = await adult.client.rpc("ask_mort_guide_faq", {
      p_question: "Who should I hire and can you decide the payment dispute?",
      p_client_request_id: randomUUID(),
    });
    assertQa(answer.data?.ok === true, "high-stakes request did not return safe help");
    assertQa(answer.data.answer.includes("cannot rank applicants") && answer.data.answer.includes("payment disputes"), "high-stakes refusal is incomplete");
  });
  qaLog(scope, "MORT Guide refuses employment, identity, safety, moderation, legal, medical, and dispute decisions");
}

async function billingEntitlementForgery(scope) {
  await withQaUsers(scope, [{ key: "teen", role: "teen" }], async ({ teen }) => {
    const direct = await teen.client.from("subscription_entitlements").insert({
      user_id: teen.id,
      entitlement_key: "mort_plus",
      product_id: "mort_plus",
      source_purchase_id: randomUUID(),
      status: "active",
    });
    assertQa(direct.error, "client inserted a subscription entitlement");
    const grant = await teen.client.rpc("grant_play_review_entitlement", { p_user_id: teen.id });
    assertQa(grant.error, "client executed service-only review entitlement grant");
  });
  qaLog(scope, "client cannot insert Plus entitlements or invoke synthetic review grants");
}

async function billingTokenReplay(scope) {
  await withQaUsers(scope, [{ key: "teenA", role: "teen" }, { key: "teenB", role: "teen" }], async ({ teenA, teenB }) => {
    await withDatabase(async (database) => {
      await database.query("begin");
      try {
        await database.query("update public.play_billing_runtime_controls set billing_enabled=true, provider_verification_enabled=true where id");
        await database.query("update public.store_products set active=true where product_id='mort_theme_neon_pack'");
        const token = `qa-token-${randomUUID()}-secure`;
        const first = await database.query(`select public.record_google_play_purchase_verification($1,'mort_theme_neon_pack',null,'com.mortapp.mobile','license_test',$2,$3,'purchased','acknowledged',null,now(),null,'{}') result`, [teenA.id, token, randomUUID()]);
        assertQa(first.rows[0].result.ok === true, "first isolated purchase token was not accepted");
        const replay = await database.query(`select public.record_google_play_purchase_verification($1,'mort_theme_neon_pack',null,'com.mortapp.mobile','license_test',$2,$3,'purchased','acknowledged',null,now(),null,'{}') result`, [teenB.id, token, randomUUID()]);
        assertQa(replay.rows[0].result.code === "purchase_token_replayed", "token replay across users did not fail");
      } finally {
        await database.query("rollback");
      }
    });
  });
  qaLog(scope, "duplicate purchase token cannot be rebound to another MORT user");
}

async function billingReviewEntitlement(scope) {
  await withQaUsers(scope, [{ key: "reviewer", role: "teen" }], async ({ reviewer }) => {
    await withDatabase(async (database) => {
      await database.query("begin");
      try {
        const before = await database.query("select count(*)::integer count from public.purchase_records where user_id=$1", [reviewer.id]);
        const grant = await database.query("select public.grant_play_review_entitlement($1,'mort_plus','isolated QA') result", [reviewer.id]);
        assertQa(grant.rows[0].result.ok === true && grant.rows[0].result.synthetic === true, "review entitlement was not synthetic");
        const after = await database.query("select count(*)::integer count from public.purchase_records where user_id=$1", [reviewer.id]);
        assertQa(after.rows[0].count === before.rows[0].count, "review entitlement created a financial record");
      } finally {
        await database.query("rollback");
      }
    });
  });
  qaLog(scope, "server-only Play review entitlement is synthetic, revocable, test-account-bound, and non-financial");
}

async function billingFreeCore(scope) {
  const access = await text("flutter_mort/lib/features/monetization/domain/feature_access.dart");
  const paywall = await text("flutter_mort/lib/features/monetization/screens/google_play_billing_screens.dart");
  for (const marker of ["safetyToolsFree", "basicApplyingFree", "basicGuardianModeFree", "proofUploadFree", "reportBlockSafetyPingFree"]) assertQa(access.includes(marker), `missing free-core contract: ${marker}`);
  assertQa(paywall.includes("Core app, jobs, and safety remain free"), "paywall omits free-core disclosure");
  qaLog(scope, "job, proof, Guardian, report, block, and Safety Ping access remains independent of billing");
}

async function paywallDisclosures(scope) {
  const ui = await text("flutter_mort/lib/features/monetization/screens/google_play_billing_screens.dart");
  for (const marker of ["product.price", "billingPeriod", "renew automatically until canceled", "Optional recurring", "No free trial is promised", "no applicant ranking"]) assertQa(ui.toLowerCase().includes(marker.toLowerCase()), `missing paywall disclosure: ${marker}`);
  for (const forbidden of ["countdown", "only today", "last chance", "$1.99"]) assertQa(!ui.toLowerCase().includes(forbidden.toLowerCase()), `paywall contains hardcoded or pressure copy: ${forbidden}`);
  qaLog(scope, "paywall uses localized Play pricing, renewal/cancellation disclosures, and no pressure mechanics");
}

async function admobDisabledMode(scope) {
  const config = await text("flutter_mort/lib/core/config/app_config.dart");
  const manifest = await text("flutter_mort/android/app/src/main/AndroidManifest.xml");
  assertQa(config.includes("static const nativeAdsCompiledIn = false"), "native ads are compiled in");
  assertQa(config.match(/ADS_ENABLED[\s\S]{0,100}defaultValue: false/), "ads do not default disabled");
  assertQa(manifest.match(/AD_ID[^>]+tools:node="remove"/), "advertising ID is not explicitly stripped");
  qaLog(scope, "AdMob SDK/runtime remains disabled and Android advertising IDs are stripped");
}

async function admobTestMode(scope) {
  const config = await text("flutter_mort/lib/core/config/app_config.dart");
  const service = await text("flutter_mort/lib/features/ads/data/admob_service.dart");
  assertQa(config.match(/USE_TEST_ADS[\s\S]{0,100}defaultValue: true/), "test-ad mode is not the future default");
  assertQa(service.includes("Ready for native test ads"), "test-mode decision is absent");
  assertQa(service.includes("Ads are not included in this release"), "disabled-SDK guard is absent");
  qaLog(scope, "future ad integration is test-first and cannot show while the SDK boundary is disabled");
}

async function teenAdTreatment(scope) {
  await withQaUsers(scope, [{ key: "teen", role: "teen" }], async ({ teen }) => {
    const eligibility = await teen.client.rpc("get_ad_eligibility", { p_placement: "job-feed", p_ad_format: "banner" });
    assertQa(!eligibility.error && eligibility.data?.[0]?.request_non_personalized === true, `teen ad eligibility was not privacy-protective: ${eligibility.error?.message ?? JSON.stringify(eligibility.data)}`);
  });
  qaLog(scope, "teen and unknown-age ad decisions require non-personalized, age-restricted treatment");
}

async function sensitiveAdPlacement(scope) {
  const service = await text("flutter_mort/lib/features/ads/data/admob_service.dart");
  for (const placement of ["auth", "onboarding", "age_gate", "safety_ping", "report", "messages", "guardian_approval", "proof_upload", "verification", "payment_preference", "admin", "paywall"]) assertQa(service.includes(`'${placement}'`), `missing sensitive ad exclusion: ${placement}`);
  qaLog(scope, "all authentication, safety, messaging, proof, verification, payment, admin, and paywall placements reject ads");
}
