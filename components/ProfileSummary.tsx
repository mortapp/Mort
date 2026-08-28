import { Card } from "@/components/Card";
import { StatusPill } from "@/components/StatusPill";
import { Text } from "@/components/Text";
import type { Profile } from "@/types/domain";

export function ProfileSummary({ profile }: { profile: Profile }) {
  return (
    <Card>
      <Text variant="subtitle">{profile.display_name ?? "MORT user"}</Text>
      {profile.username ? <Text>@{profile.username}</Text> : null}
      <StatusPill label={profile.role ?? "onboarding"} tone={profile.role === "admin" ? "danger" : "info"} />
      <Text>
        {profile.city || "City not set"}
        {profile.state ? `, ${profile.state}` : ""}
      </Text>
      <Text variant="caption">Verification: {profile.verification_status}</Text>
      <Text variant="caption">Payment preference only: {profile.payment_preference.replace("_", " ")}</Text>
      <Text variant="caption">Account status: {profile.account_status ?? "active"}</Text>
    </Card>
  );
}
