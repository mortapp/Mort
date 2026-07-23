import Foundation

protocol BusinessRegistryProvider: Sendable {
    var automationEnabled: Bool { get }
    func search(
        jurisdiction: String,
        legalName: String,
        registrationNumber: String
    ) async throws -> [BusinessRegistrySearchResult]
}

enum BusinessRegistryProviderError: LocalizedError, Sendable {
    case manualReviewRequired
    case officialSourceNotAllowed

    var errorDescription: String? {
        switch self {
        case .manualReviewRequired:
            "Automated registry search is disabled. Use the audited official-source manual review workflow."
        case .officialSourceNotAllowed:
            "Only an approved official government registry source may be used."
        }
    }
}

struct ManualOfficialSourceBusinessRegistryProvider: BusinessRegistryProvider {
    let automationEnabled = false

    func search(
        jurisdiction: String,
        legalName: String,
        registrationNumber: String
    ) async throws -> [BusinessRegistrySearchResult] {
        _ = jurisdiction
        _ = legalName
        _ = registrationNumber
        throw BusinessRegistryProviderError.manualReviewRequired
    }
}
