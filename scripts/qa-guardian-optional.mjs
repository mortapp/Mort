import {
  assertQa,
  qaLog,
  saveJob,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const scope = "qa-guardian-optional";

await withQaUsers(
  scope,
  [
    { key: "teen", role: "teen" },
    { key: "adult", role: "adult" },
    { key: "guardian", role: "guardian" },
    { key: "unrelatedGuardian", role: "guardian" },
  ],
  async ({ teen, adult, guardian, unrelatedGuardian }) => {
    const policy = await teen.client.rpc("get_guardian_policy_for_user");
    assertQa(!policy.error, `guardian policy RPC failed: ${policy.error?.message}`);
    assertQa(policy.data?.guardian_link_required === false, "guardian linking must default to optional");
    assertQa(
      policy.data?.guardian_approval_required_for_application === false,
      "application approval must default to optional",
    );
    assertQa(
      policy.data?.guardian_approval_required_for_job === false,
      "job guardian approval must default to optional",
    );
    qaLog(scope, "jurisdiction policy defaults all guardian requirements to false");

    const skipped = await teen.client.rpc("set_guardian_setup_skipped");
    assertQa(!skipped.error && skipped.data?.ok === true, `skip setup failed: ${skipped.error?.message}`);
    const profileAfterSkip = await teen.client
      .rpc("get_my_profile")
      .single();
    assertQa(!profileAfterSkip.error, `profile after skip failed: ${profileAfterSkip.error?.message}`);
    assertQa(profileAfterSkip.data.guardian_setup_status === "skipped", "guardian setup was not marked skipped");
    assertQa(profileAfterSkip.data.onboarding_completed === true, "skipping guardian changed onboarding completion");
    qaLog(scope, "skipping Guardian Mode preserves completed onboarding and active account access");

    const created = await saveJob(adult.client);
    assertQa(created.result?.ok === true && created.result?.job?.status === "open", "optional-guardian job did not publish");
    assertQa(created.result.job.requires_guardian_approval === false, "job unexpectedly requires guardian approval");

    const eligibility = await teen.client.rpc("get_job_application_eligibility", {
      p_job_id: created.result.job.id,
    });
    assertQa(!eligibility.error, `eligibility RPC failed: ${eligibility.error?.message}`);
    assertQa(eligibility.data?.eligible === true, `skipped guardian blocked application: ${JSON.stringify(eligibility.data)}`);
    qaLog(scope, "teen without a guardian is eligible for a normal job");

    const application = await teen.client.rpc("submit_job_application", {
      p_job_id: created.result.job.id,
      p_note: "I am available this weekend and have organizing experience.",
      p_availability_confirmed: true,
      p_portfolio_ids: [],
    });
    assertQa(!application.error && application.data?.ok === true, `application failed: ${application.error?.message}`);
    assertQa(application.data.application.status === "adult_review", "normal application did not go to adult review");
    assertQa(application.data.application.guardian_id === null, "normal application unexpectedly stored a guardian");
    qaLog(scope, "skipping Guardian Mode does not block real application insertion");

    const invite = await teen.client.rpc("create_guardian_invite_v2", {
      p_invite_email: guardian.email,
    });
    assertQa(!invite.error && invite.data?.ok === true, `invite failed: ${invite.error?.message}`);
    assertQa(typeof invite.data.invite_code === "string", "invite did not return a one-time code");

    const accepted = await guardian.client.rpc("accept_guardian_invite", {
      p_invite_code: invite.data.invite_code,
    });
    assertQa(!accepted.error && accepted.data, `invite acceptance failed: ${accepted.error?.message}`);

    const activeLink = await teen.client
      .from("guardian_connections")
      .select("id,status,guardian_id,guardian_preferences(*)")
      .eq("teen_id", teen.id)
      .eq("status", "active")
      .single();
    assertQa(!activeLink.error, `active link query failed: ${activeLink.error?.message}`);
    assertQa(activeLink.data.guardian_id === guardian.id, "accepted link has the wrong guardian");
    qaLog(scope, "hashed invite flow created one active Guardian Mode connection");

    const unrelatedRead = await unrelatedGuardian.client
      .from("guardian_connections")
      .select("id")
      .eq("id", activeLink.data.id);
    assertQa(!unrelatedRead.error && unrelatedRead.data.length === 0, "unrelated guardian could read the link");
    qaLog(scope, "unrelated guardian cannot read another teen's connection");

    const preferenceUpdate = await teen.client
      .from("guardian_preferences")
      .update({ weekly_digest: true, optional_job_approval_enabled: true })
      .eq("link_id", activeLink.data.id)
      .select("link_id,weekly_digest,optional_job_approval_enabled")
      .single();
    assertQa(!preferenceUpdate.error, `teen preference update failed: ${preferenceUpdate.error?.message}`);
    assertQa(preferenceUpdate.data.weekly_digest === true, "weekly digest preference did not persist");

    const guardianPreferenceWrite = await guardian.client
      .from("guardian_preferences")
      .update({ weekly_digest: false })
      .eq("link_id", activeLink.data.id)
      .select("link_id");
    assertQa(
      guardianPreferenceWrite.error || guardianPreferenceWrite.data.length === 0,
      "guardian modified teen-controlled privacy preferences",
    );
    qaLog(scope, "only the teen can modify per-link sharing preferences");

    const safetyPing = await teen.client
      .from("safety_pings")
      .insert({ teen_id: teen.id, status: "ok", note: "Guardian delivery QA" })
      .select("id")
      .single();
    assertQa(!safetyPing.error, `safety ping insert failed: ${safetyPing.error?.message}`);
    const guardianPing = await guardian.client
      .from("safety_pings")
      .select("id")
      .eq("id", safetyPing.data.id);
    const unrelatedPing = await unrelatedGuardian.client
      .from("safety_pings")
      .select("id")
      .eq("id", safetyPing.data.id);
    const guardianNotification = await guardian.client
      .from("notifications")
      .select("id")
      .contains("data", { safetyPingId: safetyPing.data.id });
    assertQa(guardianPing.data?.length === 1, "linked guardian cannot read an enabled Safety Ping");
    assertQa(unrelatedPing.data?.length === 0, "unrelated guardian can read another teen's Safety Ping");
    assertQa(guardianNotification.data?.length === 1, "linked guardian did not receive a Safety Ping notification");
    qaLog(scope, "Safety Ping visibility and notification delivery follow active link preferences");

    const unlinked = await teen.client.rpc("unlink_guardian", {
      p_link_id: activeLink.data.id,
    });
    assertQa(!unlinked.error && unlinked.data?.ok === true, `unlink failed: ${unlinked.error?.message}`);
    const profileAfterUnlink = await teen.client
      .rpc("get_my_profile")
      .single();
    assertQa(profileAfterUnlink.data.account_status === "active", "unlink restricted the teen account");
    assertQa(profileAfterUnlink.data.onboarding_completed === true, "unlink reset onboarding");

    const guardianRequestedJob = await saveJob(adult.client, {
      title: "QA Feature Public Shelf Labels",
      summary: "Place new labels on public library shelves with staff nearby.",
      requires_guardian_approval: true,
    });
    const guardianRequiredEligibility = await teen.client.rpc("get_job_application_eligibility", {
      p_job_id: guardianRequestedJob.result.job.id,
    });
    assertQa(
      guardianRequiredEligibility.data?.code === "guardian_link_required",
      `specific guardian job returned ${guardianRequiredEligibility.data?.code}`,
    );
    qaLog(scope, "a poster-requested guardian job returns a specific guardian error after unlink");

    const normalAfterUnlink = await saveJob(adult.client, {
      title: "QA Feature Normal Job After Unlink",
      summary: "A normal safe job remains available after Guardian Mode unlinking.",
    });
    const afterUnlinkEligibility = await teen.client.rpc("get_job_application_eligibility", {
      p_job_id: normalAfterUnlink.result.job.id,
    });
    assertQa(afterUnlinkEligibility.data?.eligible === true, "unlinking blocked later normal job applications");
    qaLog(scope, "unlinking stops future guardian access without locking teen features");
  },
);
