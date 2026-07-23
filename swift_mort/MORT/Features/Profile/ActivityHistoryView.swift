import SwiftUI

struct ActivityHistoryView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(SessionStore.self) private var session
    @State private var applications: [MortApplication] = []
    @State private var jobs: [Job] = []
    @State private var connections: [GuardianConnection] = []
    @State private var reviews: [MortReview] = []
    @State private var reports: [ReportSummary] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                MortSectionHeader(title: "Your MORT activity", subtitle: "Only records your account can read through RLS appear here.")
                if isLoading { ProgressView().tint(MortColors.neon) }
                if let errorMessage { MortAlertBanner(title: "Some history could not load", message: errorMessage) }
                switch session.profile?.role {
                case .teen: historySection("Applications and work", rows: applications.map { ($0.job?.title ?? "Application", statusText($0.status), "doc.text") })
                case .adult: historySection("Posted jobs", rows: jobs.map { ($0.title, $0.status.capitalized, "briefcase") })
                case .guardian: historySection("Guardian links", rows: connections.map { ($0.teen?.name ?? "Guardian Mode connection", $0.status.capitalized, "person.2") })
                case .admin, .none: EmptyView()
                }
                historySection("Approved reviews received", rows: reviews.map { ("\($0.rating) out of 5", $0.body ?? "No comment", "star") })
                historySection("Safety reports submitted", rows: reports.map { ($0.reason.replacingOccurrences(of: "_", with: " ").capitalized, $0.status.capitalized, "flag") })
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("Activity")
        .task { await load() }
        .mortScreen()
    }

    private func historySection(_ title: String, rows: [(String, String, String)]) -> some View {
        VStack(alignment: .leading, spacing: MortSpacing.sm) {
            MortSectionHeader(title: title)
            MortCard {
                if rows.isEmpty {
                    Text("No activity yet.").foregroundStyle(MortColors.textMuted)
                } else {
                    VStack(alignment: .leading, spacing: MortSpacing.md) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { entry in
                            let row = entry.element
                            HStack(alignment: .top) {
                                Image(systemName: row.2).foregroundStyle(MortColors.safetyBlue).frame(width: 26)
                                VStack(alignment: .leading) { Text(row.0).font(MortTypography.label); Text(row.1).font(MortTypography.caption).foregroundStyle(MortColors.textMuted) }
                            }
                        }
                    }
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        var failures: [String] = []
        do {
            switch session.profile?.role {
            case .teen: applications = try await container.applications.listMine()
            case .adult: jobs = try await container.jobs.listMine()
            case .guardian: connections = try await container.guardians.connections()
            case .admin, .none: break
            }
        } catch { failures.append(mortMessage(error)) }
        do { reviews = try await container.reviews.received() } catch { failures.append(mortMessage(error)) }
        do { reports = try await container.safety.myReports() } catch { failures.append(mortMessage(error)) }
        errorMessage = failures.first
    }
}
