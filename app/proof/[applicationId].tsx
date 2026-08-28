import { useLocalSearchParams } from "expo-router";
import { useEffect, useState } from "react";
import * as Linking from "expo-linking";

import { Button } from "@/components/Button";
import { Card } from "@/components/Card";
import { EmptyState } from "@/components/EmptyState";
import { ErrorBanner } from "@/components/ErrorBanner";
import { Field } from "@/components/Field";
import { Screen } from "@/components/Screen";
import { Text } from "@/components/Text";
import { addProofUpload, getApplication, listProofUploads } from "@/lib/data";
import { colors } from "@/lib/theme";
import { createSignedUploadPreviewUrl, pickAndUploadImage } from "@/lib/uploads";
import { useAuth } from "@/providers/AuthProvider";
import type { Application, ProofUpload } from "@/types/domain";

export default function ProofUploadScreen() {
  const { applicationId } = useLocalSearchParams<{ applicationId: string }>();
  const { profile, user } = useAuth();
  const [storagePath, setStoragePath] = useState<string | null>(null);
  const [note, setNote] = useState("");
  const [application, setApplication] = useState<Application | null>(null);
  const [proofs, setProofs] = useState<ProofUpload[]>([]);
  const [loading, setLoading] = useState(true);
  const [signedUrls, setSignedUrls] = useState<Record<string, string>>({});
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const canUploadProof = Boolean(profile?.role === "teen" && application && application.teen_id === user?.id && application.status === "accepted");

  async function loadProofs() {
    if (!applicationId) return;
    setLoading(true);
    setError(null);
    try {
      const [nextApplication, nextProofs] = await Promise.all([getApplication(applicationId), listProofUploads(applicationId)]);
      setApplication(nextApplication);
      setProofs(nextProofs);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to load proof uploads.");
    } finally {
      setLoading(false);
    }
  }

  async function pickProof() {
    if (!user || !canUploadProof) return;
    setError(null);
    try {
      const result = await pickAndUploadImage("proof-uploads", user.id);
      if (result) setStoragePath(result.storagePath);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to upload proof image.");
    }
  }

  async function openProof(proof: ProofUpload) {
    setError(null);
    try {
      const existing = signedUrls[proof.id];
      const signedUrl = existing ?? (await createSignedUploadPreviewUrl("proof-uploads", proof.storage_path));
      setSignedUrls((current) => ({ ...current, [proof.id]: signedUrl }));
      await Linking.openURL(signedUrl);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to open signed proof preview.");
    }
  }

  async function save() {
    if (!user || !applicationId || !storagePath || !canUploadProof) return;
    setError(null);
    setMessage(null);
    try {
      await addProofUpload({
        applicationId,
        uploadedBy: user.id,
        storagePath,
        note
      });
      setMessage("Proof saved to the application.");
      setStoragePath(null);
      setNote("");
      await loadProofs();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to save proof.");
    }
  }

  useEffect(() => {
    if (!applicationId) return;
    let active = true;

    async function loadInitialProofs() {
      try {
        const [nextApplication, rows] = await Promise.all([getApplication(applicationId), listProofUploads(applicationId)]);
        if (!active) return;
        setApplication(nextApplication);
        setProofs(rows);
        setError(null);
      } catch (err) {
        if (!active) return;
        setError(err instanceof Error ? err.message : "Unable to load proof uploads.");
      } finally {
        if (active) setLoading(false);
      }
    }

    void loadInitialProofs();

    return () => {
      active = false;
    };
  }, [applicationId]);

  return (
    <Screen>
      <Text variant="title">Proof upload</Text>
      {application ? (
        <Card>
          <Text variant="subtitle">{application.jobs?.title ?? "Application proof"}</Text>
          <Text variant="caption">Application status: {application.status}</Text>
          {canUploadProof ? (
            <Text>Upload proof after the adult accepts the application. Adults, guardians, and admins can review existing proof through signed previews.</Text>
          ) : (
            <Text color={colors.muted}>Proof uploads are limited to the teen on an accepted application. Reviewers can open existing proof with signed URLs.</Text>
          )}
        </Card>
      ) : null}
      {proofs.length === 0 && !loading ? (
        <EmptyState title="No proof yet" body="Uploaded proof for this application will appear here for participants and admins." />
      ) : null}
      {proofs.map((proof) => (
        <Card key={proof.id}>
          <Text variant="subtitle">Proof record</Text>
          <Text>{proof.note || "No note"}</Text>
          <Text variant="caption">Private storage path: {proof.storage_path}</Text>
          <Text variant="caption">{new Date(proof.created_at).toLocaleString()}</Text>
          <Button title="Open signed preview" variant="secondary" onPress={() => openProof(proof)} />
        </Card>
      ))}
      {canUploadProof ? (
        <Card>
          <Text>Upload completion proof or safety-relevant job evidence from your photo library.</Text>
          <Button title={storagePath ? "Replace image" : "Choose image"} variant="secondary" onPress={pickProof} />
          {storagePath ? <Text variant="caption">Uploaded: {storagePath}</Text> : null}
          <Field label="Proof note" multiline onChangeText={setNote} value={note} />
          <ErrorBanner message={error} />
          {message ? <Text color={colors.success}>{message}</Text> : null}
          <Button disabled={!storagePath} title="Save proof" onPress={save} />
        </Card>
      ) : (
        <ErrorBanner message={error} />
      )}
    </Screen>
  );
}
