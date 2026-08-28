import { AppHeader, FeatureLockCard, SafetyBanner } from "@/components/DesignSystem";
import { BoostPaywall } from "@/components/monetization/BoostPaywall";
import { RestorePurchasesButton } from "@/components/Monetization";
import { Screen } from "@/components/Screen";

export default function JobBoostScreen() {
  return (
    <Screen>
      <AppHeader title="Job boost" subtitle="Optional adult/business visibility. Safety review always wins." />
      <SafetyBanner>
        Boosts cannot override moderation, verification, job safety checks, age limits, report/block systems, or admin review.
      </SafetyBanner>
      <BoostPaywall />
      <FeatureLockCard
        title="Suggested setup"
        body="Suggested product: mort_job_boost_1 at $1.99 one-time. Actual checkout price must come from RevenueCat."
        cta="Dashboard setup"
      />
      <RestorePurchasesButton />
    </Screen>
  );
}
