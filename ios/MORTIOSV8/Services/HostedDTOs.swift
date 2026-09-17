//
//  HostedDTOs.swift
//  MORT iOS V8
//
//  Wire models for the real hosted MORT Supabase contracts. Keep these
//  separate from the original Rork handoff DTOs so migrations are explicit
//  and reviewable.
//

import Foundation

nonisolated struct HostedProfileDTO: Codable, Sendable {
    let id: String
    let role: String?
    let displayName: String?
    let city: String?
    let state: String?
    let createdAt: Date
    let updatedAt: Date
    let username: String?
    let guardianSetupStatus: String?
    let verificationStatus: String?
    let bio: String?
    let preferredJobCategories: [String]?
    let approximateArea: String?

    func toDomain() -> MortUser {
        let cleanUsername = username?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        let handle = cleanUsername.map { "@\($0)" } ?? "@member"

        let display = displayName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let safeDisplay = (display?.isEmpty == false) ? display! : handle

        let area: String? = {
            if let approximateArea {
                let value = approximateArea.trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty { return value }
            }
            let cityValue = city?.trimmingCharacters(in: .whitespacesAndNewlines)
            let stateValue = state?.trimmingCharacters(in: .whitespacesAndNewlines)
            switch (cityValue, stateValue) {
            case let (.some(city), .some(state)) where !city.isEmpty && !state.isEmpty:
                return "\(city), \(state)"
            case let (.some(city), _) where !city.isEmpty:
                return city
            case let (_, .some(state)) where !state.isEmpty:
                return state
            default:
                return nil
            }
        }()

        let initials = safeDisplay
            .split(separator: " ")
            .compactMap(\.first)
            .prefix(2)
            .map(String.init)
            .joined()
            .uppercased()

        let year = Calendar(identifier: .gregorian).component(.year, from: createdAt)

        return MortUser(
            id: id,
            handle: handle,
            displayName: safeDisplay,
            // Unknown / legacy roles fail toward the least-privileged client UX.
            // The backend remains authoritative for every permitted action.
            role: role.flatMap(MortRole.init(rawValue:)) ?? .teen,
            area: area,
            avatarInitials: initials.isEmpty ? "?" : initials,
            rating: nil,
            completedJobs: 0,
            verifications: [],
            memberSince: String(year),
            bio: bio,
            guardianLinked: guardianSetupStatus == "linked"
        )
    }
}

nonisolated struct HostedProfileUpdateResponseDTO: Codable, Sendable {
    let ok: Bool
    let replayed: Bool?
    let code: String?
    let profile: HostedProfileDTO?
}
