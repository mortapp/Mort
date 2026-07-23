import { ActionRow } from "@/components/DesignSystem";

export function PerkRow({ title, body }: { title: string; body: string }) {
  return <ActionRow title={title} body={body} />;
}
