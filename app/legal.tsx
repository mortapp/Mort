import { Card } from "@/components/Card";
import { Screen } from "@/components/Screen";
import { Text } from "@/components/Text";
import { EMERGENCY_DISCLAIMER, PAYMENT_DISCLAIMER, SAFETY_DISCLAIMER, VERIFICATION_DISCLAIMER } from "@/lib/disclaimers";

export default function LegalScreen() {
  return (
    <Screen>
      <Text variant="title">MORT rules and safety</Text>
      <Card>
        <Text variant="subtitle">Community rules</Text>
        <Text>Keep work legal, local, age-appropriate, and on-platform. Do not share phone numbers, social handles, exact home addresses, or payment details in chat.</Text>
      </Card>
      <Card>
        <Text variant="subtitle">Guardian Mode</Text>
        <Text>Guardians can supervise linked teen applications, messages, safety pings, and pause teen activity when needed.</Text>
      </Card>
      <Card>
        <Text variant="subtitle">Disclaimers</Text>
        <Text>{PAYMENT_DISCLAIMER}</Text>
        <Text>{VERIFICATION_DISCLAIMER}</Text>
        <Text>{SAFETY_DISCLAIMER}</Text>
        <Text>{EMERGENCY_DISCLAIMER}</Text>
      </Card>
      <Card>
        <Text variant="subtitle">Terms and privacy</Text>
        <Text>MORT still needs final lawyer-reviewed Terms, Privacy Policy, child/teen safety review, and App Store privacy disclosures before public launch.</Text>
      </Card>
    </Screen>
  );
}
