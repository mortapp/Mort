//
//  JobDetailView.swift
//  MORT iOS V8 — Jobs
//
//  One job, seen from whichever side the viewer is on. The action bar is
//  driven entirely by backend job state — the UI never invents a transition.
//

import SwiftUI

@Observable
@MainActor
final class JobDetailViewModel {
    var job: LoadState<MortJob> = .idle
    var receipt: Receipt?

    private let mort: MortDependencies
    private let jobId: String

    init(mort: MortDependencies, jobId: String) {
        self.mort = mort
        self.jobId = jobId
    }

    func load() async {
        job = .loading
        do {
            let loaded = try await mort.jobs.job(id: jobId)
            job = .loaded(loaded)
            // A receipt only exists once the backend issued one.
            if loaded.state == .settled {
                receipt = try? await mort.receipts.receipt(jobId: jobId, type: .adultJobPayment)
            }
        } catch let error as MortError {
            job = .failed(error)
        } catch {
            job = .failed(.unknown)
        }
    }
}

struct JobDetailView: View {
    let jobId: String
    let user: MortUser

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var model: JobDetailViewModel?

    private var isPoster: Bool {
        guard let job = model?.job.value else { return false }
        return job.posterHandle == user.handle
    }

    var body: some View {
        MortScreen(atmosphereIntensity: 0.7) {
            if let model {
                switch model.job {
                case .idle, .loading:
                    VStack(alignment: .leading, spacing: MortSpace.s4) {
                        MortSkeletonBar(width: 220, height: 24)
                        MortSkeletonBar(width: 140, height: 14)
                        MortSkeletonList(rows: 3)
                    }
                case .failed(let error):
                    MortErrorState(message: error.userMessage) {
                        Task { await model.load() }
                    }
                case .loaded(let job), .offlineCache(let job):
                    detail(job)
                }
            }
        } bottom: {
            if let job = model?.job.value {
                MortBottomBar { actions(job) }
            }
        }
        .navigationTitle("Job")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if model == nil { model = JobDetailViewModel(mort: mort, jobId: jobId) }
            await model?.load()
        }
    }

    @ViewBuilder
    private func detail(_ job: MortJob) -> some View {
        VStack(alignment: .leading, spacing: MortSpace.s5) {
            VStack(alignment: .leading, spacing: MortSpace.s3) {
                MortStatusPill(
                    tone: job.state.tone,
                    symbol: job.state.symbol,
                    label: job.state.label
                )
                Text(job.title)
                    .mortH1()
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: MortSpace.s2) {
                    Text(job.category).mortLabel()
                    Text("·").mortLabel()
                    Text(job.distance).mortLabel()
                    Text("·").mortLabel()
                    Text(job.area).mortLabel()
                }
            }

            MortCard {
                VStack(alignment: .leading, spacing: MortSpace.s3) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(job.basePay.formatted)
                                .font(MortFont.money(32, weight: .light))
                                .foregroundStyle(MortColor.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                            Text("BASE PAY").mortEyebrow()
                        }
                        Spacer(minLength: MortSpace.s2)
                        if let order = job.orderNumber {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("#\(order)")
                                    .font(MortFont.money(14))
                                    .foregroundStyle(MortColor.textSecondary)
                                Text("ORDER").mortEyebrow()
                            }
                        }
                    }
                    MortDivider()
                    MortKeyValueRow(label: "WHEN", value: job.scheduleText)
                    MortDivider()
                    MortKeyValueRow(
                        label: isPoster ? "WORKER" : "POSTED BY",
                        value: isPoster ? (job.workerHandle ?? "Not chosen yet") : job.posterHandle
                    )
                    if job.requiresProof {
                        MortDivider()
                        MortNote(
                            text: "This job asks for a photo or note when the work is done.",
                            tone: .info,
                            symbol: "camera"
                        )
                    }
                }
            }

            VStack(alignment: .leading, spacing: MortSpace.s3) {
                MortSectionHeader(title: "What's involved")
                Text(job.details)
                    .mortBody()
                    .fixedSize(horizontal: false, vertical: true)
            }

            if job.state == .funded || job.state == .scheduled || job.state == .inProgress {
                MortStatusPanel(
                    tone: .success,
                    symbol: "lock.shield",
                    label: "JOB FUNDED",
                    detail: isPoster
                        ? "MORT is holding the funds. They're released after you confirm the work."
                        : "The money is already held by MORT. You'll be paid after the job is confirmed."
                )
            }

            if let receipt = model?.receipt {
                MortGhostButton(title: "View receipt", symbol: "doc.text") {
                    nav.push(.receipt(receipt.id))
                }
            }

            VStack(spacing: MortSpace.s2) {
                MortNavRow(title: "Message", symbol: "bubble.left") {
                    nav.push(.conversation(MortFixtures.conversations[0].id))
                }
                MortDivider()
                MortNavRow(
                    title: isPoster ? "View worker profile" : "View poster profile",
                    symbol: "person.crop.circle"
                ) {
                    nav.push(.publicProfile(isPoster ? (job.workerHandle ?? "") : job.posterHandle))
                }
                MortDivider()
                MortNavRow(title: "Report a problem", symbol: "flag", tone: .danger) {
                    nav.present(.safetyReport(jobId: job.id))
                }
            }
        }
    }

    @ViewBuilder
    private func actions(_ job: MortJob) -> some View {
        switch (job.state, isPoster) {
        case (.open, false):
            MortPrimaryButton(title: "Apply for this job", symbol: "paperplane") {
                nav.push(.jobApply(job.id))
            }
        case (.open, true):
            MortPrimaryButton(title: "Review applicants", symbol: "person.2") {
                nav.push(.jobApplicants(job.id))
            }
        case (.applied, false):
            MortGhostButton(title: "Application submitted", isEnabled: false) {}
        case (.accepted, true):
            MortPrimaryButton(title: "Fund this job", symbol: "lock.shield") {
                nav.push(.paymentReview(job.id))
            }
        case (.accepted, false):
            MortStatusPanel(
                tone: .warning,
                symbol: "hourglass",
                label: "WAITING ON FUNDING",
                detail: "You can start once the poster funds the job."
            )
        case (.funded, false), (.scheduled, false):
            MortPrimaryButton(title: "Start this job", symbol: "play.circle") {
                nav.present(.jobStartPin(job.id))
            }
        case (.inProgress, false):
            MortPrimaryButton(title: "Finish up", symbol: "checkmark.circle") {
                nav.push(.jobExecution(job.id))
            }
        case (.awaitingCompletion, true), (.completed, true):
            MortPrimaryButton(title: "Confirm the work", symbol: "checkmark.seal") {
                nav.push(.jobCompletion(job.id))
            }
        case (.settled, true):
            MortGhostButton(title: "Add a tip", symbol: "hand.thumbsup") {
                nav.present(.tipSelect(jobId: job.id, isLate: true))
            }
        case (.disputed, _):
            MortGhostButton(title: "View dispute", symbol: "exclamationmark.triangle", tone: .danger) {
                nav.push(.jobDispute(job.id))
            }
        default:
            MortGhostButton(title: "View job history", symbol: "clock.arrow.circlepath") {
                nav.push(.history)
            }
        }

        if isPoster, [.open, .accepted, .funded, .scheduled].contains(job.state) {
            MortQuietButton(title: "Cancel this job", tone: .danger) {
                nav.present(.jobCancel(job.id))
            }
        }
    }
}

#Preview {
    NavigationStack {
        JobDetailView(jobId: MortFixtures.job.id, user: MortFixtures.teen)
    }
    .environment(\.mort, MortDependencies.preview())
    .environment(MortNavigator())
    .preferredColorScheme(.dark)
}
