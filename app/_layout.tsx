import { Stack } from "expo-router";
import { StatusBar } from "expo-status-bar";
import { GestureHandlerRootView } from "react-native-gesture-handler";
import { SafeAreaProvider } from "react-native-safe-area-context";

import { colors } from "@/lib/theme";
import { AuthProvider } from "@/providers/AuthProvider";
import { MonetizationProvider } from "@/providers/MonetizationProvider";

export default function RootLayout() {
  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <SafeAreaProvider>
        <AuthProvider>
          <MonetizationProvider>
            <StatusBar style="light" />
            <Stack screenOptions={{ headerShown: false, contentStyle: { backgroundColor: colors.background } }}>
              <Stack.Screen name="index" />
              <Stack.Screen name="auth" />
              <Stack.Screen name="onboarding" />
              <Stack.Screen name="account-status" />
              <Stack.Screen name="teen" />
              <Stack.Screen name="adult" />
              <Stack.Screen name="guardian" />
              <Stack.Screen name="admin" />
              <Stack.Screen name="monetization" />
              <Stack.Screen name="settings" />
              <Stack.Screen name="job/[id]" />
              <Stack.Screen name="messages/[threadId]" />
              <Stack.Screen name="proof/[applicationId]" />
              <Stack.Screen name="report/[targetUserId]" />
              <Stack.Screen name="notifications" />
              <Stack.Screen name="support" />
              <Stack.Screen name="legal" />
            </Stack>
          </MonetizationProvider>
        </AuthProvider>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}
