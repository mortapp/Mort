import { useEffect, useState } from "react";

import { Button } from "@/components/Button";
import { Card } from "@/components/Card";
import { EmptyState } from "@/components/EmptyState";
import { ErrorBanner } from "@/components/ErrorBanner";
import { Screen } from "@/components/Screen";
import { StatusPill } from "@/components/StatusPill";
import { Text } from "@/components/Text";
import { listNotifications, markNotificationRead } from "@/lib/data";
import { colors } from "@/lib/theme";
import { useAuth } from "@/providers/AuthProvider";
import type { Notification } from "@/types/domain";

export default function NotificationsScreen() {
  const { user } = useAuth();
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function markRead(notificationId: string) {
    if (!user) return;
    try {
      await markNotificationRead(notificationId);
      setNotifications(await listNotifications(user.id));
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to mark notification read.");
    }
  }

  async function markAllRead() {
    if (!user) return;
    setError(null);
    try {
      const unread = notifications.filter((notification) => !notification.read_at);
      await Promise.all(unread.map((notification) => markNotificationRead(notification.id)));
      setNotifications(await listNotifications(user.id));
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to mark all notifications read.");
    }
  }

  useEffect(() => {
    const userId = user?.id ?? "";
    if (!userId) return;
    let active = true;

    async function loadNotifications() {
      try {
        const rows = await listNotifications(userId);
        if (!active) return;
        setNotifications(rows);
        setError(null);
      } catch (err) {
        if (!active) return;
        setError(err instanceof Error ? err.message : "Unable to load notifications.");
      } finally {
        if (active) setLoading(false);
      }
    }

    void loadNotifications();

    return () => {
      active = false;
    };
  }, [user?.id]);

  return (
    <Screen>
      <Text variant="title">Notifications</Text>
      <Text color={colors.muted}>Guardian approvals, application updates, safety alerts, and moderation outcomes appear here.</Text>
      {notifications.some((notification) => !notification.read_at) ? (
        <Button title="Mark all read" variant="secondary" onPress={markAllRead} />
      ) : null}
      <ErrorBanner message={error} />
      {notifications.length === 0 && !loading ? (
        <EmptyState title="No notifications" body="MORT will list safety and marketplace updates here after Supabase is connected." />
      ) : null}
      {notifications.map((notification) => (
        <Card key={notification.id}>
          <StatusPill label={notification.read_at ? "read" : "new"} tone={notification.read_at ? "default" : "info"} />
          <Text variant="subtitle">{notification.title}</Text>
          <Text>{notification.body}</Text>
          <Text variant="caption">{new Date(notification.created_at).toLocaleString()}</Text>
          {!notification.read_at ? <Button title="Mark read" variant="secondary" onPress={() => markRead(notification.id)} /> : null}
        </Card>
      ))}
    </Screen>
  );
}
