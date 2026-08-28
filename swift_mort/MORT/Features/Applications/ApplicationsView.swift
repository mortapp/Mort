import SwiftUI

struct ApplicationsView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(Router.self) private var router
    @State private var state: LoadState<[MortApplication]> = .idle
    @State private var statusFilter = "all"
    let mode: ApplicationListMode

    var body: some View {
        Group {
            switch state {
            case .idle, .loading: MortLoadingState(label: "Loading applications")
            case let .failed(message): MortErrorState(message: message) { Task { await load() } }
            case let .loaded(applications) where filtered(applications).isEmpty:
                MortEmptyState(title: "No applications here", message: emptyMessage, systemImage: "doc.text.magnifyingglass")
            case let .loaded(applications):
                List(filtered(applications)) { application in
                    Button { router.push(.applicationDetail(application.id, mode)) } label: {
                        ApplicationCard(application: application, mode: mode)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(MortColors.background)
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .refreshable { await load() }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { statusPicker }
        .navigationTitle(title)
        .task { await load() }
        .mortScreen()
    }

    private var statusPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: MortSpacing.xs) {
                ForEach(["all", "pending", "accepted", "in progress", "completed", "closed"], id: \.self) { value in
                    Button(value.capitalized) { statusFilter = value }
                        .buttonStyle(.bordered)
                        .tint(statusFilter == value ? MortColors.neon : MortColors.textMuted)
                }
            }
            .padding(.horizontal, MortSpacing.lg)
            .padding(.vertical, MortSpacing.xs)
        }
        .background(MortColors.elevated)
    }

    private var title: String {
        switch mode {
        case .teen: "My applications"
        case .adult: "Applicants"
        case .guardian: "Guardian approvals"
        }
    }

    private var emptyMessage: String {
        switch mode {
        case .teen: "Applications you submit will appear here with their real backend status."
        case .adult: "Applications to your posted jobs will appear here."
        case .guardian: "Only applications for jobs that explicitly require guardian approval appear here."
        }
    }

    private func filtered(_ items: [MortApplication]) -> [MortApplication] {
        switch statusFilter {
        case "all": items
        case "pending": items.filter { ["submitted", "guardian_pending", "adult_review", "viewed"].contains($0.status) }
        case "accepted": items.filter { $0.status == "accepted" }
        case "in progress": items.filter { ["in_progress", "proof_submitted"].contains($0.status) }
        case "completed": items.filter { $0.status == "completed" }
        default: items.filter { ["rejected", "guardian_rejected", "withdrawn"].contains($0.status) }
        }
    }

    private func load() async {
        state = .loading
        do {
            state = .loaded(mode == .adult ? try await container.applications.listForMyJobs() : try await container.applications.listMine())
        } catch { state = .failed(mortMessage(error)) }
    }
}

private struct ApplicationCard: View {
    let application: MortApplication
    let mode: ApplicationListMode

    var body: some View {
        MortCard {
            VStack(alignment: .leading, spacing: MortSpacing.sm) {
                HStack {
                    MortBadge(text: application.status.replacingOccurrences(of: "_", with: " "), tint: statusTint(application.status))
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(MortColors.textMuted)
                }
                Text(mode == .adult ? application.teen?.name ?? "Applicant" : application.job?.title ?? "Job application")
                    .font(MortTypography.section)
                    .foregroundStyle(MortColors.text)
                if mode == .adult, let title = application.job?.title {
                    Text(title).foregroundStyle(MortColors.textMuted)
                } else if let pay = application.job?.payDisplay {
                    Text(pay).foregroundStyle(MortColors.neon)
                }
                HStack {
                    Label(application.availabilityConfirmed ? "Availability confirmed" : "Availability not confirmed", systemImage: "calendar.badge.checkmark")
                    Spacer()
                    Text(DateFormatting.displayDateTime(application.createdAt))
                }
                .font(MortTypography.caption)
                .foregroundStyle(MortColors.textMuted)
            }
        }
    }
}
