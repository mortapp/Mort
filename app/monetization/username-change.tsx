import { AppHeader } from "@/components/DesignSystem";
import { MonetizationDisclaimer, RestorePurchasesButton, TeenMonetizationSafetyNotice } from "@/components/Monetization";
import { UsernameTokenPurchaseCard } from "@/components/UsernameChange";
import { Screen } from "@/components/Screen";

export default function UsernameChangePaywallScreen() {
  return (
    <Screen>
      <AppHeader
        title="Username token"
        subtitle="You used your 3 free username changes. Another change is optional; your account still works."
      />
      <TeenMonetizationSafetyNotice />
      <UsernameTokenPurchaseCard />
      <RestorePurchasesButton />
      <MonetizationDisclaimer />
    </Screen>
  );
}
