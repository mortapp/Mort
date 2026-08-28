import { Ionicons } from "@expo/vector-icons";
import { Tabs } from "expo-router";

import { GuardedRouteFallback } from "@/components/GuardedRouteFallback";
import { colors } from "@/lib/theme";
import { useRequireRole } from "@/lib/useRequireRole";

export default function AdminLayout() {
  const ready = useRequireRole("admin");

  if (!ready) {
    return <GuardedRouteFallback />;
  }

  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: colors.danger,
        tabBarInactiveTintColor: colors.muted
      }}
    >
      <Tabs.Screen name="index" options={{ title: "Admin", tabBarIcon: ({ color, size }) => <Ionicons color={color} name="speedometer-outline" size={size} /> }} />
      <Tabs.Screen name="reports" options={{ title: "Reports", tabBarIcon: ({ color, size }) => <Ionicons color={color} name="flag-outline" size={size} /> }} />
      <Tabs.Screen name="verification" options={{ title: "Verify", tabBarIcon: ({ color, size }) => <Ionicons color={color} name="shield-checkmark-outline" size={size} /> }} />
      <Tabs.Screen name="jobs" options={{ title: "Jobs", tabBarIcon: ({ color, size }) => <Ionicons color={color} name="briefcase-outline" size={size} /> }} />
      <Tabs.Screen name="users" options={{ title: "Users", tabBarIcon: ({ color, size }) => <Ionicons color={color} name="people-outline" size={size} /> }} />
      <Tabs.Screen name="support" options={{ title: "Support", tabBarIcon: ({ color, size }) => <Ionicons color={color} name="help-circle-outline" size={size} /> }} />
    </Tabs>
  );
}
