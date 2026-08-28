import { Card } from "@/components/Card";
import { Text } from "@/components/Text";

export function EmptyState({ title, body }: { title: string; body: string }) {
  return (
    <Card>
      <Text variant="subtitle">{title}</Text>
      <Text color="#a7b0c0">{body}</Text>
    </Card>
  );
}
