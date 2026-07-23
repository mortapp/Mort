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

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    storage: authStorage,
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: false
  }
});
