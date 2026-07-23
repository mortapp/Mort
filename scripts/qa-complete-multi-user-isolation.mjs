import { randomUUID } from "node:crypto";

import { createClient } from "@supabase/supabase-js";

import {
  assertQa,
  confirmSafetyAgreement,
  qaLog,
  saveJob,
  serviceClient,
  supabaseUrl,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const scope = "qa-complete-multi-user-isolation";
const anonKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY;

if (!anonKey) {
  throw new Error("Missing required environment variable: EXPO_PUBLIC_SUPABASE_ANON_KEY");
}

const anonymousClient = createClient(supabaseUrl, anonKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});
const avatarBytes = Uint8Array.from(
  Buffer.from(
    "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////2wBDAf//////////////////////////////////////////////////////////////////////////////////////wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAX/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIQAxAAAAF//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABBQJ//8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAwEBPwF//8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAgEBPwF//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQAGPwJ//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPyF//9oADAMBAAIAAwAAABD/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oACAEDAQE/EB//xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oACAECAQE/EB//xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oACAEBAAE/EB//2Q==",
    "base64",
  ),
);

function assertHidden(result, message) {
  assertQa(!result.error, `${message}: ${result.error?.message}`);
  assertQa((result.data ?? []).length === 0, message);
}

function assertRejectedOrHidden(result, message) {
  assertQa(result.error || (result.data ?? []).length === 0, message);
}

await withQaUsers(
  scope,
  [
    { key: "teenA", role: "teen" },
    { key: "teenB", role: "teen" },
    { key: "adultA", role: "adult" },
    { key: "adultB", role: "adult" },
    { key: "guardianA", role: "guardian" },
    { key: "guardianB", role: "guardian" },
    { key: "nonAdmin", role: "teen", isTest: false },
    { key: "adminQa", role: "admin" },
  ],
  async ({
    teenA,
    teenB,
    adultA,
    adultB,
    guardianA,
    guardianB,
    nonAdmin,
    adminQa,
  }) => {
    const avatarPath = `${teenA.id}/${randomUUID()}.jpg`;

    try {
      const privateProfileRead = await teenA.client
        .from("profiles")
        .select("id,dob,city,expo_push_token,payment_preference,account_status")
        .eq("id", teenB.id);
      assertQa(privateProfileRead.error, "Teen A read Teen B private profile columns");
      const otherProfileUpdate = await teenA.client
        .from("profiles")
        .update({ display_name: "UNAUTHORIZED PROFILE CHANGE" })
        .eq("id", teenB.id)
        .select("id");
      assertRejectedOrHidden(otherProfileUpdate, "Teen A edited Teen B profile");
      qaLog(scope, "1/30 private profile columns and cross-user profile updates are denied");

      const jobA = await saveJob(adultA.client, {
        title: "QA Complete Isolation Job A",
        summary: "A private multi-user application and messaging fixture.",
      });
      assertQa(jobA.result?.ok === true, "Adult A could not publish the QA job");
      qaLog(scope, "2/30 Adult A created a server-validated job");

      const teenAJob = await teenA.client
        .from("jobs")
        .select("id,title")
        .eq("id", jobA.result.job.id);
      assertQa(!teenAJob.error && teenAJob.data.length === 1, "Teen A could not see the test-isolated job");
      qaLog(scope, "3/30 matching QA teen can see the open QA job");

      const application = await teenA.client.rpc("submit_job_application", {
        p_job_id: jobA.result.job.id,
        p_note: "Teen A private proposal for the isolation test.",
        p_availability_confirmed: true,
        p_portfolio_ids: [],
      });
      assertQa(
        !application.error && application.data?.ok === true,
        `Teen A application failed: ${application.error?.message}`,
      );
      const applicationId = application.data.application.id;
      qaLog(scope, "4/30 Teen A applied through the authorized RPC");

      const adultAApplication = await adultA.client
        .from("applications")
        .select("id,teen_id,note,status")
        .eq("id", applicationId);
      assertQa(
        !adultAApplication.error && adultAApplication.data.length === 1,
        "Adult A could not read an application to their own job",
      );
      qaLog(scope, "5/30 Adult A can review only the owned-job application fixture");

      const adultBApplication = await adultB.client
        .from("applications")
        .select("id,note,status")
        .eq("id", applicationId);
      assertHidden(adultBApplication, "Adult B read Adult A's application");
      const adultBManage = await adultB.client.rpc("update_application_status_v2", {
        p_application_id: applicationId,
        p_action: "accepted",
      });
      assertQa(
        !adultBManage.error && adultBManage.data?.ok === false,
        "Adult B managed Adult A's application",
      );
      qaLog(scope, "6/30 unrelated adult cannot read or manage the application");

      const teenBProposal = await teenB.client
        .from("applications")
        .select("id,note,status")
        .eq("id", applicationId);
      assertHidden(teenBProposal, "Teen B read Teen A's proposal");
      qaLog(scope, "7/30 unrelated teen cannot read another teen's proposal");

      const accepted = await adultA.client.rpc("update_application_status_v2", {
        p_application_id: applicationId,
        p_action: "accepted",
      });
      assertQa(
        !accepted.error && accepted.data?.ok === true && accepted.data.application.status === "accepted",
        "Adult A could not accept Teen A",
      );
      qaLog(scope, "8/30 owning adult accepted exactly one applicant");
      await confirmSafetyAgreement(teenA.client, adultA.client, applicationId);

      const thread = await teenA.client
        .from("message_threads")
        .select("id")
        .eq("application_id", applicationId)
        .single();
      assertQa(!thread.error && thread.data?.id, `application thread missing: ${thread.error?.message}`);
      const teenMessage = await teenA.client.rpc("send_safe_message", {
        p_thread_id: thread.data.id,
        p_body: "I can arrive at the public work site at the agreed time.",
      });
      const adultMessage = await adultA.client.rpc("send_safe_message", {
        p_thread_id: thread.data.id,
        p_body: "Confirmed. Please check in at the staffed front desk.",
      });
      assertQa(!teenMessage.error && teenMessage.data?.id, "Teen A could not send a safe message");
      assertQa(!adultMessage.error && adultMessage.data?.id, "Adult A could not send a safe message");
      for (const participant of [teenA, adultA]) {
        const visibleMessages = await participant.client
          .from("messages")
          .select("id,sender_id,body")
          .eq("thread_id", thread.data.id);
        assertQa(
          !visibleMessages.error && visibleMessages.data.length === 2,
          `${participant.email} could not read participant messages`,
        );
      }
      qaLog(scope, "9/30 conversation participants can send and read safety-scanned messages");

      for (const outsider of [teenB, adultB]) {
        const hiddenThread = await outsider.client
          .from("message_threads")
          .select("id")
          .eq("id", thread.data.id);
        const hiddenMessages = await outsider.client
          .from("messages")
          .select("id,body")
          .eq("thread_id", thread.data.id);
        const hiddenConversation = await outsider.client
          .from("conversations")
          .select("id")
          .eq("application_id", applicationId);
        assertHidden(hiddenThread, `${outsider.email} read an unrelated message thread`);
        assertHidden(hiddenMessages, `${outsider.email} read unrelated messages`);
        assertHidden(hiddenConversation, `${outsider.email} read an unrelated conversation projection`);
      }
      qaLog(scope, "10/30 unrelated users cannot read threads, conversations, or messages");

      const invite = await teenA.client.rpc("create_guardian_invite_v2", {
        p_invite_email: guardianA.email,
      });
      assertQa(!invite.error && invite.data?.ok === true, `guardian invite failed: ${invite.error?.message}`);
      const acceptedInvite = await guardianA.client.rpc("accept_guardian_invite", {
        p_invite_code: invite.data.invite_code,
      });
      assertQa(!acceptedInvite.error && acceptedInvite.data, "Guardian A could not accept Teen A's invite");
      const activeLink = await teenA.client
        .from("guardian_connections")
        .select("id,status,guardian_id")
        .eq("teen_id", teenA.id)
        .eq("status", "active")
        .single();
      assertQa(
        !activeLink.error && activeLink.data.guardian_id === guardianA.id,
        "Guardian A link was not active",
      );
      qaLog(scope, "11/30 Guardian A linked through the hashed invite flow");

      const safetyPing = await teenA.client
        .from("safety_pings")
        .insert({ teen_id: teenA.id, status: "ok", note: "Complete isolation QA ping" })
        .select("id")
        .single();
      assertQa(!safetyPing.error && safetyPing.data?.id, "Teen A could not create a Safety Ping");
      const guardianATeen = await guardianA.client
        .from("teen_profiles")
        .select("user_id")
        .eq("user_id", teenA.id);
      const guardianAPing = await guardianA.client
        .from("safety_pings")
        .select("id,status")
        .eq("id", safetyPing.data.id);
      assertQa(!guardianATeen.error && guardianATeen.data.length === 1, "Guardian A cannot read linked teen safety profile");
      assertQa(!guardianAPing.error && guardianAPing.data.length === 1, "Guardian A cannot read an enabled Safety Ping");
      qaLog(scope, "12/30 linked guardian sees only permitted teen safety information");

      const guardianBTeen = await guardianB.client
        .from("teen_profiles")
        .select("user_id")
        .eq("user_id", teenA.id);
      const guardianBPing = await guardianB.client
        .from("safety_pings")
        .select("id")
        .eq("id", safetyPing.data.id);
      const guardianBLinkProbe = await guardianB.client.rpc(
        "guardian_is_connected_to_teen",
        { p_teen_id: teenA.id, p_guardian_id: guardianA.id },
      );
      const guardianBPingProbe = await guardianB.client.rpc(
        "guardian_receives_safety_pings",
        { p_teen_id: teenA.id, p_guardian_id: guardianA.id },
      );
      const teenBAccountProbe = await teenB.client.rpc("is_profile_active", {
        p_user_id: teenA.id,
      });
      assertHidden(guardianBTeen, "Guardian B read unrelated teen safety profile");
      assertHidden(guardianBPing, "Guardian B read unrelated Teen A Safety Ping");
      assertQa(
        !guardianBLinkProbe.error && guardianBLinkProbe.data === false,
        "Guardian B probed another guardian's active link through a helper RPC",
      );
      assertQa(
        !guardianBPingProbe.error && guardianBPingProbe.data === false,
        "Guardian B probed another guardian's Safety Ping preference through a helper RPC",
      );
      assertQa(
        !teenBAccountProbe.error && teenBAccountProbe.data === false,
        "Teen B probed Teen A's private account status through a helper RPC",
      );
      qaLog(scope, "13/30 unrelated guardian cannot see Teen A linked data");

      const guardianThread = await guardianA.client
        .from("message_threads")
        .select("id")
        .eq("id", thread.data.id);
      const guardianMessages = await guardianA.client
        .from("messages")
        .select("id,body")
        .eq("thread_id", thread.data.id);
      assertHidden(guardianThread, "Linked guardian read an unrestricted private job thread");
      assertHidden(guardianMessages, "Linked guardian read unrestricted private job messages");

      const unlink = await teenA.client.rpc("unlink_guardian", {
        p_link_id: activeLink.data.id,
      });
      assertQa(!unlink.error && unlink.data?.ok === true, "Teen A could not unlink Guardian A");
      qaLog(scope, "14/30 Teen A can unlink Guardian A without restricting the teen account");

      const guardianAAfterUnlink = await guardianA.client
        .from("teen_profiles")
        .select("user_id")
        .eq("user_id", teenA.id);
      const guardianAPingAfterUnlink = await guardianA.client
        .from("safety_pings")
        .select("id")
        .eq("id", safetyPing.data.id);
      assertHidden(guardianAAfterUnlink, "Guardian A retained teen profile access after unlink");
      assertHidden(guardianAPingAfterUnlink, "Guardian A retained Safety Ping access after unlink");
      qaLog(scope, "15/30 unlink immediately removes guardian access to linked teen data");

      const uploadedAvatar = await teenA.client.storage
        .from("profile-avatars")
        .upload(avatarPath, avatarBytes, { contentType: "image/jpeg", upsert: false });
      assertQa(!uploadedAvatar.error, `Teen A avatar upload failed: ${uploadedAvatar.error?.message}`);
      const attachedAvatar = await teenA.client
        .from("profiles")
        .update({ avatar_path: avatarPath, avatar_moderation_status: "active" })
        .eq("id", teenA.id)
        .select("avatar_path")
        .single();
      assertQa(
        !attachedAvatar.error && attachedAvatar.data.avatar_path === avatarPath,
        "Teen A avatar path did not persist",
      );
      qaLog(scope, "16/30 Teen A uploads and attaches an owner-prefixed avatar");

      const overwriteAvatar = await teenB.client.storage
        .from("profile-avatars")
        .upload(avatarPath, avatarBytes, { contentType: "image/jpeg", upsert: true });
      const teenBDownload = await teenB.client.storage.from("profile-avatars").download(avatarPath);
      const teenBList = await teenB.client.storage.from("profile-avatars").list(teenA.id);
      const anonymousDownload = await anonymousClient.storage.from("profile-avatars").download(avatarPath);
      assertQa(overwriteAvatar.error, "Teen B overwrote Teen A's avatar");
      assertQa(teenBDownload.error, "Teen B directly downloaded Teen A's private avatar original");
      assertQa(teenBList.error || teenBList.data.length === 0, "Teen B listed Teen A's private avatar folder");
      assertQa(anonymousDownload.error, "Anonymous client downloaded a private avatar original");
      qaLog(scope, "17/30 avatar originals reject unrelated overwrite, list, and direct download");

      const jobB = await saveJob(adultB.client, {
        title: "QA Complete Isolation Job B",
        summary: "An ownership and saved-job isolation fixture.",
      });
      assertQa(jobB.result?.ok === true, "Adult B could not publish the ownership fixture");
      const adultAJobBUpdate = await adultA.client
        .from("jobs")
        .update({ title: "UNAUTHORIZED JOB CHANGE" })
        .eq("id", jobB.result.job.id)
        .select("id");
      assertRejectedOrHidden(adultAJobBUpdate, "Adult A modified Adult B's job");
      const adultAJobBManage = await adultA.client.rpc("manage_job", {
        p_job_id: jobB.result.job.id,
        p_action: "pause",
      });
      assertQa(
        !adultAJobBManage.error && adultAJobBManage.data?.ok === false,
        "Adult A managed Adult B's job",
      );
      qaLog(scope, "18/30 adults cannot modify or manage another adult's job");

      const hiddenTestJob = await nonAdmin.client
        .from("jobs")
        .select("id")
        .eq("id", jobA.result.job.id);
      assertHidden(hiddenTestJob, "Normal production account saw a QA test job");
      qaLog(scope, "19/30 test jobs remain hidden from normal accounts");

      const normalAdminQueue = await nonAdmin.client.from("admin_action_logs").select("id").limit(1);
      assertHidden(normalAdminQueue, "Normal user read an admin queue");
      const normalAdminProfiles = await nonAdmin.client.rpc("admin_list_profiles", { p_limit: 10 });
      assertQa(normalAdminProfiles.error, "Normal user invoked the admin profile queue");
      const adminProfiles = await adminQa.client.rpc("admin_list_profiles", { p_limit: 10 });
      assertQa(!adminProfiles.error && adminProfiles.data.length > 0, "Admin QA user could not read the admin profile queue");
      qaLog(scope, "20/30 admin queues reject normal users and accept a verified admin role");

      const nonAdminProfileBefore = await serviceClient
        .from("profiles")
        .select("role,verification_status,is_test_account")
        .eq("id", nonAdmin.id)
        .single();
      assertQa(!nonAdminProfileBefore.error, "Could not snapshot protected profile state");

      const forgedProfile = await nonAdmin.client
        .from("profiles")
        .update({ role: "admin", verification_status: "approved", is_test_account: true })
        .eq("id", nonAdmin.id)
        .select("id");
      assertRejectedOrHidden(forgedProfile, "Normal user forged admin, verification, or test status");
      const nonAdminProfile = await serviceClient
        .from("profiles")
        .select("role,verification_status,is_test_account")
        .eq("id", nonAdmin.id)
        .single();
      assertQa(
        !nonAdminProfile.error &&
          nonAdminProfile.data.role === nonAdminProfileBefore.data.role &&
          nonAdminProfile.data.verification_status === nonAdminProfileBefore.data.verification_status &&
          nonAdminProfile.data.is_test_account === nonAdminProfileBefore.data.is_test_account,
        "Normal user's protected profile state changed",
      );
      const forgedVerification = await adultA.client
        .from("business_verifications")
        .insert({
          adult_id: adultA.id,
          business_name: "Forged verification",
          business_type: "individual",
          status: "approved",
        })
        .select("id");
      assertRejectedOrHidden(forgedVerification, "Adult forged a business verification record");
      qaLog(scope, "21/30 users cannot forge roles, verification state, or test-account status");

      const forgedEntitlement = await nonAdmin.client
        .from("monetization_entitlements_cache")
        .insert({ user_id: nonAdmin.id, entitlements: ["mort_plus"], source: "app" })
        .select("user_id");
      const forgedPurchaseAudit = await nonAdmin.client
        .from("purchase_audit_logs")
        .insert({ user_id: nonAdmin.id, source: "app", action: "purchase_completed" })
        .select("id");
      const forgedAiAudit = await nonAdmin.client
        .from("ai_model_audit_logs")
        .insert({ model_name: "forged-client-audit" })
        .select("id");
      assertRejectedOrHidden(forgedEntitlement, "Normal user forged RevenueCat entitlements");
      assertRejectedOrHidden(forgedPurchaseAudit, "Normal user wrote a purchase audit record");
      assertRejectedOrHidden(forgedAiAudit, "Normal user wrote an AI model audit record");
      qaLog(scope, "22/30 monetization, purchase, and AI audit records reject client forgery");

      const forgedUsernameCredit = await nonAdmin.client
        .from("username_change_credits")
        .upsert({ user_id: nonAdmin.id, token_credits: 99 })
        .select("user_id");
      const forgedBoostCredit = await adultA.client
        .from("job_boost_credits")
        .upsert({ user_id: adultA.id, available_credits: 99 })
        .select("user_id");
      const nonAdminCreditGrant = await nonAdmin.client.rpc("admin_grant_username_change_credit", {
        p_user_id: nonAdmin.id,
        p_credit_count: 1,
        p_reason: "multi-user-negative-check",
      });
      assertRejectedOrHidden(forgedUsernameCredit, "Normal user granted username credits");
      assertRejectedOrHidden(forgedBoostCredit, "Adult granted job boost credits");
      assertQa(nonAdminCreditGrant.error, "Normal user invoked the admin username-credit grant RPC");
      qaLog(scope, "23/30 username and job-boost credits cannot be self-granted");

      const earlyReview = await teenA.client
        .from("reviews")
        .insert({
          job_id: jobA.result.job.id,
          reviewer_id: teenA.id,
          subject_id: adultA.id,
          rating: 5,
          body: "This review must be blocked before completion.",
        })
        .select("id");
      assertRejectedOrHidden(earlyReview, "Teen A reviewed an unfinished job");
      qaLog(scope, "24/30 review creation is blocked before completed work");

      const started = await teenA.client.rpc("update_application_status_v2", {
        p_application_id: applicationId,
        p_action: "in_progress",
      });
      assertQa(!started.error && started.data?.ok === true, "Teen A could not start accepted work");
      const completed = await adultA.client.rpc("update_application_status_v2", {
        p_application_id: applicationId,
        p_action: "completed",
      });
      assertQa(!completed.error && completed.data?.ok === true, "Adult A could not complete in-progress work");
      const firstReview = await teenA.client
        .from("reviews")
        .insert({
          job_id: jobA.result.job.id,
          reviewer_id: teenA.id,
          subject_id: adultA.id,
          rating: 5,
          body: "Safe public location and clear instructions.",
        })
        .select("id")
        .single();
      assertQa(!firstReview.error && firstReview.data?.id, "First completed-job review failed");
      const duplicateReview = await teenA.client
        .from("reviews")
        .insert({
          job_id: jobA.result.job.id,
          reviewer_id: teenA.id,
          subject_id: adultA.id,
          rating: 4,
        })
        .select("id");
      assertRejectedOrHidden(duplicateReview, "Teen A submitted a duplicate review from the same side");
      qaLog(scope, "25/30 one review per side is allowed only after completion");

      const visibleJobB = await teenA.client
        .from("jobs")
        .select("id,status")
        .eq("id", jobB.result.job.id);
      assertQa(
        !visibleJobB.error && visibleJobB.data.length === 1,
        `Teen A cannot see Adult B's saveable job: ${visibleJobB.error?.message}`,
      );
      const saved = await teenA.client
        .from("saved_jobs")
        .insert({ user_id: teenA.id, job_id: jobB.result.job.id })
        .select("job_id");
      assertQa(
        !saved.error && saved.data.length === 1,
        `Teen A could not save Adult B's job: ${saved.error?.message ?? "no row returned"}`,
      );
      const teenBSavedRead = await teenB.client
        .from("saved_jobs")
        .select("job_id")
        .eq("user_id", teenA.id);
      const teenBSavedDelete = await teenB.client
        .from("saved_jobs")
        .delete()
        .eq("user_id", teenA.id)
        .eq("job_id", jobB.result.job.id)
        .select("job_id");
      assertHidden(teenBSavedRead, "Teen B read Teen A's saved jobs");
      assertRejectedOrHidden(teenBSavedDelete, "Teen B deleted Teen A's saved job");
      qaLog(scope, "26/30 saved jobs remain owner-isolated");

      const support = await teenA.client.rpc("create_support_ticket", {
        p_subject: "Isolation QA ticket",
        p_message: "This private support ticket exists only for the multi-user QA run.",
      });
      assertQa(!support.error && support.data?.ok === true, "Teen A could not create a support ticket");
      const supportTicketId = support.data.ticket.id;
      const teenBSupport = await teenB.client
        .from("support_tickets")
        .select("id,subject")
        .eq("id", supportTicketId);
      const teenBSupportMessages = await teenB.client
        .from("support_ticket_messages")
        .select("id,body")
        .eq("ticket_id", supportTicketId);
      assertHidden(teenBSupport, "Teen B read Teen A's support ticket");
      assertHidden(teenBSupportMessages, "Teen B read Teen A's support messages");
      const block = await teenA.client
        .from("blocks")
        .insert({ blocker_id: teenA.id, blocked_id: guardianB.id })
        .select("id")
        .single();
      assertQa(!block.error && block.data?.id, "Teen A could not create an owner-bound block");
      const teenBBlock = await teenB.client.from("blocks").select("id").eq("id", block.data.id);
      const teenBBlockProbe = await teenB.client.rpc("users_are_blocked", {
        p_user_one: teenA.id,
        p_user_two: guardianB.id,
      });
      assertHidden(teenBBlock, "Teen B read Teen A's block record");
      assertQa(
        !teenBBlockProbe.error && teenBBlockProbe.data === false,
        "Teen B probed another user's block relationship through a helper RPC",
      );
      qaLog(scope, "27/30 support tickets, support messages, and blocks remain private");

      const notification = await serviceClient
        .from("notifications")
        .insert({
          recipient_id: teenA.id,
          title: "Multi-user isolation QA",
          body: "Private notification fixture",
          data: { scope },
        })
        .select("id")
        .single();
      assertQa(!notification.error && notification.data?.id, "Could not create isolated notification fixture");
      const teenANotification = await teenA.client
        .from("notifications")
        .select("id")
        .eq("id", notification.data.id);
      const teenBNotification = await teenB.client
        .from("notifications")
        .select("id")
        .eq("id", notification.data.id);
      assertQa(!teenANotification.error && teenANotification.data.length === 1, "Teen A cannot read own notification");
      assertHidden(teenBNotification, "Teen B read Teen A's notification");
      qaLog(scope, "28/30 notifications remain recipient-isolated");

      const applicationEvent = await serviceClient
        .from("application_status_events")
        .select("id")
        .eq("application_id", applicationId)
        .order("created_at", { ascending: false })
        .limit(1)
        .single();
      assertQa(!applicationEvent.error && applicationEvent.data?.id, "Application activity fixture is missing");
      for (const participant of [teenA, adultA]) {
        const ownEvent = await participant.client
          .from("application_status_events")
          .select("id")
          .eq("id", applicationEvent.data.id);
        assertQa(!ownEvent.error && ownEvent.data.length === 1, "Application participant cannot read activity history");
      }
      for (const outsider of [teenB, adultB]) {
        const hiddenEvent = await outsider.client
          .from("application_status_events")
          .select("id")
          .eq("id", applicationEvent.data.id);
        assertHidden(hiddenEvent, `${outsider.email} read unrelated application activity`);
      }
      qaLog(scope, "29/30 application activity history remains participant-isolated");

      const buckets = await serviceClient.storage.listBuckets();
      assertQa(!buckets.error, `private bucket audit failed: ${buckets.error?.message}`);
      for (const bucketName of ["profile-avatars", "proof-uploads", "verification-uploads"]) {
        const bucket = buckets.data.find((candidate) => candidate.name === bucketName);
        assertQa(bucket?.public === false, `${bucketName} is not private`);
        const anonymousList = await anonymousClient.storage.from(bucketName).list();
        assertQa(
          anonymousList.error || anonymousList.data.length === 0,
          `anonymous client listed ${bucketName}`,
        );
        const unrelatedList = await teenB.client.storage.from(bucketName).list(teenA.id);
        assertQa(
          unrelatedList.error || unrelatedList.data.length === 0,
          `unrelated user listed Teen A objects in ${bucketName}`,
        );
      }
      const unsupportedAvatar = await teenA.client.storage
        .from("profile-avatars")
        .upload(`${teenA.id}/qa-unsupported.txt`, Uint8Array.from([1, 2, 3]), {
          contentType: "text/plain",
          upsert: false,
        });
      assertQa(unsupportedAvatar.error, "private avatar bucket accepted an unsupported MIME type");
      qaLog(scope, "30/30 private buckets deny anonymous listing, cross-user listing, and unsupported MIME uploads");
    } finally {
      await serviceClient.storage.from("profile-avatars").remove([avatarPath]);
    }
  },
);

qaLog(scope, "all 30 multi-user isolation checks passed");
