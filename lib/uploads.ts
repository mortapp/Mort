import * as ImagePicker from "expo-image-picker";

import { supabase } from "@/lib/supabase";

export type PickedUpload = {
  storagePath: string;
};

export async function pickAndUploadImage(bucket: "proof-uploads" | "verification-uploads" | "report-uploads", userId: string) {
  const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
  if (!permission.granted) {
    throw new Error("Photo library permission is required for this upload.");
  }

  const result = await ImagePicker.launchImageLibraryAsync({
    mediaTypes: ["images"],
    quality: 0.82,
    allowsEditing: false
  });

  if (result.canceled || !result.assets[0]) {
    return null;
  }

  const asset = result.assets[0];
  const extension = asset.fileName?.split(".").pop()?.toLowerCase() ?? "jpg";
  const path = `${userId}/${Date.now()}-${Math.random().toString(36).slice(2)}.${extension}`;
  const response = await fetch(asset.uri);
  const blob = await response.blob();

  const { error } = await supabase.storage.from(bucket).upload(path, blob, {
    contentType: asset.mimeType ?? "image/jpeg",
    upsert: false
  });

  if (error) {
    throw error;
  }

  return {
    storagePath: path
  } satisfies PickedUpload;
}

export async function createSignedUploadPreviewUrl(
  bucket: "proof-uploads" | "verification-uploads" | "report-uploads",
  path: string,
  expiresInSeconds = 60 * 10
) {
  const { data, error } = await supabase.storage.from(bucket).createSignedUrl(path, expiresInSeconds);
  if (error) throw error;
  return data.signedUrl;
}
