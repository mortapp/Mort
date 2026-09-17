//
//  AdultDashboardView.swift
//  MORT iOS V8 — Dashboard
//
//  The poster home: jobs needing action, funding status, applicants waiting.
//

import SwiftUI

@Observable
@MainActor
final class AdultDashboardViewModel {
    var jobs: LoadState<[MortJob]> = .idle
    var unreadNotifications = 0

    private let mort: MortDependencies
    init(mort: MortDependencies) { self.mort = mort }

    func load() async {
        jobs = .loading
        do {
            jobs = .loaded(try await mort.jobs.myJobs(role: .adult))
        } catch let error as MortError {
            jobs = .failed(error)
        } catch {
            jobs = .failed(.unknown)
        }
        let notes = (try? await mort.notifications.notifications()) ?? []
        unreadNotifications = notes.filter { !$0.isRead }.count
    }

    var needsFunding: [MortJob] {
        (jobs.value ?? []).filter { $0.state == .accepted }
    }

    var awaitingConfirmation: [MortJob] {
        (jobs.value ?? []).filter { $0.state == .awaitingCompletion || $0.state == .completed }
    }

    var live: [MortJob] {
        (jobs.value ?? []).filter { [.funded, .scheduled, .inProgress].contains($0.state) }
    }

    var open: [MortJob] {
        (jobs.value ?? []).filter { $0.state == .open }
    }
}

struct AdultDashboardView: View {
    let user: MortUser

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var model: AdultDashboardViewModel?

    var body: some View {
        MortScreen(atmosphereIntensity: 0.85) {
            VStack(alignment: .leading, spacing: MortSpace.s6) {
                VStack(alignment: .leading, spacing: MortSpace.s2) {
                    Text("HELLO \(user.displayName.split(separator: " ").first?.uppercased() ?? "")")
                        .mortEyebrow()
                    Text("What needs doing?")
                        .mortH1()
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                MortPrimaryButton(title: "Post a job", symbol: "plus") {
                    nav.push(.jobCreate)
                }

                if let model {
                    switch model.jobs {
                    case .idle, .loading:
                        MortSkeletonList(rows: 3)
                    case .failed(let error):
                        MortErrorState(message: error.userMessage) {
                            Task { await model.load() }
                        }
                    case .loaded, .offlineCache:
                        content(model)
                    }
                }
            }
        }
        .navigationTitle("")
        .toolbar { dashboardToolbar(unread: model?.unreadNotifications ?? 0, nav: nav) }
        .task {
            if model == nil { model = AdultDashboardViewModel(mort: mort) }
            await model?.load()
        }
        .refreshable { await model?.load() }
    }

    @ViewBuilder
    private func content(_ model: AdultDashboardViewModel) -> some View {
        if !model.needsFunding.isEmpty {
            VStack(alignment: .leading, spacing: MortSpace.s3) {
                MortSectionHeader(
                    title: "Needs funding",
                    subtitle: "Work can't start until you fund the job"
                )
                ForEach(model.needsFunding) { job in
                    MortCard {
                        VStack(alignment: .leading, spacing: MortSpace.s3) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(job.title).mortTitle().lineLimit(2)
                                    if let worker = job.workerHandle {
                                        Text("Worker: \(worker)").mortMicro()
                                    }
                                }
                                Spacer(minLength: MortSpace.s2)
                                MortStatusPill(
                                    tone: .warning,
                                    symbol: "lock.open",
                                    label: "Not funded",
                                    compact: true
                                )
                            }
                            MortPrimaryButton(title: "Fund \(job.basePay.formatted) job", symbol: "lock.shield") {
                                nav.push(.paymentReview(job.id))
                            }
                        }
                    }
                }
            }
        }

        if !model.awaitingConfirmation.isEmpty {
            VStack(alignment: .leading, spacing: MortSpace.s3) {
                MortSectionHeader(
                    title: "Waiting on you",
                    subtitle: "Confirm the work so your worker gets paid"
                )
                ForEach(model.awaitingConfirmation) { job in
                    JobCard(job: job, showsState: true) {
                        nav.push(.jobCompletion(job.id))
                    }
                }
            }
        }

        if !model.live.isEmpty {
            VStack(alignment: .leading, spacing: MortSpace.s3) {
                MortSectionHeader(title: "In motion")
                ForEach(model.live) { job in
                    JobCard(job: job, showsState: true) {
                        nav.push(.jobDetail(job.id))
                    }
                }
            }
        }

        if !model.open.isEmpty {
            VStack(alignment: .leading, spacing: MortSpace.s3) {
                MortSectionHeader(title: "Open posts", subtitle: "Waiting for applicants")
                ForEach(model.open) { job in
                    MortCard {
                        VStack(alignment: .leading, spacing: MortSpace.s3) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(job.title).mortTitle().lineLimit(2)
                                    Text("\(job.applicantCount) \(job.applicantCount == 1 ? "applicant" : "applicants")")
                                        .mortMicro()
                                }
                                Spacer(minLength: MortSpace.s2)
                                Text(job.basePay.formatted)
                                    .font(MortFont.money(16, weight: .medium))
                                    .foregroundStyle(MortColor.textPrimary)
                            }
                            MortGhostButton(
                                title: job.applicantCount > 0 ? "Review applicants" : "View post",
                                symbol: job.applicantCount > 0 ? "person.2" : "eye"
                            ) {
                                nav.push(job.applicantCount > 0 ? .jobApplicants(job.id) : .jobDetail(job.id))
                            }
                        }
                    }
                }
            }
        }

        if model.needsFunding.isEmpty, model.awaitingConfirmation.isEmpty,
           model.live.isEmpty, model.open.isEmpty {
            MortEmptyState(
                symbol: "house",
                title: "Nothing posted yet",
                message: "Post your first job and local teens can apply. You only fund it once you've picked someone.",
                actionTitle: "Post a job"
            ) {
                nav.push(.jobCreate)
            }
        }
    }
}

#Preview {
    NavigationStack {
        AdultDashboardView(user: MortFixtures.adult)
    }
    .environment(\.mort, MortDependencies.preview(user: MortFixtures.adult))
    .environment(MortNavigator())
    .preferredColorScheme(.dark)
}
