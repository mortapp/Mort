import SwiftUI

struct LegalCenterView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(Router.self) private var router
    @State private var state: LoadState<LegalRequirementsResponse> = .idle

    var body: some View {
        Group {
            switch state {
            case .idle, .loading:
                MortLoadingState(label: "Loading legal requirements")
            case let .failed(message):
                MortErrorState(message: message) { Task { await load() } }
            case let .loaded(response):
                List {
                    Section {
                        MortAlertBanner(
                            title: "Attorney review is still required",
                            message: "MORT's legal files are drafts and are not legally approved. Only a future published, effective, exact-hash version can be accepted here.",
                            tint: MortColors.warning,
                            icon: "doc.badge.clock"
                        )
                    }
                    Section("Required for your account") {
                        if response.requirements.isEmpty {
                            Text("No attorney-approved legal version is currently published for clickwrap. Browsing MORT does not create acceptance.")
                                .foregroundStyle(MortColors.textMuted)
                        }
                        ForEach(response.requirements) { requirement in
                            Button { router.push(.legalAcceptance(requirement)) } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: MortSpacing.xs) {
                                        Text(requirement.title).foregroundStyle(MortColors.text)
                                        Text("Version \(requirement.versionLabel) | \(requirement.contentHash.prefix(12))...")
                                            .font(MortTypography.caption)
                                            .foregroundStyle(MortColors.textMuted)
                                    }
                                    Spacer()
                                    Image(systemName: requirement.needsAcceptance ? "square.and.pencil" : "checkmark.seal.fill")
                                        .foregroundStyle(requirement.needsAcceptance ? MortColors.warning : MortColors.neon)
                                }
                            }
                        }
                    }
                    Section("Plain-language and reference documents") {
                        Button("Teen terms summary") { router.push(.teenTermsSummary) }
                        ForEach(LegalDocument.allCases) { document in
                            Button(document.title) { router.push(.legal(document)) }
                        }
                    }
                    Section("Consent boundaries") {
                        Label("No prechecked boxes", systemImage: "checkmark.square.fill")
                        Label("No acceptance inferred from browsing", systemImage: "hand.raised.fill")
                        Label("Guardian Mode stays optional", systemImage: "person.2.slash")
                        Text("Minor capacity, enforceability, electronic signatures, arbitration, class actions, and jurisdiction rules require qualified attorney review.")
                            .font(MortTypography.caption)
                            .foregroundStyle(MortColors.textMuted)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Legal center")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .mortScreen()
    }

    private func load() async {
        state = .loading
        do { state = .loaded(try await container.legalAcceptance.requirements()) }
        catch { state = .failed(mortMessage(error)) }
    }
}

struct TeenTermsSummaryView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                MortAlertBanner(
                    title: "Plain-language summary",
                    message: "This helps teens understand the draft rules. It does not replace the full agreement or attorney review.",
                    tint: MortColors.safetyBlue,
                    icon: "text.book.closed.fill"
                )
                summary("Use MORT honestly", "Use your real role and age information. Do not impersonate someone or evade account restrictions.")
                summary("Only accept work you can safely do", "Never accept prohibited, sexual, illegal, dangerous, overnight, or age-inappropriate work. Leave when something feels unsafe.")
                summary("Keep private details protected", "Use general locations until an accepted job reaches the authorized release stage. Keep communication in MORT.")
                summary("Payment is off-platform", "MORT records the agreement and payment status but does not process money, hold escrow, or guarantee recovery.")
                summary("Reports are private allegations", "A report does not automatically prove guilt. MORT preserves evidence, limits retaliation, and uses review and appeal steps.")
                summary("Verification has limits", "Document quality, web-image reuse, live-presence checks, school email, and device Face ID do not by themselves prove legal identity or safety.")
                summary("Guardian Mode is optional", "A teen can choose Guardian Mode where offered. Separate law or pilot eligibility rules are not silently tied to that choice.")
                MortSafetyBanner(message: "Immediate danger belongs with emergency services and a trusted adult. MORT is not emergency services or legal representation.")
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("Teen terms summary")
        .navigationBarTitleDisplayMode(.inline)
        .mortScreen()
    }

    private func summary(_ title: String, _ body: String) -> some View {
        MortCard {
            VStack(alignment: .leading, spacing: MortSpacing.xs) {
                Text(title).font(MortTypography.section)
                Text(body).foregroundStyle(MortColors.textMuted)
            }
        }
    }
}

struct LegalReacceptanceView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(Router.self) private var router
    let requirement: LegalRequirementItem

    @State private var versionState: LoadState<PublishedLegalVersion> = .idle
    @State private var summaryViewed = false
    @State private var affirmative = false
    @State private var signature = ""
    @State private var working = false
    @State private var message: String?

    var body: some View {
        Group {
            switch versionState {
            case .idle, .loading:
                MortLoadingState(label: "Loading exact legal version")
            case let .failed(message):
                MortErrorState(message: message) { Task { await load() } }
            case let .loaded(version):
                ScrollView {
                    VStack(alignment: .leading, spacing: MortSpacing.lg) {
                        MortAlertBanner(
                            title: requirement.reacceptanceRequirementID == nil ? "Affirmative clickwrap" : "Material revision",
                            message: "Acceptance is bound to version \(version.versionLabel) and SHA-256 \(version.contentHash). It is never inferred from browsing.",
                            tint: MortColors.warning,
                            icon: "signature"
                        )
                        TeenTermsSummaryView()
                            .frame(minHeight: 520)
                            .clipShape(RoundedRectangle(cornerRadius: MortRadius.medium))
                        Toggle("I reviewed the teen plain-language summary first", isOn: $summaryViewed)
                        Divider()
                        Text(requirement.title).font(MortTypography.title)
                        Text(version.contentMarkdown)
                            .textSelection(.enabled)
                            .foregroundStyle(MortColors.textMuted)
                        if requirement.requiresElectronicSignature {
                            MortTextField(title: "Type your name", text: $signature, prompt: "Electronic signature")
                        }
                        Toggle("I affirmatively agree to this exact version", isOn: $affirmative)
                        MortPrimaryButton(title: "Accept exact version", icon: "checkmark.seal.fill", isLoading: working) {
                            Task { await accept() }
                        }
                        .disabled(!summaryViewed || !affirmative || (requirement.requiresElectronicSignature && signature.trimmed.count < 3))
                        MortSecondaryButton(title: "Not now", icon: "xmark") { router.pop() }
                    }
                    .padding(MortSpacing.lg)
                }
            }
        }
        .navigationTitle(requirement.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .alert("Legal response", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
        .mortScreen()
    }

    private func load() async {
        versionState = .loading
        do { versionState = .loaded(try await container.legalAcceptance.version(id: requirement.versionID)) }
        catch { versionState = .failed(mortMessage(error)) }
    }

    private func accept() async {
        guard summaryViewed, affirmative else { return }
        working = true
        defer { working = false }
        do {
            _ = try await container.legalAcceptance.accept(
                versionID: requirement.versionID,
                teenSummaryViewed: summaryViewed,
                signature: signature
            )
            message = "Acceptance recorded for the exact document hash and version."
            affirmative = false
        } catch { message = mortMessage(error) }
    }
}
