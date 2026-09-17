//
//  TeenDashboardView.swift
//  MORT iOS V8 — Dashboard
//
//  The teen home: what's next, safety status, earnings-at-a-glance, and the
//  jobs worth looking at. Nothing here fabricates a number — every value
//  comes from a repository and empty means empty.
//

import SwiftUI

@Observable
@MainActor
final class TeenDashboardViewModel {
    var jobs: LoadState<[MortJob]> = .idle
    var nearby: LoadState<[MortJob]> = .idle
    var checkIn: SafetyCheckIn?
    var payout: PayoutStatus?
    var unreadNotifications = 0

    private let mort: MortDependencies

    init(mort: MortDependencies) {
        self.mort = mort
    }

    func load() async {
        jobs = .loading
        async let mine = mort.jobs.myJobs(role: .teen)
        async let feed = mort.jobs.discover(query: nil, category: nil, cursor: nil)
        async let check = mort.safety.activeCheckIn()
        async let payoutStatus = mort.payouts.payoutStatus()
        async let notes = mort.notifications.notifications()

        do {
            jobs = .loaded(try await mine)
        } catch let error as MortError {
            jobs = .failed(error)
        } catch {
            jobs = .failed(.unknown)
        }

        do {
            nearby = .loaded(try await feed.jobs)
        } catch let error as MortError {
            nearby = .failed(error)
        } catch {
            nearby = .failed(.unknown)
        }

        checkIn = try? await check
        payout = try? await payoutStatus
        unreadNotifications = ((try? await notes) ?? []).filter { !$0.isRead }.count
    }

    /// Active work the teen should act on now.
    var activeJobs: [MortJob] {
        (jobs.value ?? []).filter {
            [.funded, .scheduled, .inProgress, .awaitingCompletion].contains($0.state)
        }
    }

    /// Settled earnings are the ONLY thing counted here — never pending work.
    var settledJobs: [MortJob] {
        (jobs.value ?? []).filter { $0.state == .settled }
    }
}

struct TeenDashboardView: View {
    let user: MortUser

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var model: TeenDashboardViewModel?

    var body: some View {
        MortScreen(atmosphereIntensity: 0.85) {
            VStack(alignment: .leading, spacing: MortSpace.s6) {
                header

                if let model {
                    if let checkIn = model.checkIn, checkIn.state != .confirmed {
                        CheckInPrompt(checkIn: checkIn) {
                            nav.push(.safetyCheckIn(checkIn.jobId))
                        }
                    }

                    activeSection(model)
                    payoutSection(model)
                    nearbySection(model)
                }
            }
        }
        .navigationTitle("")
        .toolbar { dashboardToolbar(unread: model?.unreadNotifications ?? 0, nav: nav) }
        .task {
            if model == nil { model = TeenDashboardViewModel(mort: mort) }
            await model?.load()
        }
        .refreshable { await model?.load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: MortSpace.s2) {
            Text("HELLO \(user.displayName.split(separator: " ").first?.uppercased() ?? "")")
                .mortEyebrow()
            Text("Let's get you working.")
                .mortH1()
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func activeSection(_ model: TeenDashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: MortSpace.s3) {
            MortSectionHeader(title: "Your work") {
                if !model.activeJobs.isEmpty {
                    Button("See all") { nav.push(.myApplications) }
                        .font(MortFont.label())
                        .foregroundStyle(MortColor.silver3)
                }
            }

            switch model.jobs {
            case .loading, .idle:
                MortSkeletonList(rows: 2)
            case .failed(let error):
                MortErrorState(message: error.userMessage) {
                    Task { await model.load() }
                }
            case .loaded, .offlineCache:
                if model.activeJobs.isEmpty {
                    MortEmptyState(
                        symbol: "briefcase",
                        title: "No active jobs yet",
                        message: "When a neighbor picks you and funds the job, it shows up here.",
                        actionTitle: "Find work nearby"
                    ) {
                        nav.push(.jobDetail(MortFixtures.job.id))
                    }
                } else {
                    ForEach(model.activeJobs) { job in
                        JobCard(job: job, showsState: true) {
                            nav.push(.jobDetail(job.id))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func payoutSection(_ model: TeenDashboardViewModel) -> some View {
        if let payout = model.payout {
            VStack(alignment: .leading, spacing: MortSpace.s3) {
                MortSectionHeader(title: "Your money")
                MortCard {
                    VStack(alignment: .leading, spacing: MortSpace.s4) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(payout.amount.formatted)
                                    .font(MortFont.money(30, weight: .light))
                                    .foregroundStyle(MortColor.textPrimary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                                Text("MOVING TO YOUR BANK")
                                    .mortEyebrow()
                            }
                            Spacer(minLength: MortSpace.s2)
                            MortStatusPill(
                                tone: payout.stage.tone,
                                symbol: payout.stage.symbol,
                                label: payout.stage.label
                            )
                        }
                        Text(payout.stage.guidance)
                            .mortMicro()
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: MortSpace.s2) {
                            MortGhostButton(title: "Earnings", symbol: "chart.line.uptrend.xyaxis") {
                                nav.push(.earnings)
                            }
                            MortGhostButton(title: "Payouts", symbol: "building.columns") {
                                nav.push(.payoutStatus)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func nearbySection(_ model: TeenDashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: MortSpace.s3) {
            MortSectionHeader(title: "Near you", subtitle: "Jobs matching what you do")

            switch model.nearby {
            case .loading, .idle:
                MortSkeletonList(rows: 3)
            case .failed(let error):
                MortErrorState(message: error.userMessage) {
                    Task { await model.load() }
                }
            case .loaded(let jobs), .offlineCache(let jobs):
                if jobs.isEmpty {
                    MortEmptyState(
                        symbol: "magnifyingglass",
                        title: "Nothing nearby right now",
                        message: "New jobs appear as neighbors post them. We'll notify you."
                    )
                } else {
                    ForEach(jobs.prefix(4)) { job in
                        JobCard(job: job) { nav.push(.jobDetail(job.id)) }
                    }
                }
            }
        }
    }
}

/// Shared dashboard toolbar: notifications + settings.
@ToolbarContentBuilder
func dashboardToolbar(unread: Int, nav: MortNavigator) -> some ToolbarContent {
    ToolbarItem(placement: .topBarLeading) {
        MortMotionMark()
            .frame(width: 26, height: 26)
    }
    ToolbarItem(placement: .topBarTrailing) {
        Button {
            nav.push(.notifications)
        } label: {
            Image(systemName: unread > 0 ? "bell.badge" : "bell")
                .foregroundStyle(MortColor.textPrimary)
        }
        .accessibilityLabel(unread > 0 ? "Notifications, \(unread) unread" : "Notifications")
    }
    ToolbarItem(placement: .topBarTrailing) {
        Button {
            nav.push(.settings)
        } label: {
            Image(systemName: "gearshape")
                .foregroundStyle(MortColor.textPrimary)
        }
        .accessibilityLabel("Settings")
    }
}

struct CheckInPrompt: View {
    let checkIn: SafetyCheckIn
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MortSpace.s3) {
                Image(systemName: checkIn.state.symbol)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(checkIn.state.tone.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(checkIn.state.label)
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(checkIn.state.tone.color)
                    Text(checkIn.jobTitle)
                        .mortBodyStrong()
                        .lineLimit(1)
                    Text(checkIn.dueText).mortMicro()
                }
                Spacer(minLength: MortSpace.s2)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MortColor.textMuted)
            }
            .padding(MortSpace.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: MortRadius.lg, style: .continuous)
                    .fill(checkIn.state.tone.dim)
            }
            .overlay {
                RoundedRectangle(cornerRadius: MortRadius.lg, style: .continuous)
                    .strokeBorder(checkIn.state.tone.color.opacity(0.35), lineWidth: 1)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        TeenDashboardView(user: MortFixtures.teen)
    }
    .environment(\.mort, MortDependencies.preview())
    .environment(MortNavigator())
    .preferredColorScheme(.dark)
}
