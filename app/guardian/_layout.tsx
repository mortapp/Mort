import { Ionicons } from "@expo/vector-icons";
import { Tabs } from "expo-router";

import { GuardedRouteFallback } from "@/components/GuardedRouteFallback";
import { colors } from "@/lib/theme";
import { useRequireRole } from "@/lib/useRequireRole";

export default function GuardianLayout() {
  const ready = useRequireRole("guardian");

  if (!ready) {
    return <GuardedRouteFallback />;
  }

  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: colors.primary,
        tabBarInactiveTintColor: colors.muted
      }}
    >
      <Tabs.Screen name="approvals" options={{ title: "Approvals", tabBarIcon: ({ color, size }) => <Ionicons color={color} name="checkmark-circle-outline" size={size} /> }} />
      <Tabs.Screen name="teens" options={{ title: "Teens", tabBarIcon: ({ color, size }) => <Ionicons color={color} name="people-outline" size={size} /> }} />
      <Tabs.Screen name="messages" options={{ title: "Chat", tabBarIcon: ({ color, size }) => <Ionicons color={color} name="chatbubbles-outline" size={size} /> }} />
      <Tabs.Screen name="safety" options={{ title: "Safety", tabBarIcon: ({ color, size }) => <Ionicons color={color} name="shield-outline" size={size} /> }} />
      <Tabs.Screen name="profile" options={{ title: "Profile", tabBarIcon: ({ color, size }) => <Ionicons color={color} name="person-outline" size={size} /> }} />
    </Tabs>
  );
}
