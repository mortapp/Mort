//
//  SupabaseConfig.swift
//  MORT
//
//  Centralized Supabase configuration. PUBLIC anon key only — never the
//  service_role key, and never log these values.
//

import Foundation

/// Holds the public Supabase project configuration.
///
/// The anon key is the public client key and is safe to ship in an app.
/// NEVER place a `service_role` key here or anywhere in the client.
nonisolated enum SupabaseConfig {
    /// Try to load values from Info.plist so builds can be configured per-target.
    /// Falls back to demo behavior when keys are missing. Do NOT ship a
    /// `service_role` key in the client.

    static var url: URL {
        if let s = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
           let u = URL(string: s) {
            return u
        }
        // Developer-visible warning but avoid leaking secrets.
        print("[MORT] WARNING: SUPABASE_URL not found in Info.plist — running in demo mode")
        return URL(string: "https://rakjydmgwwgtdislanbt.supabase.co")!
    }

    /// Public anon key. Safe for client distribution only if RLS is properly
    /// configured server-side. If missing, the app will run in demo mode.
    static var anonKey: String? {
        if let k = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
           !k.trimmingCharacters(in: .whitespaces).isEmpty {
            return k
        }
        print("[MORT] WARNING: SUPABASE_ANON_KEY missing — demo mode enabled")
        return nil
    }

    static var demoMode: Bool { anonKey == nil }

    /// Avatar storage bucket name.
    static let avatarBucket = "profile-avatars"

    /// Tables this app is designed to read/write.
    enum Table {
        static let profiles = "profiles"
        static let jobs = "jobs"
        static let jobApplications = "job_applications"
        static let conversations = "conversations"
        static let messages = "messages"
        static let notificationEvents = "notification_events"
        static let reports = "reports"
        static let blockedUsers = "blocked_users"
        static let guardianLinks = "guardian_links"
        static let trustedCircleContacts = "trusted_circle_contacts"
        static let safetyPings = "safety_pings"
        static let adminActions = "admin_actions"
        static let moderationQueue = "moderation_queue"
        static let adRewardEvents = "ad_reward_events"
        static let userRewardBalances = "user_reward_balances"
        static let safetyScans = "safety_scans"
        static let rateLimitEvents = "rate_limit_events"
    }
}

// TODO: Supabase integration
// 1. Add the supabase-swift package in Xcode:
//    File > Add Package Dependencies > https://github.com/supabase/supabase-swift
// 2. Create a shared client:
//    import Supabase
//    let supabase = SupabaseClient(supabaseURL: SupabaseConfig.url,
//                                  supabaseKey: SupabaseConfig.anonKey)
// 3. Replace the Mock*Service implementations with live ones that call
//    supabase.from(SupabaseConfig.Table.xxx)... and supabase.auth...
// 4. Configure Row Level Security policies in the Supabase dashboard so each
//    role can only read/write what it should.
