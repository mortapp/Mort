// Config.swift
// Public, non-secret client configuration shipped with the native MORT app.
//
// Supabase publishable keys are designed for client distribution and are
// protected by Auth + Row Level Security. Service-role, Stripe secret, webhook,
// operations, or other privileged credentials must NEVER be added here.

import Foundation

enum Config {
    static let EXPO_PUBLIC_SUPABASE_URL = "https://rakjydmgwwgtdislanbt.supabase.co"
    static let EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY = "sb_publishable_Q4uDJsjSs2wWFfVOdRax7Q_vuS2ADl1"

    // Legacy Rork values remain empty unless that optional tooling is used.
    static let EXPO_PUBLIC_PROJECT_ID = ""
    static let EXPO_PUBLIC_RORK_API_BASE_URL = ""
    static let EXPO_PUBLIC_RORK_AUTH_URL = ""
    static let EXPO_PUBLIC_RORK_FUNCTIONS_URL = ""
    static let EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY = ""
    static let EXPO_PUBLIC_TEAM_ID = ""
    static let EXPO_PUBLIC_TOOLKIT_URL = ""

    static let allValues: [String: String] = [
        "EXPO_PUBLIC_SUPABASE_URL": EXPO_PUBLIC_SUPABASE_URL,
        "EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY": EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
        "EXPO_PUBLIC_PROJECT_ID": EXPO_PUBLIC_PROJECT_ID,
        "EXPO_PUBLIC_RORK_API_BASE_URL": EXPO_PUBLIC_RORK_API_BASE_URL,
        "EXPO_PUBLIC_RORK_AUTH_URL": EXPO_PUBLIC_RORK_AUTH_URL,
        "EXPO_PUBLIC_RORK_FUNCTIONS_URL": EXPO_PUBLIC_RORK_FUNCTIONS_URL,
        "EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY": EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY,
        "EXPO_PUBLIC_TEAM_ID": EXPO_PUBLIC_TEAM_ID,
        "EXPO_PUBLIC_TOOLKIT_URL": EXPO_PUBLIC_TOOLKIT_URL,
    ]
}
