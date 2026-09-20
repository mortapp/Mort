import "react-native-get-random-values";
import "react-native-url-polyfill/auto";

import AsyncStorage from "@react-native-async-storage/async-storage";
import { createClient } from "@supabase/supabase-js";
import { Platform } from "react-native";

import { SUPABASE_ANON_KEY, SUPABASE_URL } from "@/lib/env";

const staticRenderStorage = {
  getItem: async () => null,
  setItem: async () => undefined,
  removeItem: async () => undefined
};

const authStorage =
  Platform.OS === "web" && typeof globalThis.window === "undefined" ? staticRenderStorage : AsyncStorage;

// The Expo tree is reference-only; Flutter is the supported production client.
// Keep an unconfigured/static export fail-closed without letting supabase-js throw
// during module initialization. isSupabaseConfigured remains false because it is
// calculated from the real environment values in lib/env.ts.
const clientUrl = SUPABASE_URL || "https://ci-placeholder.supabase.co";
const clientAnonKey = SUPABASE_ANON_KEY || "ci-placeholder-anon-key-not-a-real-credential";

export const supabase = createClient(clientUrl, clientAnonKey, {
  auth: {
    storage: authStorage,
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: false
  }
});
