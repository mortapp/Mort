import { AppHeader } from "@/components/DesignSystem";
import { MonetizationDisclaimer, PaywallCard, RestorePurchasesButton, TeenMonetizationSafetyNotice } from "@/components/Monetization";
import { Screen } from "@/components/Screen";

export default function PaywallScreen() {
  return (
    <Screen>
      <AppHeader
        title="Make MORT yours."
        subtitle="Free stays useful. Plus just gives you extra style, control, and convenience."
      />
      <TeenMonetizationSafetyNotice />
      <PaywallCard />
      <RestorePurchasesButton />
      <MonetizationDisclaimer />
    </Screen>
  );
}
