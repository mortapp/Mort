import Foundation

enum NotificationLinkResolution: Equatable {
    case notNotification
    case destination(AppRoute)
}

enum NotificationDestinationResolver {
    private static let notificationHosts = Set(["notification", "notifications"])

    static func destination(for data: [String: JSONValue], role: UserRole?) -> AppRoute {
        if let id = uuid(data["threadId"]) {
            return .messageThread(id)
        }

        if isPresent(data["supportTicketId"]) {
            return role == .admin ? .adminQueue(.support) : .support
        }

        if isPresent(data["reportId"]) {
            return role == .admin ? .adminQueue(.reports) : .activity
        }

        if isPresent(data["reviewId"]) {
            return role == .admin ? .adminQueue(.reviews) : .reviews
        }

        if isPresent(data["guardianLinkId"]) {
            return role == .teen || role == .guardian ? .guardianMode : .activity
        }

        if let id = uuid(data["applicationId"]) {
            switch role {
            case .some(.teen): return .applicationDetail(id, .teen)
            case .some(.adult): return .applicationDetail(id, .adult)
            case .some(.guardian): return .applicationDetail(id, .guardian)
            case .some(.admin), .none: return .activity
            }
        }

        if isPresent(data["safetyPingId"]) {
            switch role {
            case .some(.admin): return .adminQueue(.safetyPings)
            case .some(.guardian): return .guardianSafetyPings
            case .some(.teen), .some(.adult), .none: return .safetyCenter
            }
        }

        if let id = uuid(data["jobId"]) {
            return .jobDetail(id)
        }

        if isPresent(data["verificationId"]) || isPresent(data["verificationStatus"]) {
            switch role {
            case .some(.admin): return .adminQueue(.verifications)
            case .some(.adult): return .verification
            case .some(.teen), .some(.guardian), .none: return .activity
            }
        }

        return .activity
    }

    static func linkResolution(for url: URL, role: UserRole?) -> NotificationLinkResolution {
        guard url.scheme?.lowercased() == "mort",
              let host = url.host?.lowercased(),
              notificationHosts.contains(host)
        else {
            return .notNotification
        }

        var data: [String: JSONValue] = [:]
        for item in URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? [] {
            guard let value = item.value, !value.isEmpty else { continue }
            data[item.name] = .string(value)
        }
        return .destination(destination(for: data, role: role))
    }

    private static func uuid(_ value: JSONValue?) -> UUID? {
        guard let text = value?.stringValue else { return nil }
        return UUID(uuidString: text)
    }

    private static func isPresent(_ value: JSONValue?) -> Bool {
        guard let value else { return false }
        switch value {
        case .null: return false
        case let .string(text): return !text.isEmpty
        default: return true
        }
    }
}
