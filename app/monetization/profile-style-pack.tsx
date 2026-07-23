import { AppHeader, AppSelect, FeatureLockCard, PremiumBadge } from "@/components/DesignSystem";
import { MonetizationDisclaimer, RestorePurchasesButton } from "@/components/Monetization";
import { Screen } from "@/components/Screen";
import { Text } from "@/components/Text";
import { useState } from "react";

const themeOptions = [
  { label: "Neon green", value: "neon" },
  { label: "Safety blue", value: "safety" },
  { label: "Premium purple", value: "premium" }
] as const;

export default function ProfileStylePackScreen() {
  const [theme, setTheme] = useState<(typeof themeOptions)[number]["value"]>("neon");

  return (
    <Screen>
      <AppHeader title="Profile style pack" subtitle="Cosmetic only. No safety, hiring, or ranking advantage." right={<PremiumBadge />} />
      <FeatureLockCard
        title="Profile Style Pack"
        body="Suggested product: mort_profile_style_pack at $0.99 one-time. Actual checkout price must come from RevenueCat."
        cta="Optional"
      />
      <AppSelect label="Preview accent" options={[...themeOptions]} value={theme} onChange={setTheme} />
      <Text>Preview only until RevenueCat products and theme unlocks are configured.</Text>
      <RestorePurchasesButton />
      <MonetizationDisclaimer />
    </Screen>
  );
}
