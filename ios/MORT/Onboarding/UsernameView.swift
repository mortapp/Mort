//
//  UsernameView.swift
//  MORT
//

import SwiftUI

/// Reserved usernames that cannot be claimed.
let mortReservedUsernames: Set<String> = [
    "admin", "support", "mort", "moderator", "staff", "help",
    "safety", "official", "null", "undefined", "deleted", "unknown",
]

struct UsernameView: View {
    @Environment(SessionStore.self) private var session
    @State private var username = ""
    @State private var status: ValidationStatus = .idle
    @State private var checking = false

    enum ValidationStatus: Equatable {
        case idle
        case invalid(String)
        case checking
        case available
        case taken
    }

    private func localValidation(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if trimmed.count < 3 || trimmed.count > 20 {
            return "Username must be 3–20 characters."
        }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_")
        if trimmed.unicodeScalars.contains(where: { !allowed.contains($0) }) {
            return "Use only letters, numbers, and underscores."
        }
        if mortReservedUsernames.contains(trimmed.lowercased()) {
            return "That username is reserved."
        }
        return nil
    }

    private func validate() {
        if let error = localValidation(username) {
            status = .invalid(error)
            return
        }
        status = .checking
        checking = true
        Task {
            let available = await session.checkUsername(username)
            checking = false
            status = available ? .available : .taken
        }
    }

    private var canContinue: Bool { status == .available }

    var body: some View {
        OnboardingScaffold(
            title: "Pick a username",
            subtitle: "This is how others find you on MORT. You can change your display name later."
        ) {
            VStack(alignment: .leading, spacing: MortSpacing.md) {
                MortTextField(
                    title: "Username",
                    text: $username,
                    placeholder: "jordan",
                    systemImage: "at",
                    helper: "3–20 characters · letters, numbers, underscore",
                    characterLimit: 20
                )
                .onChange(of: username) { _, _ in status = .idle }

                statusLabel

                MortButton(title: status == .available ? "Continue" : "Check username", isLoading: checking, isDisabled: username.isEmpty) {
                    if canContinue {
                        session.submitUsername(username.trimmingCharacters(in: .whitespaces))
                    } else {
                        validate()
                    }
                }
            }
        }
    }

    @ViewBuilder private var statusLabel: some View {
        switch status {
        case .idle, .checking:
            EmptyView()
        case .invalid(let msg):
            Label(msg, systemImage: "exclamationmark.circle.fill")
                .font(MortFont.caption()).foregroundStyle(MortColor.danger)
        case .available:
            Label("@\(username) is available", systemImage: "checkmark.circle.fill")
                .font(MortFont.caption()).foregroundStyle(MortColor.success)
        case .taken:
            Label("That username is taken", systemImage: "xmark.circle.fill")
                .font(MortFont.caption()).foregroundStyle(MortColor.danger)
        }
    }
}
