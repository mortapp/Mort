import { useEffect, useState } from "react";
import { Pressable, StyleSheet, View } from "react-native";

import { Button } from "@/components/Button";
import { Card } from "@/components/Card";
import { ErrorBanner } from "@/components/ErrorBanner";
import { Field } from "@/components/Field";
import { Text } from "@/components/Text";
import { getPaymentPreference, savePaymentPreference } from "@/lib/data";
import { PAYMENT_DISCLAIMER } from "@/lib/disclaimers";
import { colors, spacing } from "@/lib/theme";
import type { PaymentPreference, Profile } from "@/types/domain";

const preferences: { label: string; value: PaymentPreference }[] = [
  { label: "None", value: "none" },
  { label: "Cash", value: "cash" },
  { label: "Cash App", value: "cash_app" },
  { label: "Square link", value: "square_link" },
  { label: "Flexible", value: "flexible" }
];

type PaymentPreferenceEditorProps = {
  profile: Profile | null;
  userId: string | null;
  onSaved: () => Promise<void>;
};

export function PaymentPreferenceEditor({ profile, userId, onSaved }: PaymentPreferenceEditorProps) {
  const [preference, setPreference] = useState<PaymentPreference>(profile?.payment_preference ?? "none");
  const [cashAppTag, setCashAppTag] = useState("");
  const [squareUrl, setSquareUrl] = useState("");
  const [note, setNote] = useState("");
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const id = userId ?? "";
    if (!id) return;
    let active = true;

    async function loadPaymentPreference() {
      try {
        const record = await getPaymentPreference(id);
        if (!active || !record) return;
        setPreference(record.preference);
        setCashAppTag(record.cash_app_tag ?? "");
        setSquareUrl(record.square_url ?? "");
        setNote(record.note ?? "");
      } catch {
        if (active) setError("Unable to load payment preference details.");
      }
    }

    void loadPaymentPreference();

    return () => {
      active = false;
    };
  }, [userId]);

  async function save() {
    if (!userId) return;
    setBusy(true);
    setError(null);
    setMessage(null);
    try {
      await savePaymentPreference(userId, { preference, cashAppTag, squareUrl, note });
      await onSaved();
      setMessage("Payment preference saved.");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to save payment preference.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <Card>
      <Text variant="subtitle">Payment preference only</Text>
      <Text color={colors.muted}>{PAYMENT_DISCLAIMER}</Text>
      <View style={styles.options}>
        {preferences.map((item) => (
          <Pressable
            accessibilityRole="button"
            key={item.value}
            onPress={() => setPreference(item.value)}
            style={[styles.option, preference === item.value ? styles.selected : null]}
          >
            <Text variant="label">{item.label}</Text>
          </Pressable>
        ))}
      </View>
      {preference === "cash_app" ? <Field autoCapitalize="none" label="Cash App tag" onChangeText={setCashAppTag} placeholder="$MortUser" value={cashAppTag} /> : null}
      {preference === "square_link" ? (
        <Field autoCapitalize="none" keyboardType="url" label="Square invoice/payment link" onChangeText={setSquareUrl} placeholder="https://square.link/..." value={squareUrl} />
      ) : null}
      <Field label="Payment note" maxLength={240} multiline onChangeText={setNote} placeholder="Optional, keep details in-app." value={note} />
      <ErrorBanner message={error} />
      {message ? <Text color={colors.success}>{message}</Text> : null}
      <Button disabled={busy || !userId} title={busy ? "Saving..." : "Save payment preference"} onPress={save} />
    </Card>
  );
}

const styles = StyleSheet.create({
  options: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: spacing.sm
  },
  option: {
    borderColor: colors.border,
    borderRadius: 8,
    borderWidth: 1,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm
  },
  selected: {
    borderColor: colors.primary,
    backgroundColor: "#10251d"
  }
});
