import { randomUUID } from "node:crypto";

import {
  assertQa,
  confirmSafetyAgreement,
  qaLog,
  saveJob,
  updateApplicationStatus,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const scope = "qa-reviews";

await withQaUsers(
  scope,
  [
    { key: "adult", role: "adult" },
    { key: "teen", role: "teen" },
    { key: "otherTeen", role: "teen" },
  ],
  async ({ adult, teen, otherTeen }) => {
    const job = await saveJob(adult.client, {
      title: "QA Feature Review Lifecycle",
      summary: "A completed-job fixture for two-sided review RLS checks.",
    });
    assertQa(job.result?.ok === true, "review fixture job did not publish");

    const early = await teen.client
      .from("reviews")
      .insert({
        job_id: job.result.job.id,
        reviewer_id: teen.id,
        subject_id: adult.id,
        rating: 5,
        body: "This should not be accepted before completion.",
      })
      .select("id");
    assertQa(early.error || early.data.length === 0, "review was accepted before job completion");
    qaLog(scope, "reviews are blocked before completed job/application state");

    const application = await teen.client.rpc("submit_job_application", {
      p_job_id: job.result.job.id,
      p_note: "Available for the review lifecycle QA job.",
      p_availability_confirmed: true,
      p_portfolio_ids: [],
    });
    assertQa(application.data?.ok === true, "review fixture application failed");
    const applicationId = application.data.application.id;

    for (const [client, action] of [
      [adult.client, "accepted"],
      [teen.client, "in_progress"],
      [adult.client, "completed"],
    ]) {
      const transition = await updateApplicationStatus(client, {
        applicationId,
        action,
      });
      assertQa(transition.data?.ok === true, `${action} transition failed for review fixture`);
      if (action === "accepted") {
        await confirmSafetyAgreement(teen.client, adult.client, applicationId);
      }
    }

    const teenReview = await teen.client
      .from("reviews")
      .insert({
        job_id: job.result.job.id,
        reviewer_id: teen.id,
        subject_id: adult.id,
        rating: 5,
        body: "Clear instructions and safe public work area.",
      })
      .select("id,moderation_status")
      .single();
    assertQa(!teenReview.error, `teen review failed: ${teenReview.error?.message}`);
    assertQa(teenReview.data.moderation_status === "pending_review", "new review bypassed moderation queue");

    const adultCanSee = await adult.client
      .from("reviews")
      .select("id")
      .eq("id", teenReview.data.id);
    assertQa(!adultCanSee.error && adultCanSee.data.length === 0, "review subject saw pending blind-review content");
    const authorCanSee = await teen.client
      .from("reviews")
      .select("id")
      .eq("id", teenReview.data.id);
    assertQa(!authorCanSee.error && authorCanSee.data.length === 1, "review author cannot see their pending review");
    const unrelatedCannotSee = await otherTeen.client
      .from("reviews")
      .select("id")
      .eq("id", teenReview.data.id);
    assertQa(!unrelatedCannotSee.error && unrelatedCannotSee.data.length === 0, "unrelated user saw pending review");
    qaLog(scope, "pending blind reviews are visible only to their author and restricted moderation roles");

    const duplicate = await teen.client
      .from("reviews")
      .insert({
        job_id: job.result.job.id,
        reviewer_id: teen.id,
        subject_id: adult.id,
        rating: 4,
      })
      .select("id");
    assertQa(duplicate.error || duplicate.data.length === 0, "same side submitted a second review");

    const adultReview = await adult.client
      .from("reviews")
      .insert({
        job_id: job.result.job.id,
        reviewer_id: adult.id,
        subject_id: teen.id,
        rating: 5,
        body: "Reliable work and clear in-app communication.",
      })
      .select("id,moderation_status")
      .single();
    assertQa(!adultReview.error, `adult review failed: ${adultReview.error?.message}`);
    const teenRevealState = await teen.client
      .from("reviews")
      .select("revealed_at")
      .eq("id", teenReview.data.id)
      .single();
    const adultRevealState = await adult.client
      .from("reviews")
      .select("revealed_at")
      .eq("id", adultReview.data.id)
      .single();
    assertQa(
      !teenRevealState.error &&
        !adultRevealState.error &&
        teenRevealState.data.revealed_at &&
        adultRevealState.data.revealed_at,
      "mutual review submission did not set blind-reveal timestamps",
    );
    const teenCannotSeePendingAdultReview = await teen.client
      .from("reviews")
      .select("id")
      .eq("id", adultReview.data.id);
    assertQa(
      !teenCannotSeePendingAdultReview.error && teenCannotSeePendingAdultReview.data.length === 0,
      "mutual reveal bypassed moderation approval",
    );
    qaLog(scope, "one review per side sets mutual reveal state without bypassing moderation");

    const unrelatedInsert = await otherTeen.client
      .from("reviews")
      .insert({
        job_id: job.result.job.id,
        reviewer_id: otherTeen.id,
        subject_id: adult.id,
        rating: 1,
      })
      .select("id");
    assertQa(unrelatedInsert.error || unrelatedInsert.data.length === 0, "unrelated user reviewed the job");

    const report = await adult.client.rpc("submit_safety_report_v2", {
      p_target_user_id: null,
      p_target_job_id: null,
      p_target_message_id: null,
      p_target_review_id: teenReview.data.id,
      p_application_id: null,
      p_category: "other_urgent_concern",
      p_severity: "moderate",
      p_immediate_danger: false,
      p_details: "QA verifies that review reports enter the private incident and moderation workflow.",
      p_occurred_at: null,
      p_location_type: null,
      p_desired_outcome: "Review the submitted review for policy compliance.",
      p_confidential_safety_feedback: false,
      p_client_request_id: randomUUID(),
    });
    assertQa(
      !report.error && report.data?.ok === true && report.data?.incident_id,
      "review report did not enter the checked incident workflow",
    );
    const cases = await adult.client.rpc("get_my_incident_cases");
    assertQa(
      !cases.error && cases.data.some((incident) => incident.incident_id === report.data.incident_id),
      "review reporter cannot see the participant-safe case status",
    );
    qaLog(scope, "review reporting creates a private incident with participant-safe status");
  },
);
