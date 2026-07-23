import SwiftUI

struct VerificationView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(SessionStore.self) private var session
    @State private var identityState: LoadState<IdentityVerificationSummary> = .idle
    @State private var businessState: LoadState<[BusinessVerification]> = .idle
    @State private var appealReason = ""
    @State private var isWorking = false
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                identityHeader
                identityContent
                if session.profile?.role == .adult {
                    Divider().overlay(MortColors.border)
                    businessContent
                }
                MortSafetyBanner(message: "Verification reduces impersonation risk but cannot guarantee a person's conduct or safety. Raw identity, school, selfie, and address evidence is never shown to marketplace users, guardians, or job participants.")
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("Verification")
        .navigationBarTitleDisplayMode(.inline)
        .alert("MORT", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "Verification is unavailable.") }
        .task { await load() }
        .mortScreen()
    }

    private var identityHeader: some View {
        VStack(alignment: .leading, spacing: MortSpacing.sm) {
            MortSectionHeader(
                title: "Identity and age verification",
                subtitle: "Public marketplace participation stays closed until secure production verification is available. Guardian Mode remains optional."
            )
            HStack {
                Label("Safety tools stay free", systemImage: "lock.open.fill")
                Spacer()
                Label("Private evidence", systemImage: "lock.shield.fill")
            }
            .font(MortTypography.caption)
            .foregroundStyle(MortColors.safetyBlue)
        }
    }

    @ViewBuilder
    private var identityContent: some View {
        switch identityState {
        case .idle, .loading:
            MortLoadingState(label: "Loading verification status")
        case let .failed(error):
            MortErrorState(message: error) { Task { await loadIdentity() } }
        case let .loaded(summary):
            identityStatusCard(summary)
            verificationModeState(summary)
            if summary.verificationMode == "production",
               ["verification_rejected", "verification_expired", "verification_suspended"].contains(summary.status),
               let id = summary.id {
                appealForm(id: id)
            }
            if summary.verificationMode == "production",
               ["verification_pending", "manual_review", "appeal_pending"].contains(summary.status) {
                MortAlertBanner(title: "Review pending", message: "Marketplace actions stay locked while authorized reviewers assess the minimum evidence needed. Reports, blocking, support, and emergency guidance remain available.", tint: MortColors.warning, icon: "hourglass")
            }
        }
    }

    private func identityStatusCard(_ summary: IdentityVerificationSummary) -> some View {
        MortCard {
            VStack(alignment: .leading, spacing: MortSpacing.sm) {
                HStack {
                    Text("Marketplace identity").font(MortTypography.section)
                    Spacer()
                    MortBadge(
                        text: summary.productionVerified == true
                            ? "Production verified"
                            : summary.environment == "sandbox"
                                ? "TEST MODE"
                                : summary.status.replacingOccurrences(of: "_", with: " ").capitalized,
                        tint: summary.productionVerified == true ? MortColors.neon : MortColors.warning
                    )
                }
                Label(summary.marketplaceEnabled ? "Marketplace actions enabled" : "Marketplace actions locked", systemImage: summary.marketplaceEnabled ? "checkmark.seal.fill" : "lock.fill")
                    .font(MortTypography.label)
                    .foregroundStyle(summary.marketplaceEnabled ? MortColors.neon : MortColors.warning)
                Text("Mode \(summary.verificationMode ?? "disabled") | Guardian Mode optional: \(summary.guardianModeOptional ? "Yes" : "No")")
                    .font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                if let environment = summary.environment {
                    Text("Environment: \(environment)\(environment == "sandbox" ? " (never production eligible)" : "")")
                        .font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                }
                if let expiresAt = summary.expiresAt {
                    Text("Recheck by \(DateFormatting.displayDateTime(expiresAt))").font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                }
            }
        }
    }

    @ViewBuilder
    private func verificationModeState(_ summary: IdentityVerificationSummary) -> some View {
        if summary.verificationMode == "disabled" || summary.verificationMode == nil {
            MortAlertBanner(
                title: "Identity verification is not accepting public submissions yet.",
                message: "MORT is still preparing its secure verification system. Do not upload an ID or personal document.",
                tint: MortColors.warning,
                icon: "lock.shield.fill"
            )
        } else if summary.verificationMode == "sandbox" {
            if summary.sandboxEligible == true {
                VStack(alignment: .leading, spacing: MortSpacing.md) {
                    MortAlertBanner(
                        title: "TEST MODE",
                        message: "Test verification - do not use real documents. Sandbox results never grant production eligibility.",
                        tint: MortColors.warning,
                        icon: "testtube.2"
                    )
                    if summary.id == nil || summary.status == "unverified" {
                        MortPrimaryButton(
                            title: "Start simulated verification",
                            icon: "testtube.2",
                            isLoading: isWorking
                        ) {
                            Task { await startSandboxSession(summary: summary) }
                        }
                    }
                }
            } else {
                MortAlertBanner(
                    title: "Sandbox restricted",
                    message: "Test verification is available only to explicitly isolated QA accounts.",
                    tint: MortColors.warning,
                    icon: "lock.fill"
                )
            }
        } else if summary.productionProviderAvailable != true {
            MortAlertBanner(
                title: "Production provider unavailable",
                message: "Production verification fails closed until an approved provider, signed webhook, legal approval, retention policy, and trained operations are ready.",
                tint: MortColors.warning,
                icon: "lock.shield.fill"
            )
        } else {
            MortAlertBanner(
                title: "Provider session required",
                message: "Verification is available only through the backend-confirmed approved provider session.",
                tint: MortColors.safetyBlue,
                icon: "checkmark.shield.fill"
            )
        }
    }

    private func appealForm(id: UUID) -> some View {
        VStack(alignment: .leading, spacing: MortSpacing.md) {
            MortSectionHeader(title: "Request another review", subtitle: "An appeal does not automatically restore marketplace access.")
            MortTextField(title: "Appeal reason", text: $appealReason, prompt: "Explain what the reviewer should reconsider", axis: .vertical)
            MortPrimaryButton(title: "Submit appeal", icon: "arrow.triangle.2.circlepath", isLoading: isWorking, isDisabled: appealReason.trimmed.count < 20) {
                Task { await appealIdentity(verificationID: id) }
            }
        }
    }

    private var businessContent: some View {
        VStack(alignment: .leading, spacing: MortSpacing.lg) {
            MortSectionHeader(title: "Adult or business trust check", subtitle: "New verification evidence intake is paused with public identity verification.")
            MortAlertBanner(
                title: "Evidence intake unavailable",
                message: "Do not upload a personal ID or private document. Existing status history remains visible while MORT prepares an approved provider workflow.",
                tint: MortColors.warning,
                icon: "lock.shield.fill"
            )
            businessHistory
        }
    }

    @ViewBuilder
    private var businessHistory: some View {
        switch businessState {
        case .idle, .loading: ProgressView().tint(MortColors.neon)
        case let .failed(error): MortAlertBanner(title: "Business history unavailable", message: error)
        case let .loaded(items) where items.isEmpty: Text("No business trust-check submissions yet.").foregroundStyle(MortColors.textMuted)
        case let .loaded(items):
            ForEach(items) { item in
                MortCard {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.businessName).font(MortTypography.label)
                            Text(item.businessType.capitalized).font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                        }
                        Spacer()
                        MortBadge(text: item.status, tint: statusTint(item.status))
                    }
                }
            }
        }
    }

    private func load() async {
        await loadIdentity()
        if session.profile?.role == .adult { await loadBusiness() }
    }

    private func loadIdentity() async {
        identityState = .loading
        do {
            let summary = try await container.verification.identityStatus()
            identityState = .loaded(summary)
        } catch { identityState = .failed(mortMessage(error)) }
    }

    private func loadBusiness() async {
        businessState = .loading
        do { businessState = .loaded(try await container.verification.listMine()) }
        catch { businessState = .failed(mortMessage(error)) }
    }

    private func startSandboxSession(summary: IdentityVerificationSummary) async {
        isWorking = true
        defer { isWorking = false }
        do {
            let provider: any IdentityVerificationProvider
            if summary.verificationMode == "sandbox", summary.sandboxEligible == true {
                provider = SandboxVerificationProvider {
                    try await container.verification.createSandboxIdentitySession()
                }
            } else if summary.verificationMode == "production", summary.productionProviderAvailable == true {
                provider = UnavailableProductionVerificationProvider()
            } else {
                provider = DisabledVerificationProvider()
            }
            let providerSession = try await provider.createSession()
            guard providerSession.documentsAllowed == false else {
                throw MortError.backend(code: "sandbox_documents_prohibited", message: "Sandbox sessions must never allow documents.")
            }
            message = "Sandbox session created. No documents were collected."
            await loadIdentity()
        } catch { message = mortMessage(error) }
    }

    private func appealIdentity(verificationID: UUID) async {
        isWorking = true
        defer { isWorking = false }
        do {
            _ = try await container.verification.appealIdentity(verificationID: verificationID, reason: appealReason)
            appealReason = ""
            message = "Appeal submitted. Access is not restored until an authorized review approves it."
            await loadIdentity()
        } catch { message = mortMessage(error) }
    }

}
