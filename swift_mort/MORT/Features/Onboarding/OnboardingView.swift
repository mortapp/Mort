import PhotosUI
import SwiftUI
import UIKit

private enum OnboardingAccount: String, CaseIterable, Identifiable {
    case teen
    case adult
    case business
    case guardian

    var id: String { rawValue }
    var title: String {
        switch self {
        case .teen: "Teen"
        case .adult: "Adult"
        case .business: "Business"
        case .guardian: "Guardian"
        }
    }
    var subtitle: String {
        switch self {
        case .teen: "Find safe local work"
        case .adult: "Post and manage local jobs"
        case .business: "Use the adult job-posting flow with business verification"
        case .guardian: "Opt into approved safety information"
        }
    }
    var role: UserRole { self == .teen ? .teen : self == .guardian ? .guardian : .adult }
}

private enum OnboardingStep: Int, CaseIterable {
    case welcome
    case role
    case age
    case basics
    case identity
    case avatar
    case preferences
    case payment
    case guardian
    case safety
    case acknowledgement
}

private enum GuardianSetupChoice: String, CaseIterable, Identifiable {
    case linkNow
    case sendInvite
    case enterCode
    case skip

    var id: String { rawValue }
    var title: String {
        switch self {
        case .linkNow: "Link guardian now"
        case .sendInvite: "Send invite"
        case .enterCode: "Enter invite code"
        case .skip: "Skip for now"
        }
    }
}

struct OnboardingView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(SessionStore.self) private var session

    @State private var step: OnboardingStep = .welcome
    @State private var account: OnboardingAccount = .teen
    @State private var dobText = ""
    @State private var dobDate = Calendar.current.date(byAdding: .year, value: -16, to: Date()) ?? Date()
    @State private var displayName = ""
    @State private var city = ""
    @State private var state = ""
    @State private var locationSetupMode = "city_state"
    @State private var bio = ""
    @State private var availability = ""
    @State private var area = ""
    @State private var goals = ""
    @State private var selectedCategories: Set<String> = []
    @State private var paymentPreference = "none"
    @State private var cashAppTag = ""
    @State private var squareURL = ""
    @State private var paymentNote = ""
    @State private var guardianChoice: GuardianSetupChoice = .skip
    @State private var guardianEmail = ""
    @State private var inviteCode = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var avatarData: Data?
    @State private var acceptedSafety = false
    @State private var acceptedRules = false
    @State private var identityRoute: IdentityEvidenceRoute = .schoolPhotoID
    @State private var identityAcknowledged = false
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private let categories = ["cleaning", "yard work", "pet care", "moving", "events", "tutoring", "tech help", "other"]

    var body: some View {
        VStack(spacing: 0) {
            progressHeader
            ScrollView {
                VStack(alignment: .leading, spacing: MortSpacing.lg) {
                    stepContent
                    if let successMessage {
                        MortAlertBanner(title: "Saved", message: successMessage, tint: MortColors.neon, icon: "checkmark.circle.fill")
                    }
                }
                .padding(MortSpacing.lg)
            }
            footer
        }
        .mortScreen()
        .task { hydrateSavedProfile() }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task { await loadPhoto(item) }
        }
        .alert("Could not continue", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var progressHeader: some View {
        VStack(spacing: MortSpacing.xs) {
            HStack {
                Text("MORT setup").font(MortTypography.label)
                Spacer()
                Text("\(step.rawValue + 1) / \(OnboardingStep.allCases.count)")
                    .font(MortTypography.caption)
                    .foregroundStyle(MortColors.textMuted)
            }
            ProgressView(value: Double(step.rawValue + 1), total: Double(OnboardingStep.allCases.count))
                .tint(MortColors.neon)
        }
        .padding(.horizontal, MortSpacing.lg)
        .padding(.vertical, MortSpacing.sm)
        .background(MortColors.elevated)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .welcome:
            onboardingHeader("Build your MORT profile", "A clear profile helps people make safer, better decisions. You can change most details later.", "bolt.shield.fill")
            MortSafetyBanner(message: "Use a general area only. Never put a home address, school schedule, phone number, or off-platform contact details in your profile.")
        case .role:
            onboardingHeader("How will you use MORT?", "Role permissions are enforced by Supabase and cannot be changed into admin access here.", "person.2.badge.gearshape")
            ForEach(OnboardingAccount.allCases) { option in
                ChoiceRow(title: option.title, subtitle: option.subtitle, selected: account == option) { account = option }
            }
        case .age:
            onboardingHeader("Confirm your age", "Teens must be 13-17. Adults, businesses, and guardians must be 18 or older.", "calendar.badge.checkmark")
            MortDateField(title: "Date of birth", text: $dobText, date: $dobDate)
            Text("Visible format: MM/DD/YYYY. MORT stores this as a date-only YYYY-MM-DD value.")
                .font(MortTypography.caption)
                .foregroundStyle(MortColors.textMuted)
        case .basics:
            onboardingHeader("Set your basics", account.role == .teen ? "A permanent address is never required. Choose the safest general-location setup for you." : "Use your city and state, never an exact address.", "person.text.rectangle")
            MortTextField(title: account == .business ? "Account or business name" : "Display name", text: $displayName, prompt: "Name shown in MORT", textContentType: .name)
            if account.role == .teen {
                NoAddressOnboardingSupport(locationSetupMode: $locationSetupMode)
            }
            if locationSetupMode == "city_state" || account.role != .teen {
                MortTextField(title: "City", text: $city, prompt: "Indianapolis", textContentType: .addressCity)
                MortTextField(title: "State", text: $state, prompt: "IN", textContentType: .addressState)
            }
            MortTextField(title: "Approximate area", text: $area, prompt: "North side, downtown, nearby suburb")
        case .identity:
            onboardingHeader("Verify identity before marketplace use", "Teens verify identity and age before applying. Adults and businesses verify before publishing. Guardian Mode remains optional and separate.", "person.badge.shield.checkmark.fill")
            Picker("Evidence route", selection: $identityRoute) {
                ForEach(onboardingIdentityRoutes) { route in Text(route.title).tag(route) }
            }
            .pickerStyle(.menu)
            Toggle("I understand evidence is restricted, verification is not a safety guarantee, and marketplace actions stay locked until review passes.", isOn: $identityAcknowledged)
                .tint(MortColors.neon)
            MortSafetyBanner(message: "Continue setup, then use Verification to capture each requested item and submit it for restricted review. Free report, block, support, and emergency guidance stay available while review is pending.")
        case .avatar:
            onboardingHeader("Add a profile photo", "Optional. MORT removes image metadata, crops avatars square, and stores them in a private bucket.", "person.crop.circle.badge.plus")
            HStack(spacing: MortSpacing.lg) {
                if let avatarData, let image = UIImage(data: avatarData) {
                    Image(uiImage: image).resizable().scaledToFill().frame(width: 96, height: 96).clipShape(Circle())
                } else {
                    MortAvatar(displayName: displayName.isEmpty ? "MORT member" : displayName, size: 96)
                }
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label(avatarData == nil ? "Choose photo" : "Replace photo", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.bordered)
                .tint(MortColors.neon)
            }
            Text("Camera capture and removal are also available from Profile after setup.")
                .font(MortTypography.caption)
                .foregroundStyle(MortColors.textMuted)
        case .preferences:
            onboardingHeader("Shape your experience", "These details improve matching without making safety decisions for you.", "slider.horizontal.3")
            MortTextField(title: "Bio", text: $bio, prompt: "A short, useful introduction", axis: .vertical)
            MortTextField(title: "Availability", text: $availability, prompt: "Weekends, weekday evenings", axis: .vertical)
            MortTextField(title: "Goals", text: $goals, prompt: account.role == .teen ? "What do you want to learn or earn toward?" : "What kind of help are you looking for?", axis: .vertical)
            MortSectionHeader(title: "Preferred categories")
            categoryGrid
        case .payment:
            onboardingHeader("Payment preference", "Preference only. MORT does not process payments, hold funds, provide escrow, or guarantee payment.", "dollarsign.circle")
            Picker("Preference", selection: $paymentPreference) {
                Text("Discuss in MORT").tag("none")
                Text("Cash").tag("cash")
                Text("Cash App").tag("cash_app")
                Text("Square link").tag("square")
                Text("Other").tag("other")
            }
            .pickerStyle(.menu)
            if paymentPreference == "cash_app" {
                MortTextField(title: "Cash App tag", text: $cashAppTag, prompt: "$cashtag")
            }
            if paymentPreference == "square" {
                MortTextField(title: "Square URL", text: $squareURL, prompt: "https://...")
            }
            MortTextField(title: "Optional note", text: $paymentNote, prompt: "Payment details stay preference-only", axis: .vertical)
            MortAlertBanner(title: "No payment processing", message: "Agree on scope, timing, and payment clearly. Never send deposits or gift cards to strangers.", tint: MortColors.warning, icon: "exclamationmark.triangle.fill")
        case .guardian:
            onboardingHeader("Add a guardian? Optional.", "Guardian Mode can share selected safety alerts and check-ins with someone you trust. You can skip this and set it up later.", "person.2.badge.gearshape")
            ForEach(GuardianSetupChoice.allCases) { option in
                ChoiceRow(title: option.title, subtitle: guardianSubtitle(option), selected: guardianChoice == option) { guardianChoice = option }
            }
            if guardianChoice == .linkNow || guardianChoice == .sendInvite {
                MortTextField(title: "Guardian email (optional)", text: $guardianEmail, prompt: "guardian@example.com", keyboardType: .emailAddress, textContentType: .emailAddress)
            } else if guardianChoice == .enterCode {
                MortTextField(title: "Invite code", text: $inviteCode, prompt: "MORT code")
            }
            MortSafetyBanner(message: "Skipping does not block browsing, applying, normal messaging, or account use. Guardians never receive unrestricted message access.")
        case .safety:
            onboardingHeader("Safety is part of the product", "Pause and report anything that feels wrong. MORT does not replace emergency services.", "shield.lefthalf.filled")
            safetyRow("Keep communication in MORT", "The safety scanner can only help with messages sent in the app.")
            safetyRow("Protect private information", "Do not share your exact home, school schedule, passwords, codes, or financial credentials.")
            safetyRow("Trust your instincts", "Leave an unsafe situation and contact a trusted adult or emergency services when needed.")
            safetyRow("Use free safety tools", "Report, block, and Safety Ping are never behind a paywall.")
            Toggle("I reviewed these safety basics.", isOn: $acceptedSafety).tint(MortColors.neon)
        case .acknowledgement:
            onboardingHeader("Ready to use MORT", "One last check before your profile becomes active.", "checkmark.seal.fill")
            MortCard {
                VStack(alignment: .leading, spacing: MortSpacing.sm) {
                    Label("Role: \(account.title)", systemImage: "person.fill")
                    Label(locationSummary, systemImage: "mappin.and.ellipse")
                    Label("Payment: preference only", systemImage: "hand.raised.fill")
                    Label(account == .teen ? "Guardian Mode: \(guardianChoice.title)" : "Guardian setup: not required", systemImage: "shield.fill")
                }
            }
            Toggle("I agree to follow MORT's Community Rules and safety guidance.", isOn: $acceptedRules)
                .tint(MortColors.neon)
            Text("Completing setup writes the onboarding flag to Supabase. RLS remains the authority for every protected action.")
                .font(MortTypography.caption)
                .foregroundStyle(MortColors.textMuted)
        }
    }

    private var categoryGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: MortSpacing.sm)], spacing: MortSpacing.sm) {
            ForEach(categories, id: \.self) { category in
                Button {
                    if selectedCategories.contains(category) { selectedCategories.remove(category) }
                    else { selectedCategories.insert(category) }
                } label: {
                    Label(category.capitalized, systemImage: selectedCategories.contains(category) ? "checkmark.circle.fill" : "circle")
                        .font(MortTypography.caption)
                        .frame(maxWidth: .infinity, minHeight: 42)
                }
                .buttonStyle(.bordered)
                .tint(selectedCategories.contains(category) ? MortColors.neon : MortColors.textMuted)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: MortSpacing.sm) {
            if step != .welcome {
                Button("Back") { goBack() }
                    .buttonStyle(.bordered)
                    .tint(MortColors.text)
            }
            MortPrimaryButton(
                title: step == .acknowledgement ? "Finish setup" : "Continue",
                icon: step == .acknowledgement ? "checkmark" : "arrow.right",
                isLoading: isWorking,
                isDisabled: !canContinue
            ) {
                Task { await advance() }
            }
        }
        .padding(MortSpacing.md)
        .background(MortColors.elevated)
    }

    private var canContinue: Bool {
        switch step {
        case .age: dobText.count == 10
        case .basics:
            !displayName.trimmed.isEmpty && (account.role == .teen && locationSetupMode != "city_state" || (!city.trimmed.isEmpty && MortValidators.stateCode(state) == nil))
        case .identity: identityAcknowledged
        case .safety: acceptedSafety
        case .acknowledgement: acceptedRules
        default: true
        }
    }

    private func onboardingHeader(_ title: String, _ subtitle: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: MortSpacing.sm) {
            Image(systemName: icon).font(.system(size: 34, weight: .bold)).foregroundStyle(MortColors.neon)
            Text(title).font(MortTypography.title)
            Text(subtitle).foregroundStyle(MortColors.textMuted)
        }
    }

    private var onboardingIdentityRoutes: [IdentityEvidenceRoute] {
        account.role == .teen
            ? [.schoolPhotoID, .governmentID, .verifiedSchoolAccount, .approvedProgramID]
            : [.governmentID]
    }

    private func safetyRow(_ title: String, _ detail: String) -> some View {
        MortCard {
            HStack(alignment: .top, spacing: MortSpacing.sm) {
                Image(systemName: "checkmark.shield.fill").foregroundStyle(MortColors.safetyBlue)
                VStack(alignment: .leading, spacing: MortSpacing.xxs) {
                    Text(title).font(MortTypography.label)
                    Text(detail).font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                }
            }
        }
    }

    private func guardianSubtitle(_ choice: GuardianSetupChoice) -> String {
        switch choice {
        case .linkNow: "Create an invitation now"
        case .sendInvite: "Send or share a secure invitation"
        case .enterCode: "Use a code from an existing invitation"
        case .skip: "Continue with full basic account access"
        }
    }

    private func hydrateSavedProfile() {
        guard let profile = session.profile else { return }
        if let role = profile.role {
            account = role == .teen ? .teen : role == .guardian ? .guardian : .adult
        }
        displayName = profile.displayName ?? displayName
        city = profile.city ?? city
        state = profile.state ?? state
        dobText = profile.dob.map(DateOfBirthRules.formattedInput) ?? dobText
        bio = profile.bio ?? bio
        availability = profile.availability ?? availability
        area = profile.approximateArea ?? area
        goals = profile.goals ?? goals
        selectedCategories = Set(profile.preferredJobCategories)
        paymentPreference = profile.paymentPreference
        locationSetupMode = profile.locationSetupMode ?? "city_state"
    }

    private func loadPhoto(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw MortError.invalidInput("That photo could not be loaded.")
            }
            avatarData = data
        } catch {
            errorMessage = mortMessage(error)
        }
    }

    private func advance() async {
        successMessage = nil
        do {
            switch step {
            case .age:
                let date = try DateOfBirthRules.parse(dobText)
                try DateOfBirthRules.validateRole(account.role, date: date)
                dobDate = date
            case .basics:
                try await persistBaseProfile()
            case .identity:
                let status = try await container.verification.identityStatus()
                if status.status == "unverified" {
                    _ = try await container.verification.startIdentity(route: identityRoute, exceptionReason: nil)
                    successMessage = "Verification started. Add evidence from Verification after setup."
                }
            case .avatar:
                try await persistAvatarIfSelected()
            case .preferences:
                _ = try await container.profiles.saveDetails(ProfileDetailsUpdate(
                    displayName: displayName.trimmed,
                    bio: bio.nilIfBlank,
                    availability: availability.nilIfBlank,
                    preferredJobCategories: Array(selectedCategories).sorted(),
                    approximateArea: area.nilIfBlank,
                    goals: goals.nilIfBlank
                ))
            case .payment:
                try await container.profiles.savePaymentPreference(
                    preference: paymentPreference,
                    cashAppTag: cashAppTag.nilIfBlank,
                    squareURL: squareURL.nilIfBlank,
                    note: paymentNote.nilIfBlank
                )
            case .guardian where account.role == .teen:
                try await persistGuardianChoice()
            case .acknowledgement:
                isWorking = true
                defer { isWorking = false }
                try await container.profiles.completeOnboarding()
                await session.refreshProfile()
                return
            default:
                break
            }
            goForward()
        } catch {
            errorMessage = mortMessage(error)
        }
    }

    private func persistBaseProfile() async throws {
        isWorking = true
        defer { isWorking = false }
        let date = try DateOfBirthRules.parse(dobText)
        try DateOfBirthRules.validateRole(account.role, date: date)
        _ = try await container.profiles.saveProfile(
            role: account.role,
            displayName: displayName,
            dob: date,
            city: city,
            state: state,
            locationSetupMode: account.role == .teen ? locationSetupMode : "city_state",
            paymentPreference: paymentPreference,
            completeOnboarding: false
        )
        if account.role == .adult {
            try await container.profiles.saveAdultBusinessProfile(
                name: displayName,
                type: account == .business ? "business" : "individual"
            )
        }
        successMessage = "Your basics are safely stored in Supabase."
    }

    private var locationSummary: String {
        switch locationSetupMode {
        case "partner_supported": "Location: partner-supported setup"
        case "location_deferred": "Location: safely deferred"
        default: "Area: \(city), \(state.uppercased())"
        }
    }

    private func persistAvatarIfSelected() async throws {
        guard let avatarData else { return }
        isWorking = true
        defer { isWorking = false }
        let prepared = try ImageProcessingService.prepare(avatarData, purpose: .avatar)
        _ = try await container.storage.uploadAvatar(prepared, replacing: session.profile?.avatarPath)
        successMessage = "Your private avatar was uploaded."
    }

    private func persistGuardianChoice() async throws {
        isWorking = true
        defer { isWorking = false }
        switch guardianChoice {
        case .linkNow, .sendInvite:
            let result = try await container.guardians.createInvite(email: guardianEmail.nilIfBlank)
            if let code = result.inviteCode { successMessage = "Invite created. Code: \(code)" }
            else { successMessage = "Guardian invite created." }
        case .enterCode:
            guard !inviteCode.trimmed.isEmpty else { throw MortError.invalidInput("Enter the guardian invite code.") }
            _ = try await container.guardians.acceptInvite(code: inviteCode)
            successMessage = "Guardian linked."
        case .skip:
            try await container.guardians.skipSetup()
        }
    }

    private func goForward() {
        var next = step.rawValue + 1
        if OnboardingStep(rawValue: next) == .guardian, account.role != .teen { next += 1 }
        if let value = OnboardingStep(rawValue: next) { step = value }
    }

    private func goBack() {
        var previous = step.rawValue - 1
        if OnboardingStep(rawValue: previous) == .guardian, account.role != .teen { previous -= 1 }
        if let value = OnboardingStep(rawValue: previous) { step = value }
    }
}

private struct ChoiceRow: View {
    let title: String
    let subtitle: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MortSpacing.md) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? MortColors.neon : MortColors.textMuted)
                VStack(alignment: .leading, spacing: MortSpacing.xxs) {
                    Text(title).font(MortTypography.label).foregroundStyle(MortColors.text)
                    Text(subtitle).font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                }
                Spacer()
            }
            .padding(MortSpacing.md)
            .background(MortColors.card)
            .overlay(RoundedRectangle(cornerRadius: MortRadius.medium).stroke(selected ? MortColors.neon : MortColors.line))
            .clipShape(RoundedRectangle(cornerRadius: MortRadius.medium))
        }
        .buttonStyle(.plain)
    }
}
