import Foundation
import Supabase

class SupabaseRepository: @unchecked Sendable {
    let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func currentUserID() async throws -> UUID {
        do {
            return try await client.auth.session.user.id
        } catch {
            throw MortError.authenticationRequired
        }
    }

    func translated<T>(_ operation: () async throws -> T) async throws -> T {
        do { return try await operation() }
        catch { throw BackendErrorTranslator.translate(error) }
    }
}

