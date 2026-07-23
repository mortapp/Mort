import Foundation

protocol PortfolioRepositoryProtocol: Sendable {
    func listPortfolioItems() async throws -> Never
}

struct PortfolioRepository: PortfolioRepositoryProtocol {
    func listPortfolioItems() async throws -> Never {
        throw MortError.featureUnavailable("Portfolio storage is mapped, but the shared backend does not have portfolio tables yet.")
    }
}
