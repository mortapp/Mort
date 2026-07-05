//
//  SessionStore.swift
//  MORT
//
//  Observable app session: authentication + onboarding + active profile.
//  Drives high-level routing in RootView.
//

import SwiftUI

/// Phases of the app flow used for top-level routing.
enum AppPhase: Equatable {
    case splash
    case onboarding
    case underageBlocked
    case home
}

/// Steps in the signup / onboarding sequence.
enum OnboardingStep: Equatable {
    case welcome
    case login
    case signup
    case verifyEmail
    case dob
    case username
    case role
    case terms
    case notifications
    case transportation
}

/// Draft collected during onboarding before a profile is created.
struct OnboardingDraft {
    var email: String = ""
    var birthDate: Date? = nil
    var ageGroup: AgeGroup = .adult
    var username: String = ""
    var role: UserRole? = nil
    var termsAccepted: Bool = false
    var notificationsRequested: Bool = false
    var transportationMode: TransportationMode? = nil
}

@MainActor
@Observable
final class SessionStore {
    var phase: AppPhase = .splash
    var step: OnboardingStep = .welcome
    var draft = OnboardingDraft()
    var profile: UserProfile?
    var isWorking = false
    var errorMessage: String?

    private let services: AppServices
    let termsVersion = "1.0"

    init(services: AppServices) {
        self.services = services
    }

    var currentRole: UserRole { profile?.role ?? .teen }

    /// Move from splash into onboarding after the splash animation.
    func finishSplash() {
        guard phase == .splash else { return }
        withAnimation(.easeInOut(duration: 0.4)) {
            phase = .onboarding
            step = .welcome
        }
    }

    func go(to step: OnboardingStep) {
        withAnimation(.easeInOut(duration: 0.25)) { self.step = step }
    }

    // MARK: Auth

    func login(email: String, password: String) async {
        await run {
            let id = try await self.services.auth.signIn(email: email, password: password)
            if let existing = try await self.services.profile.fetchProfile(id: id) {
                self.profile = existing
                self.enterHome()
            } else {
                self.draft.email = email
                self.go(to: .dob)
            }
        }
    }

    func signUp(email: String, password: String) async {
        await run {
            _ = try await self.services.auth.signUp(email: email, password: password)
            try await self.services.auth.sendVerificationEmail(to: email)
            self.draft.email = email
            self.go(to: .verifyEmail)
        }
    }

    // MARK: DOB / age gate

    func submitBirthDate(_ date: Date) {
        draft.birthDate = date
        let group = AgeGroup.from(birthDate: date)
        draft.ageGroup = group
        if group == .under13 {
            withAnimation { phase = .underageBlocked }
            return
        }
        if group == .teen { draft.role = .teen }
        go(to: .username)
    }

    // MARK: Username

    func checkUsername(_ username: String) async -> Bool {
        (try? await services.profile.isUsernameAvailable(username.lowercased())) ?? false
    }

    func submitUsername(_ username: String) {
        draft.username = username
        if draft.ageGroup == .teen {
            // Teens are locked to the teen role; skip role selection.
            draft.role = .teen
        }
        go(to: .role)
    }

    func submitRole(_ role: UserRole) {
        draft.role = role
        go(to: .terms)
    }

    func acceptTerms() {
        draft.termsAccepted = true
        go(to: .notifications)
    }

    func setNotifications(requested: Bool) {
        draft.notificationsRequested = requested
        if draft.ageGroup == .teen {
            go(to: .transportation)
        } else {
            Task { await self.completeOnboarding() }
        }
    }

    func submitTransportation(_ mode: TransportationMode) {
        draft.transportationMode = mode
        Task { await completeOnboarding() }
    }

    private func completeOnboarding() async {
        await run {
            guard let role = self.draft.role else {
                throw MortError.invalidInput("Please choose a role to continue.")
            }
            let id = self.services.auth.currentUserId ?? "u_\(UUID().uuidString.prefix(6))"
            let profile = UserProfile(
                id: id,
                username: self.draft.username,
                displayName: self.draft.username,
                role: role,
                ageGroup: self.draft.ageGroup,
                birthDatePrivate: self.draft.birthDate,
                transportationMode: self.draft.transportationMode,
                trustScore: 50,
                termsAcceptedAt: self.draft.termsAccepted ? Date() : nil,
                termsVersion: self.termsVersion,
                notificationsPermissionStatus: self.draft.notificationsRequested ? "granted" : "notDetermined"
            )
            let saved = try await self.services.profile.createProfile(profile)
            self.profile = saved
            self.enterHome()
        }
    }

    /// Demo helper: jump straight into a role's dashboard to explore the app.
    func enterDemo(as role: UserRole) {
        let group: AgeGroup = role == .teen ? .teen : .adult
        let profile = UserProfile(
            id: role == .teen ? "u_teen" : "demo_\(role.rawValue)",
            username: "demo_\(role.rawValue)",
            displayName: "Demo \(role.title)",
            role: role,
            ageGroup: group,
            transportationMode: role == .teen ? .bike : nil,
            trustScore: 60,
            termsAcceptedAt: Date(),
            termsVersion: termsVersion
        )
        self.profile = profile
        enterHome()
    }

    func signOut() {
        Task { await services.auth.signOut() }
        withAnimation {
            profile = nil
            draft = OnboardingDraft()
            phase = .onboarding
            step = .welcome
        }
    }

    func resetFromBlocked() {
        withAnimation {
            draft = OnboardingDraft()
            phase = .onboarding
            step = .welcome
        }
    }

    private func enterHome() {
        withAnimation(.easeInOut(duration: 0.3)) { phase = .home }
    }

    private func run(_ work: @escaping () async throws -> Void) async {
        isWorking = true
        errorMessage = nil
        do {
            try await work()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isWorking = false
    }
}
