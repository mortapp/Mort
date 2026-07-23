import SwiftUI

struct DocumentCaptureQualityView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var status: FirstPartyTrustStatus?
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                MortSectionHeader(title: "Document capture readiness", subtitle: "Quality architecture exists; hosted real-person collection remains disabled.")
                if let status {
                    trustFlag("Real document collection", status.realDocumentCollectionEnabled)
                    trustFlag("External web-reuse provider", status.externalWebReuseEnabled)
                    trustFlag("Authoritative identity provider", status.authoritativeIdentityProviderConnected)
                }
                MortAlertBanner(
                    title: "Real ID capture is disabled",
                    message: "Do not photograph or upload a real driver's license, state ID, passport, school ID, selfie, or face video. Current capture QA is synthetic-only and unavailable from this user screen.",
                    tint: MortColors.danger,
                    icon: "camera.fill"
                )
                FeatureChecklistView(items: [
                    "Future quality checks may assess blur, glare, framing, edge visibility, resolution, and document-side completeness.",
                    "OCR, barcode, MRZ, visual review, or a clear image would not by themselves prove authenticity or legal identity.",
                    "Real collection requires counsel, privacy and biometric review, retention controls, trained reviewers, incident response, insurance review, and a connected authoritative provider."
                ])
                if let error { Text(error).foregroundStyle(MortColors.warning) }
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("Capture quality")
        .task { await load() }
        .mortScreen()
    }

    private func trustFlag(_ label: String, _ enabled: Bool) -> some View {
        HStack { Text(label); Spacer(); MortBadge(text: enabled ? "Enabled" : "Disabled", tint: enabled ? MortColors.neon : MortColors.warning) }
    }

    private func load() async {
        do { status = try await container.firstPartyTrust.status() }
        catch { self.error = mortMessage(error) }
    }
}

struct LivePresenceChallengeView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(Router.self) private var router
    @State private var status: FirstPartyTrustStatus?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                MortSectionHeader(title: "Live-presence challenge", subtitle: "A future replay-resistant signal, not legal identity proof.")
                MortAlertBanner(
                    title: status?.realLivePresenceEnabled == true ? "Readiness review required" : "Real liveness is disabled",
                    message: "MORT does not collect a real face video from this screen. Synthetic QA challenges are reserved for controlled testing and create no identity level.",
                    tint: MortColors.warning,
                    icon: "person.crop.square.badge.video"
                )
                FeatureChecklistView(items: [
                    "A server-issued random sequence, nonce, expiration, and one-time result binding reduce basic replay risk.",
                    "Blinking, head motion, speech, or camera presence cannot prove legal name, age, document ownership, or safety.",
                    "No persistent face template should be created by this workflow."
                ])
                MortSecondaryButton(title: "Accessibility alternatives", icon: "accessibility") {
                    router.push(.livePresenceAccessibility)
                }
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("Live presence")
        .task { status = try? await container.firstPartyTrust.status() }
        .mortScreen()
    }
}

struct LivePresenceAccessibilityView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                MortSectionHeader(title: "Accessible alternative", subtitle: "A person is never penalized for being unable to perform a camera gesture.")
                FeatureChecklistView(items: [
                    "Offer a non-gesture route when movement, vision, speech, lighting, device access, disability, culture, or trauma makes the challenge unsuitable.",
                    "Route to a trained human review or another approved evidence method without lowering safety standards.",
                    "Do not infer disability, identity, deception, or risk from a failed or skipped gesture.",
                    "Provide appeal, time extensions, and plain-language assistance."
                ])
                MortAlertBanner(title: "No identity conclusion", message: "An accessible alternative and a passed live-presence signal both remain limited evidence. Neither proves legal identity.", tint: MortColors.safetyBlue, icon: "person.crop.circle.badge.questionmark")
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("Liveness accessibility")
        .mortScreen()
    }
}

struct TeamAccessReviewView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(Router.self) private var router
    @State private var assignments: [TeamRoleAssignmentRecord] = []
    @State private var error: String?

    var body: some View {
        List {
            Section {
                MortAlertBanner(
                    title: "No automatic access",
                    message: "Family, friend, founder, admin, cybersecurity, or group-chat status grants no evidence access. Roles require purpose, training, confidentiality, conflict, device, approval, expiry, assignment, and audit controls.",
                    tint: MortColors.warning,
                    icon: "person.badge.key.fill"
                )
            }
            Section("Bounded assignments") {
                if assignments.isEmpty { Text("No team assignments are visible to this account.") }
                ForEach(assignments) { assignment in
                    VStack(alignment: .leading, spacing: MortSpacing.xs) {
                        HStack { Text(assignment.roleKey.replacingOccurrences(of: "_", with: " ").capitalized); Spacer(); MortBadge(text: assignment.accessStatus.capitalized, tint: assignment.accessStatus == "active" ? MortColors.neon : MortColors.warning) }
                        Text("Environment: \(assignment.environmentScope)").font(MortTypography.caption)
                        Text("Purpose: \(assignment.accessReason)").font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                        Text("Expires: \(assignment.expiresAt)").font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                    }
                }
            }
            Section {
                Button("Assign synthetic appearance reviewer") { router.push(.reviewerAssignment) }
                Text("Raw IDs, face media, production secrets, and sensitive evidence must never be placed in consumer group chat.")
                    .font(MortTypography.caption)
                    .foregroundStyle(MortColors.textMuted)
            }
            if let error { Section { Text(error).foregroundStyle(MortColors.warning) } }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Team access review")
        .task { await load() }
        .mortScreen()
    }

    private func load() async {
        do { assignments = try await container.firstPartyTrust.teamAssignments() }
        catch { error = mortMessage(error) }
    }
}

struct ReviewerAssignmentView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var cases: [AppearanceReviewCaseRecord] = []
    @State private var reviewerID = ""
    @State private var position = 1
    @State private var purpose = ""
    @State private var message: String?

    var body: some View {
        List {
            Section {
                MortAlertBanner(
                    title: "Synthetic QA only",
                    message: "The backend rejects assignment unless the case is synthetic and contains no real face data. This screen does not enable real document or appearance review.",
                    tint: MortColors.danger,
                    icon: "testtube.2"
                )
                MortTextField(title: "Reviewer user ID", text: $reviewerID, prompt: "UUID for a trained team member")
                Picker("Review position", selection: $position) { Text("First reviewer").tag(1); Text("Second reviewer").tag(2) }
                MortTextField(title: "Purpose", text: $purpose, prompt: "Specific bounded review purpose")
            }
            Section("Eligible cases") {
                if cases.isEmpty { Text("No synthetic appearance cases are visible.") }
                ForEach(cases) { item in
                    VStack(alignment: .leading, spacing: MortSpacing.sm) {
                        HStack { Text(item.reviewState.replacingOccurrences(of: "_", with: " ").capitalized); Spacer(); MortBadge(text: item.syntheticQA && !item.containsRealFaceData ? "Synthetic" : "Blocked", tint: item.syntheticQA && !item.containsRealFaceData ? MortColors.neon : MortColors.danger) }
                        Text(item.id.uuidString).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                        MortSecondaryButton(title: "Assign reviewer", icon: "person.badge.plus") { Task { await assign(item) } }
                            .disabled(!item.syntheticQA || item.containsRealFaceData || UUID(uuidString: reviewerID) == nil || purpose.trimmed.count < 8)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Reviewer assignment")
        .task { await load() }
        .alert("Reviewer assignment", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK", role: .cancel) {} } message: { Text(message ?? "") }
        .mortScreen()
    }

    private func load() async {
        do { cases = try await container.firstPartyTrust.appearanceCases() }
        catch { message = mortMessage(error) }
    }

    private func assign(_ item: AppearanceReviewCaseRecord) async {
        guard let reviewer = UUID(uuidString: reviewerID) else { return }
        do {
            _ = try await container.firstPartyTrust.assignAppearanceReviewer(caseID: item.id, reviewerID: reviewer, position: position, purpose: purpose)
            message = "Bounded synthetic reviewer assignment created. Readiness and case access remain server-enforced."
            await load()
        } catch { message = mortMessage(error) }
    }
}

private struct FeatureChecklistView: View {
    let items: [String]

    var body: some View {
        MortCard {
            VStack(alignment: .leading, spacing: MortSpacing.sm) {
                ForEach(items, id: \.self) { item in
                    Label { Text(item).foregroundStyle(MortColors.textMuted) } icon: { Image(systemName: "checkmark.circle") .foregroundStyle(MortColors.neon) }
                }
            }
        }
    }
}
