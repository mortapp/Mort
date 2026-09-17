//
//  JobCreateView.swift
//  MORT iOS V8 — Jobs
//
//  Job posting with the Fair Pay guardrail embedded. A RED verdict genuinely
//  disables posting — and the backend re-validates on submit regardless.
//

import SwiftUI

@Observable
@MainActor
final class JobCreateViewModel {
    var title = ""
    var category = MortFixtures.categories[0]
    var details = ""
    var scheduleText = ""
    var requiresProof = false
    var offeredCents: Int64 = 2000
    var policy: FairPayPolicy = .reference
    var isSubmitting = false
    var error: MortError?
    var created: MortJob?

    private let mort: MortDependencies
    init(mort: MortDependencies) { self.mort = mort }

    var verdict: FairPayVerdict {
        FairPayVerdict.evaluate(offeredCents: offeredCents, policy: policy)
    }

    var canPost: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && !details.trimmingCharacters(in: .whitespaces).isEmpty
            && !scheduleText.trimmingCharacters(in: .whitespaces).isEmpty
            && verdict.canPost
            && !isSubmitting
    }

    func loadPolicy() async {
        policy = (try? await mort.jobs.fairPayPolicy(category: category)) ?? .reference
    }

    func post() async {
        isSubmitting = true
        error = nil
        do {
            created = try await mort.jobs.createJob(
                title: title,
                category: category,
                details: details,
                baseCents: offeredCents,
                scheduleText: scheduleText,
                requiresProof: requiresProof
            )
            MortHaptic.success()
        } catch let failure as MortError {
            // The backend can still reject an offer the client thought was OK.
            error = failure
            MortHaptic.failure()
        } catch {
            self.error = .unknown
            MortHaptic.failure()
        }
        isSubmitting = false
    }
}

struct JobCreateView: View {
    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var model: JobCreateViewModel?

    var body: some View {
        MortScreen(
            title: "Post a job",
            subtitle: "Describe the work, then set fair pay for it.",
            atmosphereIntensity: 0.65
        ) {
            if let model {
                VStack(alignment: .leading, spacing: MortSpace.s6) {
                    if let error = model.error {
                        MortStatusPanel(
                            tone: .danger,
                            symbol: "exclamationmark.triangle",
                            label: "COULDN'T POST",
                            detail: error.userMessage
                        )
                    }

                    VStack(alignment: .leading, spacing: MortSpace.s4) {
                        MortTextField(
                            label: "Job title",
                            placeholder: "e.g. Lawn mowing and edging",
                            text: Binding(get: { model.title }, set: { model.title = $0 }),
                            symbol: "text.alignleft"
                        )

                        VStack(alignment: .leading, spacing: MortSpace.s2) {
                            Text("CATEGORY").mortEyebrow()
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 112), spacing: MortSpace.s2)],
                                spacing: MortSpace.s2
                            ) {
                                ForEach(MortFixtures.categories, id: \.self) { category in
                                    MortChip(
                                        label: category,
                                        isSelected: model.category == category
                                    ) {
                                        model.category = category
                                        Task { await model.loadPolicy() }
                                    }
                                }
                            }
                        }

                        MortTextArea(
                            label: "What needs doing",
                            placeholder: "Be specific — tools available, how long it should take, anything they should know.",
                            text: Binding(get: { model.details }, set: { model.details = $0 })
                        )

                        MortTextField(
                            label: "When",
                            placeholder: "e.g. Saturday, 10:00 AM",
                            text: Binding(get: { model.scheduleText }, set: { model.scheduleText = $0 }),
                            symbol: "calendar"
                        )

                        MortCard {
                            MortToggleRow(
                                title: "Ask for proof when done",
                                detail: "Your worker adds a photo or note before you confirm.",
                                symbol: "camera",
                                isOn: Binding(get: { model.requiresProof }, set: { model.requiresProof = $0 })
                            )
                        }
                    }

                    FairPayGuardrail(
                        offeredCents: Binding(get: { model.offeredCents }, set: { model.offeredCents = $0 }),
                        policy: model.policy
                    )
                }
            }
        } bottom: {
            if let model {
                MortBottomBar {
                    MortPrimaryButton(
                        title: model.verdict.canPost ? "Post this job" : "Raise the offer to post",
                        symbol: model.verdict.canPost ? "paperplane.fill" : "lock",
                        isBusy: model.isSubmitting,
                        isEnabled: model.canPost,
                        busyTitle: "Posting…"
                    ) {
                        Task {
                            await model.post()
                            if model.created != nil { nav.popToRoot() }
                        }
                    }
                    if !model.verdict.canPost {
                        MortNote(
                            text: "Posting is blocked below \(model.policy.hardMinimum.formatted). Nothing is wrong with you — this keeps work fair.",
                            tone: .danger
                        )
                    }
                }
            }
        }
        .navigationTitle("New job")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if model == nil { model = JobCreateViewModel(mort: mort) }
            await model?.loadPolicy()
        }
    }
}

struct JobEditView: View {
    let jobId: String

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var job: LoadState<MortJob> = .idle
    @State private var title = ""
    @State private var details = ""
    @State private var offeredCents: Int64 = 0
    @State private var policy: FairPayPolicy = .reference
    @State private var isSaving = false
    @State private var error: MortError?

    private var verdict: FairPayVerdict {
        FairPayVerdict.evaluate(offeredCents: offeredCents, policy: policy)
    }

    var body: some View {
        MortScreen(title: "Edit job", atmosphereIntensity: 0.65) {
            switch job {
            case .idle, .loading:
                MortSkeletonList(rows: 4)
            case .failed(let failure):
                MortErrorState(message: failure.userMessage) { Task { await load() } }
            case .loaded(let value), .offlineCache(let value):
                VStack(alignment: .leading, spacing: MortSpace.s5) {
                    if let error {
                        MortNote(text: error.userMessage, tone: .danger)
                    }
                    if value.state != .open {
                        MortRestrictedState(
                            title: "This job can't be edited",
                            message: "Once a job is accepted or funded, its details are locked so both sides agree on the same work.",
                            symbol: "lock"
                        )
                    } else {
                        MortTextField(label: "Job title", text: $title, symbol: "text.alignleft")
                        MortTextArea(label: "What needs doing", text: $details)
                        FairPayGuardrail(offeredCents: $offeredCents, policy: policy)
                    }
                }
            }
        } bottom: {
            if let value = job.value, value.state == .open {
                MortBottomBar {
                    MortPrimaryButton(
                        title: "Save changes",
                        isBusy: isSaving,
                        isEnabled: verdict.canPost && !isSaving
                    ) {
                        Task { await save() }
                    }
                }
            }
        }
        .navigationTitle("Edit")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        job = .loading
        do {
            let value = try await mort.jobs.job(id: jobId)
            job = .loaded(value)
            title = value.title
            details = value.details
            offeredCents = value.baseCents
            policy = (try? await mort.jobs.fairPayPolicy(category: value.category)) ?? .reference
        } catch let failure as MortError {
            job = .failed(failure)
        } catch {
            job = .failed(.unknown)
        }
    }

    private func save() async {
        isSaving = true
        error = nil
        do {
            _ = try await mort.jobs.updateJob(
                id: jobId, title: title, details: details, baseCents: offeredCents
            )
            MortHaptic.success()
            nav.pop()
        } catch let failure as MortError {
            error = failure
        } catch {
            self.error = .unknown
        }
        isSaving = false
    }
}

struct JobPreviewView: View {
    var body: some View {
        MortScreen(
            title: "Preview",
            subtitle: "This is how your job looks to teens nearby.",
            atmosphereIntensity: 0.7
        ) {
            VStack(alignment: .leading, spacing: MortSpace.s4) {
                JobCard(job: MortFixtures.job) {}
                MortNote(
                    text: "Your exact address stays private until you accept someone.",
                    tone: .info
                )
            }
        }
        .navigationTitle("Preview")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { JobCreateView() }
        .environment(\.mort, MortDependencies.preview(user: MortFixtures.adult))
        .environment(MortNavigator())
        .preferredColorScheme(.dark)
}
