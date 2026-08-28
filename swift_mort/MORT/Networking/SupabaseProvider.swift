import Foundation
import Supabase

final class SupabaseProvider: @unchecked Sendable {
    let client: SupabaseClient

    init(configuration: AppConfiguration) {
        client = SupabaseClient(
            supabaseURL: configuration.supabaseURL,
            supabaseKey: configuration.supabaseAnonKey,
            options: SupabaseClientOptions(
                auth: .init(
                    redirectToURL: URL(string: "mort://auth/callback"),
                    flowType: .pkce
                )
            )
        )
    }
}
