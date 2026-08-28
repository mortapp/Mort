import Constants from "expo-constants";
import * as Device from "expo-device";
import * as Notifications from "expo-notifications";
import { Platform } from "react-native";

import { supabase } from "@/lib/supabase";

Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldPlaySound: true,
    shouldSetBadge: true,
    shouldShowBanner: true,
    shouldShowList: true
  })
});

function getProjectId() {
  const configuredProjectId =
    Constants.easConfig?.projectId ??
    (Constants.expoConfig?.extra?.eas as { projectId?: string } | undefined)?.projectId;

  if (!configuredProjectId || configuredProjectId === "00000000-0000-0000-0000-000000000000") {
    return null;
  }

  return configuredProjectId;
}

export async function registerForPushNotificationsAsync(userId: string) {
  if (Platform.OS === "web" || !Device.isDevice) {
    return null;
  }

  if (Platform.OS === "android") {
    await Notifications.setNotificationChannelAsync("mort", {
      name: "MORT safety and marketplace alerts",
      importance: Notifications.AndroidImportance.MAX
    });
  }

  const projectId = getProjectId();
  if (!projectId) {
    return null;
  }

  const existing = await Notifications.getPermissionsAsync();
  const finalStatus =
    existing.status === "granted"
      ? existing.status
      : (await Notifications.requestPermissionsAsync()).status;

  if (finalStatus !== "granted") {
    return null;
  }

  const token = (await Notifications.getExpoPushTokenAsync({ projectId })).data;
  await supabase.from("profiles").update({ expo_push_token: token }).eq("id", userId);
  await supabase.from("push_tokens").upsert({
    user_id: userId,
    expo_push_token: token,
    platform: Platform.OS,
    is_active: true,
    last_error: null
  });
  return token;
}

export async function deactivatePushTokens(userId: string) {
  await supabase.from("push_tokens").update({ is_active: false }).eq("user_id", userId);
  await supabase.from("profiles").update({ expo_push_token: null }).eq("id", userId);
}

export async function scheduleSafetyReminder() {
  if (Platform.OS === "web") {
    return null;
  }

  return Notifications.scheduleNotificationAsync({
    content: {
      title: "MORT safety check",
      body: "Check in when a job starts or ends, and contact a guardian if anything feels off."
    },
    trigger: {
      type: Notifications.SchedulableTriggerInputTypes.TIME_INTERVAL,
      seconds: 60 * 60,
      repeats: false
    }
  });
}
