import SwiftUI

struct ProofReviewView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(Router.self) private var router
    @State private var state: LoadState<[ProofUpload]> = .idle
    @State private var proofURL: URL?
    @State private var reviewNote = ""
    @State private var isWorking = false
    @State private var notice: String?
    @State private var confirmCompletion = false
    let applicationID: UUID

    var body: some View {
        Group {
            switch state {
            case .idle, .loading:
                MortLoadingState(label: "Loading private proof")
            case let .failed(message):
                MortErrorState(message: message) { Task { await load() } }
            case let .loaded(proofs) where proofs.isEmpty:
                MortEmptyState(
                    title: "No proof submitted",
                    message: "The accepted worker has not submitted completion proof for this application.",
                    systemImage: "doc.badge.clock"
                )
            case let .loaded(proofs):
                proofContent(proofs[0])
            }
        }
        .navigationTitle("Proof review")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .alert("MORT", isPresented: Binding(
            get: { notice != nil },
            set: { if !$0 { notice = nil } }
        )) {
            Button("OK", role: .cancel) { notice = nil }
        } message: {
            Text(notice ?? "")
        }
        .confirmationDialog("Mark this job complete?", isPresented: $confirmCompletion, titleVisibility: .visible) {
            Button("Mark complete") { Task { await completeJob() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Completion is available only after the current proof is approved.")
        }
        .mortScreen()
    }

    private func proofContent(_ proof: ProofUpload) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                MortSectionHeader(
                    title: "Completion evidence",
                    subtitle: "Review only the work shown. Do not download, repost, or use this private image outside the job workflow."
                )
                MortSafetyBanner(message: "A proof photo is evidence, not permission to expose a teen, address, or unrelated person.")
                MortAsyncImage(url: proofURL, height: 260)
                    .accessibilityLabel("Private completion proof image")
                MortCard {
                    VStack(alignment: .leading, spacing: MortSpacing.sm) {
                        MortBadge(text: proof.statusTitle, tint: statusTint(proof.status))
                        if let note = proof.note?.nilIfBlank {
                            Text("Worker note").font(MortTypography.label)
                            Text(note).foregroundStyle(MortColors.textMuted)
                        }
                        if let reviewNote = proof.reviewNote?.nilIfBlank {
                            Text("Review note").font(MortTypography.label)
                            Text(reviewNote).foregroundStyle(MortColors.textMuted)
                        }
                        Text("Submitted \(DateFormatting.displayDateTime(proof.createdAt))")
                            .font(MortTypography.caption)
                            .foregroundStyle(MortColors.textMuted)
                    }
                }

                if proof.status == "submitted" {
                    MortTextField(
                        title: "Review note",
                        text: $reviewNote,
                        prompt: "Required when requesting a new proof",
                        axis: .vertical
                    )
                    MortPrimaryButton(title: "Approve proof", icon: "checkmark.circle.fill", isLoading: isWorking) {
                        Task { await review(proof, action: "approved") }
                    }
                    MortSecondaryButton(title: "Request a new proof", icon: "arrow.triangle.2.circlepath") {
                        Task { await review(proof, action: "resubmission_requested") }
                    }
                    MortDangerButton(title: "Reject this proof") {
                        Task { await review(proof, action: "rejected") }
                    }
                } else if proof.status == "approved" {
                    MortPrimaryButton(title: "Mark job complete", icon: "checkmark.seal.fill", isLoading: isWorking) {
                        confirmCompletion = true
                    }
                } else {
                    MortAlertBanner(
                        title: "Waiting for replacement proof",
                        message: "The application returned to in-progress state so the teen can upload a new proof.",
                        tint: MortColors.warning,
                        icon: "arrow.triangle.2.circlepath"
                    )
                }
            }
            .padding(MortSpacing.lg)
        }
    }

    private func review(_ proof: ProofUpload, action: String) async {
        let cleanNote = reviewNote.trimmed
        if action != "approved" && cleanNote.count < 10 {
            notice = "Add at least 10 characters explaining what the worker should change."
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            _ = try await container.applications.reviewProof(
                proofID: proof.id,
                action: action,
                note: cleanNote.nilIfBlank
            )
            reviewNote = ""
            notice = action == "approved" ? "Proof approved." : "The worker was asked to submit a new proof."
            await load()
        } catch {
            notice = mortMessage(error)
        }
    }

    private func completeJob() async {
        isWorking = true
        defer { isWorking = false }
        do {
            _ = try await container.applications.updateStatus(applicationID: applicationID, action: "completed")
            router.pop()
        } catch {
            notice = mortMessage(error)
        }
    }

    private func load() async {
        state = .loading
        proofURL = nil
        do {
            let proofs = try await container.applications.proofs(applicationID: applicationID)
            state = .loaded(proofs)
            if let proof = proofs.first {
                proofURL = try await container.storage.signedURL(
                    bucket: StorageRepository.proofBucket,
                    path: proof.storagePath,
                    expiresIn: 600
                )
            }
        } catch {
            state = .failed(mortMessage(error))
        }
    }

    private func statusTint(_ status: String) -> Color {
        switch status {
        case "approved": MortColors.neon
        case "submitted": MortColors.safetyBlue
        default: MortColors.warning
        }
    }
}
