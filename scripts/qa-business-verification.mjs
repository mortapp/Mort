import { randomUUID } from "node:crypto";

import {
  assertQa,
  qaLog,
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
    assertQa(stored.error, "adult uploaded identity or business evidence directly to MORT storage");

    for (const actor of [adult, otherAdult]) {
      const submitted = await actor.client.rpc("submit_business_verification", {
        p_verification_id: verificationId,
        p_storage_path: path,
        p_business_name: "QA Adult Account",
        p_business_type: "individual",
        p_notes: "Provider-boundary QA",
      });
      assertQa(!submitted.error, `provider-required RPC contract failed: ${submitted.error?.message}`);
      assertQa(submitted.data?.ok === false, "legacy business verification submission remained open");
      assertQa(
        submitted.data?.code === "business_verification_provider_required",
        "legacy business verification returned an unsafe or ambiguous status",
      );
    }

    const ownerRead = await adult.client
      .from("business_verifications")
      .select("id")
      .eq("id", verificationId);
    const unrelatedRead = await otherAdult.client
      .from("business_verifications")
      .select("id")
      .eq("id", verificationId);
    assertQa(ownerRead.data?.length === 0, "closed workflow created a business verification record");
    assertQa(unrelatedRead.data?.length === 0, "unrelated adult can read a private verification request");

    qaLog(
      scope,
      "legacy business document uploads and submissions are closed pending an approved provider",
    );
  },
);
