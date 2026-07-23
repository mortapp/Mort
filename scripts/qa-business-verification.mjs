import { randomUUID } from "node:crypto";

import {
  assertQa,
  qaLog,
  serviceClient,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const scope = "qa-business-verification";

await withQaUsers(
  scope,
  [
    { key: "adult", role: "adult" },
    { key: "otherAdult", role: "adult" },
  ],
  async ({ adult, otherAdult }) => {
    const verificationId = randomUUID();
    const path = `${adult.id}/${verificationId}.jpg`;
    const image = Buffer.from([0xff, 0xd8, 0xff, 0xd9]);
    try {
      const direct = await adult.client
        .from("business_verifications")
        .insert({
          adult_id: adult.id,
          business_name: "Direct bypass",
          business_type: "individual",
          document_storage_path: path,
        })
        .select("id");
      assertQa(direct.error || direct.data.length === 0, "adult bypassed verification RPC");

      const stored = await adult.client.storage
        .from("verification-uploads")
        .upload(path, image, { contentType: "image/jpeg", upsert: false });
      assertQa(!stored.error, `verification object upload failed: ${stored.error?.message}`);

      const unrelated = await otherAdult.client.rpc("submit_business_verification", {
        p_verification_id: verificationId,
        p_storage_path: path,
        p_business_name: "Unrelated adult",
        p_business_type: "individual",
        p_notes: null,
      });
      assertQa(!unrelated.error && unrelated.data?.ok === false, "unrelated adult attached another user's document");

      const submitted = await adult.client.rpc("submit_business_verification", {
        p_verification_id: verificationId,
        p_storage_path: path,
        p_business_name: "QA Adult Account",
        p_business_type: "individual",
        p_notes: "Internal verification QA",
      });
      assertQa(!submitted.error && submitted.data?.ok === true, `verification RPC failed: ${submitted.error?.message}`);
      assertQa(submitted.data.idempotent === false, "first verification submit was marked idempotent");

      const retried = await adult.client.rpc("submit_business_verification", {
        p_verification_id: verificationId,
        p_storage_path: path,
        p_business_name: "QA Adult Account",
        p_business_type: "individual",
        p_notes: "Retry",
      });
      assertQa(!retried.error && retried.data?.idempotent === true, "verification retry was not idempotent");

      const profile = await adult.client
        .rpc("get_my_profile")
        .single();
      assertQa(
        profile.data?.verification_status === "approved",
        "business trust submission changed the separate identity status",
      );

      const ownerRead = await adult.client
        .from("business_verifications")
        .select("id,status")
        .eq("id", verificationId);
      const unrelatedRead = await otherAdult.client
        .from("business_verifications")
        .select("id")
        .eq("id", verificationId);
      assertQa(
        ownerRead.data?.length === 1 && ownerRead.data[0].status === "pending",
        "owner cannot read the pending business verification request",
      );
      assertQa(unrelatedRead.data?.length === 0, "unrelated adult can read private verification request");

      const attachedDelete = await adult.client.storage
        .from("verification-uploads")
        .remove([path]);
      assertQa(attachedDelete.error || attachedDelete.data.length === 0, "adult deleted attached verification evidence");
      qaLog(scope, "private verification submission is idempotent, isolated, and evidence-preserving");
    } finally {
      await serviceClient.storage.from("verification-uploads").remove([path]);
    }
  },
);
