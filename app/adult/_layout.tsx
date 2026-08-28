import { Ionicons } from "@expo/vector-icons";
import { Tabs } from "expo-router";

import { GuardedRouteFallback } from "@/components/GuardedRouteFallback";
import { colors } from "@/lib/theme";
import { useRequireRole } from "@/lib/useRequireRole";

export default function AdultLayout() {
  const ready = useRequireRole("adult");

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
      <Tabs.Screen name="dashboard" options={{ title: "Jobs", tabBarIcon: ({ color, size }) => <Ionicons color={color} name="business-outline" size={size} /> }} />
      <Tabs.Screen name="post-job" options={{ title: "Post", tabBarIcon: ({ color, size }) => <Ionicons color={color} name="add-circle-outline" size={size} /> }} />
      <Tabs.Screen name="applications" options={{ title: "Review", tabBarIcon: ({ color, size }) => <Ionicons color={color} name="clipboard-outline" size={size} /> }} />
      <Tabs.Screen name="messages" options={{ title: "Chat", tabBarIcon: ({ color, size }) => <Ionicons color={color} name="chatbubbles-outline" size={size} /> }} />
      <Tabs.Screen name="verification" options={{ title: "Verify", tabBarIcon: ({ color, size }) => <Ionicons color={color} name="checkmark-done-outline" size={size} /> }} />
      <Tabs.Screen name="profile" options={{ title: "Profile", tabBarIcon: ({ color, size }) => <Ionicons color={color} name="person-outline" size={size} /> }} />
    </Tabs>
  );
}
