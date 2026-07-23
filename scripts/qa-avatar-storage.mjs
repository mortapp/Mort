import { randomUUID } from "node:crypto";

import {
  assertQa,
  qaLog,
  serviceClient,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const scope = "qa-avatar-storage";
const bucket = "profile-avatars";
const jpegBytes = Uint8Array.from(
  Buffer.from(
    "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////2wBDAf//////////////////////////////////////////////////////////////////////////////////////wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAX/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIQAxAAAAF//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABBQJ//8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAwEBPwF//8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAgEBPwF//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQAGPwJ//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPyF//9oADAMBAAIAAwAAABD/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oACAEDAQE/EB//xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oACAECAQE/EB//xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oACAEBAAE/EB//2Q==",
    "base64",
  ),
);

await withQaUsers(
  scope,
  [
    { key: "owner", role: "teen" },
    { key: "other", role: "teen" },
  ],
  async ({ owner, other }) => {
    const buckets = await serviceClient.storage.listBuckets();
    assertQa(!buckets.error, `bucket list failed: ${buckets.error?.message}`);
    const avatarBucket = buckets.data.find((item) => item.name === bucket);
    assertQa(avatarBucket, "profile-avatars bucket is missing");
    assertQa(avatarBucket.public === false, "profile-avatars bucket is public");
    assertQa(Number(avatarBucket.file_size_limit) === 5 * 1024 * 1024, "avatar bucket limit is not 5 MB");
    assertQa(
      avatarBucket.allowed_mime_types?.length === 1 &&
        avatarBucket.allowed_mime_types[0] === "image/jpeg",
      "avatar bucket must allow only the canonical JPEG upload format",
    );
    qaLog(scope, "private bucket enforces 5 MB and JPEG-only configuration");

    const firstPath = `${owner.id}/${randomUUID()}.jpg`;
    const uploaded = await owner.client.storage.from(bucket).upload(firstPath, jpegBytes, {
      contentType: "image/jpeg",
      upsert: false,
    });
    assertQa(!uploaded.error, `owner upload failed: ${uploaded.error?.message}`);

    const profileUpdate = await owner.client
      .from("profiles")
      .update({ avatar_path: firstPath, avatar_moderation_status: "active" })
      .eq("id", owner.id)
      .select("avatar_path")
      .single();
    assertQa(!profileUpdate.error && profileUpdate.data.avatar_path === firstPath, "avatar path did not persist");
    qaLog(scope, "owner can upload and attach only an owner-prefixed avatar path");

    const otherOverwrite = await other.client.storage
      .from(bucket)
      .upload(`${owner.id}/${randomUUID()}.jpg`, jpegBytes, {
        contentType: "image/jpeg",
        upsert: false,
      });
    assertQa(otherOverwrite.error, "unrelated user uploaded into the owner's folder");

    const otherDownload = await other.client.storage.from(bucket).download(firstPath);
    assertQa(otherDownload.error, "unrelated user directly downloaded private avatar storage");
    const otherList = await other.client.storage.from(bucket).list(owner.id);
    assertQa(otherList.error || otherList.data.length === 0, "unrelated user listed the owner's avatar folder");
    qaLog(scope, "unrelated user cannot overwrite, list, or directly download private avatar objects");

    const displayUrl = await owner.client.functions.invoke("avatar-url", {
      body: { profileId: owner.id },
    });
    assertQa(
      !displayUrl.error,
      `avatar-url invocation failed: ${displayUrl.error?.message}; response=${JSON.stringify(displayUrl.data)}`,
    );
    assertQa(typeof displayUrl.data?.signedUrl === "string", "avatar-url did not return a signed display URL");
    const unrelatedDisplay = await other.client.functions.invoke("avatar-url", {
      body: { profileId: owner.id },
    });
    assertQa(!unrelatedDisplay.error, `unrelated avatar lookup failed: ${unrelatedDisplay.error?.message}`);
    assertQa(unrelatedDisplay.data?.signedUrl === null, "unrelated account received a private avatar URL");
    qaLog(scope, "authorized display receives a signed URL while an unrelated account receives no URL");

    const unsupported = await owner.client.storage
      .from(bucket)
      .upload(`${owner.id}/qa-unsupported.txt`, Uint8Array.from([1, 2, 3]), {
        contentType: "text/plain",
        upsert: false,
      });
    assertQa(unsupported.error, "unsupported MIME upload unexpectedly succeeded");

    const secondPath = `${owner.id}/${randomUUID()}.jpg`;
    const replacement = await owner.client.storage.from(bucket).upload(secondPath, jpegBytes, {
      contentType: "image/jpeg",
      upsert: false,
    });
    assertQa(!replacement.error, `replacement upload failed: ${replacement.error?.message}`);
    const replacementProfile = await owner.client
      .from("profiles")
      .update({ avatar_path: secondPath })
      .eq("id", owner.id)
      .select("avatar_path")
      .single();
    assertQa(replacementProfile.data?.avatar_path === secondPath, "replacement path did not persist");
    const removedOld = await owner.client.storage.from(bucket).remove([firstPath]);
    assertQa(!removedOld.error, `old avatar cleanup failed: ${removedOld.error?.message}`);
    qaLog(scope, "avatar replacement updates the profile and removes the stale object");

    const cleared = await owner.client
      .from("profiles")
      .update({ avatar_path: null })
      .eq("id", owner.id)
      .select("avatar_path")
      .single();
    assertQa(!cleared.error && cleared.data.avatar_path === null, "avatar removal did not restore null fallback");
    const removedReplacement = await owner.client.storage.from(bucket).remove([secondPath]);
    assertQa(!removedReplacement.error, "replacement object cleanup failed");
    qaLog(scope, "remove avatar restores the initials fallback state");
  },
);
