import type { Session, User } from "@supabase/supabase-js";
import { createContext, useCallback, useContext, useEffect, useMemo, useState, type PropsWithChildren } from "react";

import { isSupabaseConfigured } from "@/lib/env";
import { deactivatePushTokens } from "@/lib/notifications";
import { logOutRevenueCat } from "@/lib/revenuecat";
import { supabase } from "@/lib/supabase";
import type { Profile } from "@/types/domain";

type AuthContextValue = {
  configured: boolean;
  loading: boolean;
  session: Session | null;
  user: User | null;
  profile: Profile | null;
  refreshProfile: () => Promise<void>;
  signOut: () => Promise<void>;
};

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: PropsWithChildren) {
  const [session, setSession] = useState<Session | null>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [loading, setLoading] = useState(true);

  const refreshProfile = useCallback(async () => {
    const { data: userData } = await supabase.auth.getUser();
    const currentUser = userData.user;

    if (!currentUser) {
      setProfile(null);
      return;
    }

    const { data, error } = await supabase.rpc("get_my_profile");
    if (error) {
      throw error;
    }
    setProfile(data?.[0] ?? null);
  }, []);

  useEffect(() => {
    let mounted = true;

    async function hydrate() {
      const { data } = await supabase.auth.getSession();
      if (!mounted) return;

      setSession(data.session);
      if (data.session) {
        await refreshProfile();
      }
      setLoading(false);
    }

    hydrate().catch(() => {
      if (mounted) setLoading(false);
    });

    const { data: listener } = supabase.auth.onAuthStateChange((_, nextSession) => {
      setSession(nextSession);
      if (!nextSession) {
        setProfile(null);
      } else {
        refreshProfile().catch(() => undefined);
      }
    });

    return () => {
      mounted = false;
      listener.subscription.unsubscribe();
    };
  }, [refreshProfile]);

  const value = useMemo<AuthContextValue>(
    () => ({
      configured: isSupabaseConfigured,
      loading,
      session,
      user: session?.user ?? null,
      profile,
      refreshProfile,
      signOut: async () => {
        if (session?.user.id) {
          await deactivatePushTokens(session.user.id).catch(() => undefined);
        }
        await logOutRevenueCat().catch(() => undefined);
        await supabase.auth.signOut();
        setSession(null);
        setProfile(null);
      }
    }),
    [loading, profile, refreshProfile, session]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const value = useContext(AuthContext);
  if (!value) {
    throw new Error("useAuth must be used inside AuthProvider");
  }
  return value;
}
